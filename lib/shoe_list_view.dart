import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Helpers/shoe_response.dart';
import 'package:shoe_view/Image/collage_builder.dart';
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

class ShoeListView extends StatefulWidget {
  const ShoeListView({super.key});

  @override
  State<ShoeListView> createState() => _ShoeListViewState();
}

class _ShoeListViewState extends State<ShoeListView>
    with WidgetsBindingObserver {
  // --- UI State ---
  String _sortField = 'ItemId';
  bool _sortAscending = true;
  bool _isLoadingExternalData = false;
  String _searchQuery = '';
  final ValueNotifier<bool> _isFabVisible = ValueNotifier<bool>(true);

  // --- Data State ---
  List<Shoe> _streamShoes = []; // Raw data from stream
  List<Shoe> _displayedShoes = []; // Processed data (filtered & sorted)
  late Stream<List<Shoe>> _shoeStream; // 🎯 Memoize the stream

  // --- Memoization Utilities ---
  String _lastProcessedQuery = '';
  String _lastProcessedSortField = '';
  bool _lastProcessedSortAscending = true;
  int _lastProcessedListLength = -1; // Cheap hash for list change

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _lastScrollPosition = 0;

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
    final currentPosition = _scrollController.offset;
    final scrollingDown = currentPosition > _lastScrollPosition;
    final shouldBeVisible = !scrollingDown || currentPosition < 10.0;

    if (_isFabVisible.value != shouldBeVisible) {
      _isFabVisible.value = shouldBeVisible; // 🎯 Optimization: No setState here
    }
    _lastScrollPosition = currentPosition;
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  Future<void> _onRefreshData() async {
    setState(() => _isLoadingExternalData = true);
    final firebaseService = context.read<FirebaseService>();

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
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoadingExternalData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch external data: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    }
  }

  // --- Processing ---

  void _processAndDisplayShoes(List<Shoe> rawShoes) {
    final query = _searchController.text.toLowerCase();
    
    // Check if inputs have changed using reference equality for the list
    // This allows us to skip processing on simple UI rebuilds (scrolling, etc)
    // while still catching every Firestore update (which produces a new List reference).
    final inputsChanged = rawShoes != _streamShoes ||
        query != _lastProcessedQuery ||
        _sortField != _lastProcessedSortField ||
        _sortAscending != _lastProcessedSortAscending;

    if (!inputsChanged) {
      return; 
    }

    // Update references
    _streamShoes = rawShoes;
    _lastProcessedQuery = query;
    _lastProcessedSortField = _sortField;
    _lastProcessedSortAscending = _sortAscending;
    _lastProcessedListLength = rawShoes.length; // Keep for debug/logging if needed

    // Filter
    final filtered = rawShoes.where((shoe) {
      return ShoeQueryUtils.doesShoeMatchSmartQuery(shoe, query);
    }).toList();

    // Sort & Limit
    _displayedShoes = ShoeQueryUtils.sortAndLimitShoes(
      shoes: filtered,
      rawQuery: query,
      sortField: _sortField,
      sortAscending: _sortAscending,
    );

    // Trigger Image Warmup for new list (deferred)
    if (_displayedShoes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _warmUpImages(_displayedShoes);
      });
    }
  }

  void _warmUpImages(List<Shoe> shoes) {
    final cache = ShoeViewCacheManager();
    // Warm up only visible range or top items to save resources?
    // Current logic warms up all displayed items, which is okay for < 100 items.
    for (var shoe in shoes) {
      if (shoe.remoteImageUrl.isNotEmpty) {
        cache.getCachedOrDownloadFile(shoe.remoteImageUrl);
      }
    }
  }

  String _generateShareTextHelper(List<Shoe> shoes) {
    final appStatus = context.read<AppStatusNotifier>();
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          content: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox.fromSize(
              child: CollageBuilder(
                firebaseService: firebaseService,
                shoes: shoesToShare,
                text: _generateShareTextHelper(shoesToShare),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onCopyShoe(Shoe shoe) {
    AnalyticsService.logSelectContent(
        contentType: 'button', itemId: '_onCopyShoe');
    final text = _generateShareTextHelper([shoe]);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Copied: ${shoe.shoeDetail}',
              overflow: TextOverflow.ellipsis)),
    );
  }

  void _copyAll() {
    AnalyticsService.logSelectContent(
        contentType: 'button', itemId: '_onCopyAll');
    final text = _generateShareTextHelper(_displayedShoes);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_displayedShoes.length} items.')),
    );
  }

  void _deleteShoe(Shoe shoe) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Shoe'),
            content: Text(
              'Delete "${shoe.shoeDetail}" (ID: ${shoe.itemId})? This is permanent.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      final firebaseService = context.read<FirebaseService>();
      final response = await firebaseService.deleteShoe(shoe);
      if (response['success'] == false && mounted) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Error',
            message: response['message'],
            onDismissed: () {},
          ),
        );
      }
    }
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final double headerHeight = MediaQuery.of(context).size.height * 0.16;
    final firebaseService = context.read<FirebaseService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ListHeader(
              height: headerHeight,
              searchController: _searchController,
              searchQuery: _searchQuery,
              sortField: _sortField,
              sortAscending: _sortAscending,
              onSortFieldChanged: (value) {
                setState(() {
                  _sortField = value;
                  // Show feedback safely
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${ShoeQueryUtils.formatLabel(_sortField)}: ${_displayedShoes.length}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  });
                });
              },
              onSortDirectionToggled: () =>
                  setState(() => _sortAscending = !_sortAscending),
              onCopyDataPressed: _copyAll,
              onShareDataPressed: _onShareAll,
              onRefreshDataPressed: _onRefreshData,
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
                showDialog(
                  context: context,
                  builder: (_) =>
                      SettingsDialog(firebaseService: firebaseService),
                );
              },
              onSampleSendPressed: _onSampleSend,
              onSaveDataPressed: () =>
                  ShoeQueryUtils.saveShoesToAppExternal(_streamShoes),
            ),
            if (_isLoadingExternalData) const LinearProgressIndicator(),
            Expanded(
              child: StreamBuilder<List<Shoe>>(
                stream: _shoeStream, // 🎯 Use memoized stream
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)));
                  }

                  // Process Data
                  _processAndDisplayShoes(snapshot.data ?? []);

                  if (_displayedShoes.isEmpty) {
                    if (_searchQuery.isNotEmpty) {
                      return Center(
                          child: Text('No shoes found for "$_searchQuery"'));
                    }
                    return const Center(
                        child: Text('No shoes yet. Tap + to add one!'));
                  }

                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    controller: _scrollController,
                    itemCount: _displayedShoes.length,
                    itemBuilder: (context, index) {
                      final shoe = _displayedShoes[index];
                      // 🎯 ADD KEY: Using a unique key prevents "ghosting" or 
                      // cross-pollination of images when the list filters/shuffles.
                      return ShoeListItem(
                        key: ValueKey('${shoe.itemId}_${shoe.shipmentId}'),
                        shoe: shoe,
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _isFabVisible,
        builder: (context, isVisible, child) {
          return IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ShoeFormDialogContent(
                    firebaseService: firebaseService,
                    existingShoes: _streamShoes,
                  ),
                ),
                tooltip: 'Add New Shoe',
                child: const Icon(Icons.add),
              ),
            ),
          );
        },
      ),
    );
  }
}
