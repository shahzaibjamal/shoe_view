import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Services/connectivity_service.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Helpers/shoe_response.dart';
import 'package:shoe_view/Image/collage_builder.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';
import 'package:shoe_view/Services/analytics_service.dart';
import 'package:shoe_view/Services/firebase_service.dart';
import 'package:shoe_view/ShoeUpdateForm/shoe_form_dialog.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';
import 'package:shoe_view/Subscription/subscription_upgrade_page.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/list_header.dart';
import 'package:shoe_view/settings_dialog.dart';
import 'package:shoe_view/shoe_list_item.dart';
import 'package:shoe_view/shoe_model.dart';
import 'package:shoe_view/shared/constants/app_constants.dart';
import 'package:shoe_view/shared/widgets/skeleton_loader.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shoe_view/Filters/filter_menu.dart';
import 'package:shoe_view/Filters/filter_state.dart';
import 'package:lottie/lottie.dart';

class ShoeListView extends StatefulWidget {
  const ShoeListView({super.key});

  @override
  State<ShoeListView> createState() => _ShoeListViewState();
}

class _ShoeListViewState extends State<ShoeListView>
    with WidgetsBindingObserver {
  // --- UI State ---
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // 🎯 For endDrawer
  ShoeSortField _sortField = ShoeSortField.itemId;
  bool _sortAscending = true;
  bool _isLoadingExternalData = false;
  bool _isInitialLoading = true;
  String _searchQuery = '';
  final ValueNotifier<bool> _isFabVisible = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _showToTop = ValueNotifier<bool>(false);
  Timer? _debounceTimer;

  // --- Filter State ---
  FilterState _filterState = FilterState(
    selectedShipments: {},
    priceRange: const RangeValues(0, 100000), // Updated in processShoes if needed
    selectedSizesEur: {},
    selectedConditions: {},
  );

  // --- Data State ---
  List<Shoe> _streamShoes = []; // Raw data from stream
  List<Shoe> _displayedShoes = []; // Processed data (filtered & sorted)
  late Stream<List<Shoe>> _shoeStream; // 🎯 Memoize the stream

  // --- Memoization Utilities ---
  ShoeCategory _selectedCategory = ShoeCategory.available;
  ShoeCategory _lastProcessedCategory = ShoeCategory.available;
  String _lastProcessedQuery = '';
  ShoeSortField _lastProcessedSortField = ShoeSortField.itemId;
  bool _lastProcessedSortAscending = true;
  FilterState? _lastProcessedFilterState; // 🎯 ADDED
  int _lastProcessedListLength = -1;
  List<String> _searchSuggestions = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _lastScrollPosition = 0;
  Timer? _fabVisibilityTimer;

  // --- Selection Mode ---
  final Set<String> _selectedShoeIds = {};
  bool get _isSelectionMode => _selectedShoeIds.isNotEmpty;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_scrollListener);

    // Initial check for subscription
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionManager>().queryActivePurchases();
      // 🎯 Trigger Background Sync logic (moved from AuthScreen)
      _triggerBackgroundSync();
    });

    // 🎯 Initialize stream once to prevent restarts on search/rebuild
    _shoeStream = context.read<FirebaseService>().streamShoes();
    _setupConnectivityListener();
  }
  
  void _setupConnectivityListener() {
    _connectivitySubscription =
        ConnectivityService().connectivityStream.listen((results) {
      if (results.contains(ConnectivityResult.mobile)) {
        _checkAndAskForMobileSync();
      }
    });

    // Check initial state
    ConnectivityService().isMobileData().then((isMobile) {
      if (isMobile) _checkAndAskForMobileSync();
    });
  }

  void _checkAndAskForMobileSync() {
    if (!mounted) return;
    final appStatus = context.read<AppStatusNotifier>();
    if (!appStatus.allowMobileDataSync && !appStatus.hasPromptedForMobileSync) {
      _showMobileSyncDialog();
    }
  }

  void _showMobileSyncDialog() {
    if (!mounted) return;
    final appStatus = context.read<AppStatusNotifier>();
    appStatus.setHasPromptedForMobileSync(true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mobile Data Detected'),
        content: const Text(
            'Sync is paused on mobile data to save bandwidth. Would you like to enable it for this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('STAY PAUSED', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              appStatus.setSessionMobileSyncAllowed(true);
              Navigator.pop(context);
            },
            child: const Text('ENABLE SYNC'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerBackgroundSync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      AppLogger.log("🔄 [ShoeListView] Starting Background Sync for ${user.email}...");
      final String? idToken = await user.getIdToken();
      if (idToken == null) return;

      final firebaseService = context.read<FirebaseService>();
      
      // We don't need to pass notifier because we are in a valid context 
      // (or we check mounted before using it).
      final result = await firebaseService.checkUserAuthorization(
        email: user.email!,
        idToken: idToken,
      );

      AppLogger.log("☁️ [ShoeListView] CLOUD RESPONSE: $result");

      if (!mounted) return;

      final shoeResponse = ShoeResponse.fromJson(result);
      final notifier = context.read<AppStatusNotifier>();
      
      // Update Notifier
      notifier.updateFromResponse(shoeResponse, user.email!);

      // Save to Prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_locally_authorized', shoeResponse.isAuthorized);
      await prefs.setString('cached_user_email', user.email!);
      await prefs.setBool('isTestModeEnabled_Permission', shoeResponse.isTestModeEnabled);
      await prefs.setInt('dailyShares', shoeResponse.dailySharesUsed);
      await prefs.setInt('dailySharesLimit', shoeResponse.dailySharesLimit);
      await prefs.setInt('dailyWrites', shoeResponse.dailyWritesUsed);
      await prefs.setInt('dailyWritesLimit', shoeResponse.dailyWritesLimit);
      await prefs.setInt('tier', shoeResponse.tier);
      
      AppLogger.log("✅ [ShoeListView] Background Sync Complete & Saved");

    } catch (e) {
      AppLogger.log("⚠️ [ShoeListView] Background Sync Failed: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _isFabVisible.dispose();
    _debounceTimer?.cancel();
    _fabVisibilityTimer?.cancel();
    _showToTop.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('lastSubscriptionCheck') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      AppLogger.log(
        "App resumed — refreshing subscription status $now - $lastCheck = ${now - lastCheck}",
      );

      if (context.mounted) {
        final subscriptionManager = context.read<SubscriptionManager>();
        if (now - lastCheck > 10 * 60 * 1000) {
          subscriptionManager.queryActivePurchases();
          prefs.setInt('lastSubscriptionCheck', now);
        }
      }
    }
  }

  // --- Event Handlers ---

  void _scrollListener() {
    // 🎯 Hide FAB immediately when scrolling starts (any direction)
    if (_isFabVisible.value) {
      _isFabVisible.value = false;
    }

    // 🎯 Reset timer on every scroll event. 
    // Show FAB back after 1 second of being "static"
    _fabVisibilityTimer?.cancel();
    _fabVisibilityTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _isFabVisible.value = true;
      }
    });

    _lastScrollPosition = _scrollController.offset;

    // 🎯 Show Scroll-to-Top when header is small (filters hidden)
    // Filters hide when header height < 110. 
    // Header height = max - offset (capped at min).
    // So if offset > max - 110, they are hidden.
    final double headerMaxHeight = MediaQuery.of(context).size.height * 0.20;
    if (_scrollController.offset > (headerMaxHeight - 110 + 100)) { 
      // Added +100 to ensure user has scrolled a bit more into the list
      if (!_showToTop.value) _showToTop.value = true;
    } else {
      if (_showToTop.value) _showToTop.value = false;
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    }
  }

  Future<void> _onRefreshData() async {
    setState(() => _isLoadingExternalData = true);
    final firebaseService = context.read<FirebaseService>();

    int retryCount = 0;
    const maxRetries = AppConstants.maxRetries;
    
    while (retryCount < maxRetries) {
      try {
        final fetchedShoes = await firebaseService.fetchData();
        final existingKeys = {
          for (var shoe in _streamShoes) '${shoe.itemId}_${shoe.shipmentId}',
        };

        final List<Shoe> newAvailableShoes = [];
        for (final shoe in fetchedShoes) {
          final key = '${shoe.itemId}_${shoe.shipmentId}';
          if (!existingKeys.contains(key)) {
            newAvailableShoes.add(shoe);
            AppLogger.log(
              'NEW → ID: ${shoe.itemId}, Shipment: ${shoe.shipmentId}, Detail: ${shoe.shoeDetail}',
            );
          }
        }

        if (newAvailableShoes.isNotEmpty) {
          await ShoeQueryUtils.debugAddShoesFromSheetData(
            firebaseService,
            newAvailableShoes,
          );
        }

        if (mounted) {
          setState(() => _isLoadingExternalData = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Fetched ${fetchedShoes.length} item(s). Added ${newAvailableShoes.length} new.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        return; // Success, exit retry loop
        
      } catch (error) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // Final failure
          if (mounted) {
            setState(() => _isLoadingExternalData = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed after $maxRetries attempts: $error'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Retry',
                  onPressed: _onRefreshData,
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  void _onCategoryChanged(ShoeCategory? newCategory) {
    if (newCategory == null || newCategory == _selectedCategory) return;
    HapticFeedback.mediumImpact();
    AnalyticsService.logSelectContent(
        contentType: 'dropdown', itemId: 'category_filter');
    setState(() {
      _selectedCategory = newCategory;
      // Re-process shoes immediately to update displayed list
      _processAndDisplayShoes(_streamShoes);
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.category, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${newCategory.name.toUpperCase()}: ${_displayedShoes.length} Items',
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 4, left: 16, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  void _onSortChanged(ShoeSortField? newSortField) {
    if (newSortField == null || newSortField == _sortField) return;
    HapticFeedback.mediumImpact();
    AnalyticsService.logSelectContent(
        contentType: 'dropdown', itemId: 'sort_field');
    setState(() {
      _sortField = newSortField;
      _processAndDisplayShoes(_streamShoes);
    });
  }

  void _onSortDirectionChanged() {
    HapticFeedback.mediumImpact();
    AnalyticsService.logSelectContent(
        contentType: 'button', itemId: 'sort_direction');
    setState(() {
      _sortAscending = !_sortAscending;
      _processAndDisplayShoes(_streamShoes);
    });
  }

  // --- Selection Support ---
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedShoeIds.contains(id)) {
        _selectedShoeIds.remove(id);
      } else {
        _selectedShoeIds.add(id);
      }
    });
  }

  void _clearSelection() {
    if (_selectedShoeIds.isEmpty) return;
    setState(() {
      _selectedShoeIds.clear();
    });
  }

  String _getShoeKey(Shoe shoe) => '${shoe.itemId}_${shoe.shipmentId}';

  // --- Processing ---

  void _processAndDisplayShoes(List<Shoe> rawShoes) {
    final query = _searchController.text.toLowerCase();
    
    // Check if inputs have changed using reference equality for the list
    // This allows us to skip processing on simple UI rebuilds (scrolling, etc)
    // while still catching every Firestore update (which produces a new List reference).
    final bool inputsChanged = 
        rawShoes != _streamShoes ||
        query != _lastProcessedQuery ||
        _filterState != _lastProcessedFilterState || // 🎯 ADDED
        _selectedCategory != _lastProcessedCategory;

    if (!inputsChanged && _searchSuggestions.isNotEmpty && _displayedShoes.isNotEmpty) {
      return;
    }

    // Update references
    _streamShoes = rawShoes;
    _lastProcessedQuery = query;
    _lastProcessedSortField = _filterState.sortBy; // 🎯 Sync from filter
    _lastProcessedCategory = _selectedCategory;
    _lastProcessedSortAscending = _filterState.ascending; // 🎯 Sync from filter
    _lastProcessedFilterState = _filterState;
    _lastProcessedListLength = rawShoes.length;

    // 🎯 Dynamic Filter Bounds Calculation
    // We calculate these from the 'category-filtered' list to keep bounds relevant
    final categoryShoes = rawShoes.where((s) {
      if (_selectedCategory == ShoeCategory.available) return s.status == 'available';
      if (_selectedCategory == ShoeCategory.sold) return s.status == 'sold';
      if (_selectedCategory == ShoeCategory.repaired) return s.status == 'repaired';
      if (_selectedCategory == ShoeCategory.upcoming) return s.status == 'upcoming';
      if (_selectedCategory == ShoeCategory.internal) return s.status == 'internal';
      return true;
    }).toList();

    if (categoryShoes.isNotEmpty) {
      double minP = categoryShoes.map((s) => s.sellingPrice).reduce(min);
      double maxP = categoryShoes.map((s) => s.sellingPrice).reduce(max);
      
      // If we haven't user-adjusted the range yet, or if it's out of bounds, reset it
      if (_filterState.priceRange.start < minP || _filterState.priceRange.end > maxP * 1.5) {
         _filterState = _filterState.copyWith(priceRange: RangeValues(minP, maxP));
      }
    }

    // Filter
    final filtered = rawShoes.where((shoe) {
      return ShoeQueryUtils.doesShoeMatchSmartQuery(shoe, query);
    }).toList();

    // Sort & Limit
    final appStatus = context.read<AppStatusNotifier>();
    _displayedShoes = ShoeQueryUtils.sortAndLimitShoes(
      shoes: filtered,
      rawQuery: query,
      sortField: _filterState.sortBy, // 🎯 Use filterState
      sortAscending: _filterState.ascending, // 🎯 Use filterState
      category: _selectedCategory,
      isFlatSale: appStatus.isFlatSale,
      flatDiscount: appStatus.flatDiscount,
      applySaleToAllStatuses: appStatus.applySaleToAllStatuses,
      isTest: appStatus.isTest,
      categoryFixedPrices: appStatus.categoryFixedPrices,
      filterState: _filterState, // 🎯 Pass filter state
    );

    // Update suggestions if the source list changed OR if they are currently empty
    if (rawShoes != _streamShoes || _searchSuggestions.isEmpty) {
      _searchSuggestions = _computeSearchSuggestions(rawShoes);
    }

    // Trigger Image Warmup for new list (deferred)
    if (_displayedShoes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmUpImages(_displayedShoes);
      });
    }
  }

  List<String> _computeSearchSuggestions(List<Shoe> shoes) {
    if (shoes.isEmpty) return ['lim<10', 'lim~5', '#2', '<2000', '<3000'];

    final Map<String, int> frequencies = {};
    for (var shoe in shoes) {
      final detail = shoe.shoeDetail.toLowerCase();
      final tokens = detail.split(RegExp(r'\W+')).where((t) => t.length > 2);
      for (var t in tokens) {
        frequencies[t] = (frequencies[t] ?? 0) + 1;
      }
    }

    final sortedTokens = frequencies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topTokens = sortedTokens.take(15).map((e) => e.key).toList();

    return [
      ...topTokens.map((t) => t[0].toUpperCase() + t.substring(1)),
      'lim<10',
      'lim~5',
      '#',
      '<2000',
      '>3000',
    ];
  }

  void _warmUpImages(List<Shoe> shoes) {
    final cache = ShoeViewCacheManager();
    
    // Only warm up first 20 items (visible + buffer)
    final itemsToWarm = shoes.take(AppConstants.imageWarmupCount).toList();
    
    // Load in batches to avoid overwhelming the system
    final batchSize = AppConstants.imageBatchSize;
    for (int i = 0; i < itemsToWarm.length; i += batchSize) {
      final batch = itemsToWarm.skip(i).take(batchSize);
      
      // Small delay between batches
      Future.delayed(Duration(milliseconds: 100 * (i ~/ batchSize)), () {
        for (var shoe in batch) {
          if (shoe.remoteImageUrl.isNotEmpty) {
            cache.getCachedOrDownloadFile(shoe.remoteImageUrl);
          }
        }
      });
    }
  }

  String _generateShareTextHelper(List<Shoe> shoes) {
    final appStatus = context.read<AppStatusNotifier>();
    
    if (appStatus.isConciseMode) {
      return ShoeQueryUtils.generateConciseCopyText(
        shoes: shoes,
        currencyCode: appStatus.currencyCode,
        isFlatSale: appStatus.isFlatSale,
        flatDiscount: appStatus.flatDiscount,
        sortField: _sortField,
        category: _selectedCategory,
        applySaleToAllStatuses: appStatus.applySaleToAllStatuses,
        isTest: appStatus.isTest,
        categoryFixedPrices: appStatus.categoryFixedPrices,
      );
    }
    
    return ShoeQueryUtils.generateCopyText(
      shoes: shoes,
      currencyCode: appStatus.currencyCode,
      isRepairedInfoAvailable: appStatus.isRepairedInfoAvailable,
      isSalePrice: appStatus.isSalePrice,
      isFlatSale: appStatus.isFlatSale,
      isPriceHidden: appStatus.isPriceHidden,
      flatDiscount: appStatus.flatDiscount,
      lowDiscount: appStatus.lowDiscount,
      highDiscount: appStatus.highDiscount,
      sortField: _sortField,
      category: _selectedCategory,
      isInstagramOnly: appStatus.isInstagramOnly,
      applySaleToAllStatuses: appStatus.applySaleToAllStatuses,
      isTest: appStatus.isTest,
      categoryFixedPrices: appStatus.categoryFixedPrices,
    );
  }

  // --- Actions ---

  Future<void> _onSampleSend() async {
    final sampleShareCount = context.read<AppStatusNotifier>().sampleShareCount;
    if (_displayedShoes.isEmpty || sampleShareCount <= 0) return;

    const String kSequenceKey = 'sample_send_sequence';
    const String kSentHistoryKey = 'sample_send_history';
    final prefs = await SharedPreferences.getInstance();

    final Map<String, Shoe> shoeMap = {
      for (var shoe in _displayedShoes) '${shoe.shipmentId}_${shoe.itemId}': shoe,
    };
    final List<String> currentInventoryIds = shoeMap.keys.toList();

    List<String> sequenceOfIds = _getListFromPrefs(prefs, kSequenceKey);
    List<String> sentHistoryIds = _getListFromPrefs(prefs, kSentHistoryKey);

    sequenceOfIds.retainWhere((id) => currentInventoryIds.contains(id));
    sentHistoryIds.retainWhere((id) => currentInventoryIds.contains(id));

    final Set<String> existingKnownIds = {...sequenceOfIds, ...sentHistoryIds};
    final List<String> brandNewIds =
        currentInventoryIds.where((id) => !existingKnownIds.contains(id)).toList();

    if (brandNewIds.isNotEmpty) {
      brandNewIds.shuffle(Random());
      sequenceOfIds.addAll(brandNewIds);
    }

    if (sequenceOfIds.isEmpty) {
      sequenceOfIds = List.of(currentInventoryIds)..shuffle(Random());
      sentHistoryIds.clear();
    }

    final int itemsToTake = min(sampleShareCount, sequenceOfIds.length);
    final List<String> selectedIds = sequenceOfIds.take(itemsToTake).toList();
    final List<Shoe> selectedItems =
        selectedIds.map((id) => shoeMap[id]!).toList();

    sequenceOfIds.removeRange(0, itemsToTake);
    sentHistoryIds.addAll(selectedIds);

    _shareData(selectedItems);

    await prefs.setString(kSequenceKey, jsonEncode(sequenceOfIds));
    await prefs.setString(kSentHistoryKey, jsonEncode(sentHistoryIds));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent: ${selectedIds.length} | Remaining: ${sequenceOfIds.length}',
          ),
        ),
      );
    }
  }

  List<String> _getListFromPrefs(SharedPreferences prefs, String key) {
    final String? jsonString = prefs.getString(key);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      return (jsonDecode(jsonString) as List).cast<String>();
    } catch (e) {
      return [];
    }
  }

  void _onShareAll() {
    HapticFeedback.mediumImpact();
    AnalyticsService.logSelectContent(
        contentType: 'button', itemId: '_onShareAll');
    final isAllShoesShare = context.read<AppStatusNotifier>().isAllShoesShare;

    if (isAllShoesShare) {
      final query = _searchController.text.toLowerCase();
      // Use streamShoes (all raw data) to filter for share
      final filteredForShare = _streamShoes
          .where((shoe) =>
              shoe.status != 'repaired' &&
              shoe.status != 'in' &&
              ShoeQueryUtils.doesShoeMatchSmartQuery(shoe, query))
          .toList();

      final sortedForShare = ShoeQueryUtils.sortAndLimitShoes(
        shoes: filteredForShare,
        rawQuery: query,
        sortField: _sortField,
        sortAscending: _sortAscending,
        applyStatusFilter: false,
      );
      _shareData(sortedForShare);
    } else {
      _shareData(_displayedShoes);
    }
  }

  void _shareData(List<Shoe> shoesToShare) {
    final firebaseService = context.read<FirebaseService>();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            ),
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Share Collage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: CollageBuilder(
                          firebaseService: firebaseService,
                          shoes: shoesToShare,
                          text: _generateShareTextHelper(shoesToShare),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onCopyShoe(Shoe shoe) {
    HapticFeedback.lightImpact();
    AnalyticsService.logSelectContent(
        contentType: 'button', itemId: '_onCopyShoe');
    final text = _generateShareTextHelper([shoe]);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Copied: ${shoe.shoeDetail}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAll() {
    HapticFeedback.mediumImpact();
    AnalyticsService.logSelectContent(
        contentType: 'button', itemId: '_onCopyAll');
    final text = _generateShareTextHelper(_displayedShoes);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Copied ${_displayedShoes.length} items.'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteShoe(Shoe shoe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 56),
        title: const Text('Delete Shoe', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Are you sure you want to delete this shoe?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Shoe image
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: Colors.white,
              ),
              child: shoe.remoteImageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ShoeNetworkImage(
                        imageUrl: shoe.remoteImageUrl,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        desiredWidth: 400,
                      ),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              shoe.shoeDetail,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${shoe.itemId}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(false);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      try {
        final firebaseService = context.read<FirebaseService>();
        final response = await firebaseService.deleteShoe(shoe);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
        }
        
        if (response['success'] == false && mounted) {
          showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'Error',
              message: response['message'] ?? 'Failed to delete shoe',
              onDismissed: () {},
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shoe deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'Error',
              message: 'Failed to delete shoe: ${e.toString()}',
              onDismissed: () {},
            ),
          );
        }
      }
    }
  }

  Future<void> _bulkDelete() async {
    final selectedShoes = _streamShoes
        .where((s) => _selectedShoeIds.contains(_getShoeKey(s)))
        .toList();

    if (selectedShoes.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selectedShoes.length} Items?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete these shoes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final firebaseService = context.read<FirebaseService>();
        int deletedCount = 0;
        for (final shoe in selectedShoes) {
          await firebaseService.deleteShoe(shoe);
          deletedCount++;
        }

        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          _clearSelection();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted $deletedCount items'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _bulkCopy() {
    final selectedShoes = _streamShoes
        .where((s) => _selectedShoeIds.contains(_getShoeKey(s)))
        .toList();
    if (selectedShoes.isEmpty) return;

    final text = _generateShareTextHelper(selectedShoes);
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Copied ${selectedShoes.length} pairs to clipboard')),
    );
    _clearSelection();
  }

  void _bulkCollage() {
    final selectedShoes = _streamShoes
        .where((s) => _selectedShoeIds.contains(_getShoeKey(s)))
        .toList();
    if (selectedShoes.isEmpty) return;

    final text = _generateShareTextHelper(selectedShoes);
    final firebaseService = context.read<FirebaseService>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Collage',
      barrierColor: Colors.black87,
      pageBuilder: (context, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: CollageBuilder(
                  firebaseService: firebaseService,
                  shoes: selectedShoes,
                  text: text,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading shoes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() => _isInitialLoading = true);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(), // Managed by parent sliver
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://lottie.host/7e9d7249-fbd8-4903-8d6c-2f6a97184291/K7V8Bw0Y6G.json', // Premium Shoe Walk
            height: 180,
            repeat: true,
            errorBuilder: (context, error, stackTrace) => Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No shoes found' : 'Empty Hive',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Tap the + button to stock your initial pairs!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _searchController.clear(),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(double height, FirebaseService firebaseService) {
    final maxPrice = _streamShoes.isEmpty ? 0.0 : _streamShoes.map((s) => s.sellingPrice).reduce(max);
    final filterCount = _filterState.countActiveFilters(maxPrice);

    return ListHeader(
      height: height,
      searchController: _searchController,
      searchQuery: _searchQuery,
      suggestions: _searchSuggestions,
      itemCount: _displayedShoes.length,
      filterCount: filterCount, // 🎯 Pass filter count
      onFilterButtonPressed: () {
        _scaffoldKey.currentState?.openEndDrawer();
      },
      onCopyDataPressed: _copyAll,
      onShareDataPressed: _onShareAll,
      onRefreshDataPressed: _onRefreshData,
      onCloseAppPressed: () => SystemNavigator.pop(),
      onInAppButtonPressed: () {
        final subManager = context.read<SubscriptionManager>();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: subManager,
            child: const SubscriptionUpgradePage(),
          ),
        ));
      },
      onSettingsButtonPressed: () {
        final subManager = context.read<SubscriptionManager>();
        showDialog(
          context: context,
          builder: (_) => SettingsDialog(
            firebaseService: firebaseService,
            subscriptionManager: subManager,
          ),
        );
      },
      onSampleSendPressed: _onSampleSend,
      onSaveDataPressed: () =>
          ShoeQueryUtils.saveShoesToAppExternal(_streamShoes),
      selectedCount: _selectedShoeIds.length,
      onClearSelection: _clearSelection,
      onBulkDelete: _bulkDelete,
      onBulkCopy: _bulkCopy,
      onBulkCollage: _bulkCollage,
      selectedCategory: _selectedCategory,
      onCategoryChanged: (newCat) {
        setState(() => _selectedCategory = newCat);
      },
    );
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final double headerMaxHeight = 160.0; // 🎯 Increased to fit tabs
    const double headerMinHeight = 145.0; // 🎯 Increased to fit tabs
    final FirebaseService firebaseService = context.read<FirebaseService>();
    final appStatus = context.watch<AppStatusNotifier>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // 🎯 Handle Selection Mode: Clear selection on back press
        if (_isSelectionMode) {
          _clearSelection();
          return;
        }

        _showExitConfirmation();
      },
      child: Scaffold(
        key: _scaffoldKey, // 🎯 Essential for drawer management
        endDrawer: FilterMenu(
          currentFilter: _filterState,
          allShoes: _streamShoes,
          selectedCategory: _selectedCategory,
          isFlatSale: appStatus.isFlatSale,
          flatDiscount: appStatus.flatDiscount,
          applySaleToAllStatuses: appStatus.applySaleToAllStatuses,
          isTest: appStatus.isTest,
          categoryFixedPrices: appStatus.categoryFixedPrices,
          onCategoryChanged: (newCat) {
            setState(() => _selectedCategory = newCat);
          },
          onFilterChanged: (newState) {
            setState(() => _filterState = newState);
          },
          onClearAll: () {
            setState(() {
              _filterState = FilterState(); // Reset to defaults
              _selectedCategory = ShoeCategory.available; // 🎯 Default category on reset
            });
          },
        ),
        body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _isInitialLoading = true);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: StreamBuilder<List<Shoe>>(
            stream: _shoeStream,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _isInitialLoading) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ShoeListHeaderDelegate(
                        builder: (height) => _buildHeader(height, firebaseService),
                        maxHeight: headerMaxHeight,
                        minHeight: headerMinHeight,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => ShoeListItemSkeleton(),
                          childCount: 5,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              _processAndDisplayShoes(snapshot.data ?? []);
              _isInitialLoading = false;

              return CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ShoeListHeaderDelegate(
                      maxHeight: headerMaxHeight,
                      minHeight: headerMinHeight,
                      builder: (height) => _buildHeader(height, firebaseService),
                    ),
                  ),
                  if (_isLoadingExternalData)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(),
                    ),
                  if (_displayedShoes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final shoe = _displayedShoes[index];
                          final shoeKey = _getShoeKey(shoe);
                          return RepaintBoundary(
                            child: ShoeListItem(
                              key: ValueKey(shoeKey),
                              shoe: shoe,
                              isSelectionMode: _isSelectionMode,
                              isSelected: _selectedShoeIds.contains(shoeKey),
                              onToggleSelection: () => _toggleSelection(shoeKey),
                              onLongPress: () => _toggleSelection(shoeKey),
                              onCopyDataPressed: _onCopyShoe,
                              onShareDataPressed: (s) => _shareData([s]),
                              onEdit: () => showDialog(
                                context: context,
                                builder: (_) => ShoeFormDialogContent(
                                  shoe: shoe,
                                  firebaseService: firebaseService,
                                  existingShoes: _streamShoes,
                                ),
                              ),
                              onDelete: () => _deleteShoe(shoe),
                            ),
                          );
                        },
                        childCount: _displayedShoes.length,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _showToTop,
            builder: (context, show, child) {
              return AnimatedScale(
                scale: show ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.small(
                    heroTag: null, // 🎯 Fix Duplicate Hero Tag
                    onPressed: () {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.fastOutSlowIn,
                      );
                    },
                    backgroundColor: Colors.indigo.shade400,
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isFabVisible,
            builder: (context, isVisible, child) {
              return AnimatedSlide(
                offset: isVisible ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 300),
                child: AnimatedOpacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !isVisible,
                    child: FloatingActionButton(
                      heroTag: null, // 🎯 Fix Duplicate Hero Tag
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        showDialog(
                          context: context,
                          builder: (_) => ShoeFormDialogContent(
                            firebaseService: firebaseService,
                            existingShoes: _streamShoes,
                          ),
                        );
                      },
                      tooltip: 'Add New Shoe',
                      child: const Icon(Icons.add),
                      elevation: 6,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Close App?'),
        content: const Text('Are you sure you want to exit the Hive?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('STAY', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('EXIT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

}

class _ShoeListHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double height) builder;
  final double maxHeight;
  final double minHeight;

  _ShoeListHeaderDelegate({
    required this.builder,
    required this.maxHeight,
    required this.minHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final currentHeight = max(minHeight, maxHeight - shrinkOffset);
    return builder(currentHeight);
  }

  @override
  bool shouldRebuild(covariant _ShoeListHeaderDelegate oldDelegate) {
    return true; // Always rebuild to reflect latest data/callbacks
  }
}
