import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Image/collage_builder.dart';
import 'package:shoe_view/Services/analytics_service.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/Subscription/subscription_upgrade_page.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';
import 'package:shoe_view/list_header.dart';
import 'package:shoe_view/settings_dialog.dart';
import 'package:shoe_view/ShoeUpdateForm/shoe_form_dialog.dart';
import 'package:shoe_view/shoe_list_item.dart';

import 'shoe_model.dart';
import 'Services/firebase_service.dart';

class ShoeListView extends StatefulWidget {
  const ShoeListView({super.key});

  @override
  State<ShoeListView> createState() => _ShoeListViewState();
}

class _ShoeListViewState extends State<ShoeListView>
    with WidgetsBindingObserver {
  String _sortField = 'ItemId';
  bool _sortAscending = true;
  bool _isLoadingExternalData = false;
  String _searchQuery = '';
  List<Shoe> _filteredShoes = [];
  List<Shoe> _displayedShoes = [];
  List<Shoe> streamShoes = [];
  final List<Shoe> _manuallyFetchedShoes = [];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    final subscriptionManager = context.read<SubscriptionManager>();
    subscriptionManager.queryActivePurchases();

    // 🎯 NEW: Add Scroll Listener
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // 🎯 NEW: Dispose Scroll Controller and remove listener
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();

    super.dispose();
  }

  // 🎯 NEW: Logic to show/hide the FloatingActionButton
  double _lastScrollPosition = 0;
  void _scrollListener() {
    // 1. Check if the user is scrolling up or down
    final currentPosition = _scrollController.offset;
    final scrollingDown = currentPosition > _lastScrollPosition;

    // 2. Determine visibility based on direction and if scrolling is active
    final bool shouldBeVisible = !scrollingDown || currentPosition < 10.0;

    // Check if the state needs to change
    if (_isFabVisible != shouldBeVisible) {
      setState(() {
        _isFabVisible = shouldBeVisible;
      });
    }

    _lastScrollPosition = currentPosition;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt('lastSubscriptionCheck') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      AppLogger.log(
        "App resumed — refreshing subscription status $now - $lastCheck = ${now - lastCheck} > ${600000} ",
      );

      final subscriptionManager = context.read<SubscriptionManager>();
      if (now - lastCheck > 10 * 60 * 1000) {
        subscriptionManager.queryActivePurchases();
        prefs.setInt('lastSubscriptionCheck', now);
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  Future<void> _onRefreshData() async {
    setState(() {
      _isLoadingExternalData = true;
    });
    final firebaseService = context.read<FirebaseService>();

    try {
      final fetchedShoes = await firebaseService.fetchData();

      // Build a lookup map from streamShoes using composite key
      final existingKeys = {
        for (var shoe in streamShoes) '${shoe.itemId}_${shoe.shipmentId}': true,
      };

      final List<Shoe> newAvailableShoes = [];

      for (final shoe in fetchedShoes) {
        final key = '${shoe.itemId}_${shoe.shipmentId}';
        final isNew =
            !existingKeys.containsKey(key) &&
            (shoe.status == 'N/A' || shoe.status == 'Repaired');

        if (isNew) {
          newAvailableShoes.add(shoe);
          AppLogger.log(
            'NEW → ID: ${shoe.itemId}, Shipment: ${shoe.shipmentId}, Detail: ${shoe.shoeDetail}',
          );
        }
      }

      // Inject one new shoe for debug purposes
      if (newAvailableShoes.isNotEmpty) {
        await ShoeQueryUtils.debugAddShoesFromSheetData(
          firebaseService,
          newAvailableShoes,
        );
      }

      // Merge all fetched shoes into manually fetched list
      setState(() {
        _isLoadingExternalData = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fetched ${fetchedShoes.length} item(s) and merged into the list.',
            ),
          ),
        );
      });
    } catch (error) {
      setState(() {
        _isLoadingExternalData = false;
      });

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

  Future<void> _onSampleSend() async {
    final sampleShareCount = context.read<AppStatusNotifier>().sampleShareCount;

    if (_displayedShoes.isEmpty || sampleShareCount <= 0) {
      return;
    }

    const String kShoeDrawKey = 'sample_send_sequence';
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Shoe> shoeMap = {
      for (var shoe in _displayedShoes)
        '${shoe.shipmentId}_${shoe.itemId}': shoe,
    };

    final List<String> availableIdsPool = shoeMap.keys.toList();
    List<String> sequenceOfIds;
    final String? storedJsonString = prefs.getString(kShoeDrawKey);
    if (storedJsonString == null || storedJsonString.isEmpty) {
      sequenceOfIds = List.of(availableIdsPool)..shuffle(Random());
    } else {
      try {
        final List<dynamic> dynamicList = jsonDecode(storedJsonString);
        sequenceOfIds = dynamicList.cast<String>();
        sequenceOfIds.retainWhere((id) => shoeMap.containsKey(id));
      } catch (e) {
        sequenceOfIds = List.of(availableIdsPool)..shuffle(Random());
      }
    }

    if (sequenceOfIds.isEmpty) {
      sequenceOfIds = List.of(availableIdsPool)..shuffle(Random());
    }

    if (sequenceOfIds.isEmpty) {
      return;
    }

    final int itemsToTake = min(sampleShareCount, sequenceOfIds.length);
    final List<String> selectedIds = sequenceOfIds.take(itemsToTake).toList();
    final List<Shoe> selectedItems = selectedIds
        .map((id) => shoeMap[id]!)
        .toList();

    sequenceOfIds.removeRange(0, itemsToTake);

    _shareData(selectedItems);
    AppLogger.log('Remaining - ${sequenceOfIds.length}');
    final String updatedJsonString = jsonEncode(sequenceOfIds);
    await prefs.setString(kShoeDrawKey, updatedJsonString);
  }

  void _openInApp() async {
    final subscriptionManager = context.read<SubscriptionManager>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider.value(
          value: subscriptionManager,
          child: const SubscriptionUpgradePage(), // Added const
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    final firebaseService = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SettingsDialog(firebaseService: firebaseService);
      },
    );
  }

  void _deleteShoe(Shoe shoe) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Shoe'),
            content: Text(
              'Are you sure you want to delete "${shoe.shoeDetail}" (ID: ${shoe.itemId})? This action is permanent.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      final firebaseService = context.read<FirebaseService>();
      final response = await firebaseService.deleteShoe(shoe);
      ShoeQueryUtils.logDynamic(response);
      if (response['success'] == false) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Something went wrong. Please try again.',
            message: response['message'],
            onDismissed: () => {},
          ),
        );
      }
    }
  }

  void _onShareShoe(Shoe shoe) {
    AnalyticsService.logSelectContent(
      contentType: 'button',
      itemId: '_onShareShoe',
    );
    _shareData([shoe]);
  }

  void _onShareAll() {
    AnalyticsService.logSelectContent(
      contentType: 'button',
      itemId: '_onShareAll',
    );
    _shareData(_displayedShoes);
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
                text: _copyData(shoesToShare),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onCopyShoe(Shoe shoe) {
    AnalyticsService.logSelectContent(
      contentType: 'button',
      itemId: '_onCopyShoe',
    );
    Clipboard.setData(ClipboardData(text: _copyData([shoe])));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shoes details copied to clipboard! ${shoe.shoeDetail}'),
      ),
    );
  }

  void _copyAll() {
    AnalyticsService.logSelectContent(
      contentType: 'button',
      itemId: '_onCopyAll',
    );
    Clipboard.setData(ClipboardData(text: _copyData(_displayedShoes)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shoes details copied to clipboard! ${_displayedShoes.length}',
        ),
      ),
    );
  }

  String _copyData(List<Shoe> shoeList) {
    final buffer = StringBuffer();
    final gap = shoeList.length > 1 ? '    ' : '';

    shoeList = shoeList.take(CollageBuilder.maxImages).toList();
    if (shoeList.length > 1) {
      buffer.writeln('Kick Hive Drop - ${shoeList.length} Pairs\n');
    }

    final isSold = _sortField.toLowerCase().contains('sold');

    for (int i = 0; i < shoeList.length; i++) {
      final shoe = shoeList[i];
      final numbering = shoeList.length > 1 ? '${i + 1}. ' : '';
      final indent = ' ' * (numbering.length) + gap;

      buffer.writeln('$numbering${shoe.shoeDetail}');
      if (shoe.sizeEur != null && shoe.sizeEur!.length > 1) {
        String line = '${indent}Sizes: EUR ';
        for (var size in shoe.sizeEur!) {
          line += '$size, ';
        }
        buffer.writeln(line.trim().replaceAll(RegExp(r',$'), ''));
      } else {
        buffer.writeln(
          '${indent}Sizes: EUR ${shoe.sizeEur?.first}, UK ${shoe.sizeUk?.first}',
        );
      }

      final appStatus = context.read<AppStatusNotifier>();
      final currencyCode = appStatus.currencyCode;
      final isReparedInfoAvailable = appStatus.isRepairedInfoAvailable;
      final symbol = ShoeQueryUtils.getSymbolFromCode(currencyCode);

      if (isSold) {
        // buffer.writeln('${indent}❌ SOLD ❌');
      } else {
        buffer.writeln('${indent}Price: $symbol${shoe.sellingPrice}/-');
        buffer.writeln('${indent}Condition: ${shoe.condition}/10');
      }
      if (shoe.instagramLink.isNotEmpty) {
        buffer.writeln('${indent}Instagram: ${shoe.instagramLink}');
      }
      if (shoe.tiktokLink.isNotEmpty) {
        buffer.writeln('${indent}TikTok: ${shoe.tiktokLink}');
      }
      if (isReparedInfoAvailable && shoe.status == 'Repaired') {
        String notes = shoe.notes;
        if (shoe.notes.contains("Not repaired")) {
          notes = notes.replaceAll("Not repaired", "").trim();
        } else {
          buffer.writeln('$indent❌❌ Repaired ❌❌');
        }
        buffer.writeln('${indent}Note: ✨$notes✨');
        buffer.writeln('${indent}Images: ${shoe.imagesLink}');
      }
      if (isSold) {
        buffer.writeln(); // blank line for separation
        buffer.writeln('${indent}❌ SOLD ❌');
      }
      buffer.writeln(); // blank line for separation
    }

    // Only add "Tap to claim" if none are sold
    if (!isSold) {
      buffer.writeln('Tap to claim 📦');
    }

    return buffer.toString();
  }

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
              searchQuery: _searchController.text,
              sortField: _sortField,
              sortAscending: _sortAscending,
              onSortFieldChanged: (value) {
                setState(() {
                  _sortField = value;

                  // Wait for the frame to complete before accessing updated list
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${ShoeQueryUtils.formatLabel(_sortField)}: ${_displayedShoes.length}',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  });
                });
              },
              onSortDirectionToggled: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                });
              },
              onCopyDataPressed: _copyAll,
              onShareDataPressed: _onShareAll,
              onRefreshDataPressed: _onRefreshData,
              onInAppButtonPressed: _openInApp,
              onSettingsButtonPressed: _openSettingsDialog,
              onSampleSendPressed: _onSampleSend,
            ),
            if (_isLoadingExternalData) const LinearProgressIndicator(),
            Expanded(
              child: StreamBuilder<List<Shoe>>(
                stream: firebaseService.streamShoes(),
                builder: (context, snapshot) {
                  // ... (StreamBuilder logic for data processing)
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint('Firestore Stream Error: ${snapshot.error}');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading data: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  streamShoes = snapshot.data ?? [];
                  final allShoesSet = <String, Shoe>{};
                  if (_manuallyFetchedShoes.isEmpty) {
                    for (var shoe in streamShoes) {
                      allShoesSet['${shoe.itemId}_${shoe.shipmentId}'] = shoe;
                    }
                  }

                  for (var shoe in _manuallyFetchedShoes) {
                    allShoesSet['${shoe.itemId}_${shoe.shipmentId}'] = shoe;
                  }

                  final combinedShoes = allShoesSet.values.toList();

                  if (combinedShoes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No shoes added yet. Click "+" to add the first entry!',
                      ),
                    );
                  }

                  _filteredShoes = combinedShoes.where((shoe) {
                    return ShoeQueryUtils.doesShoeMatchSmartQuery(
                      shoe,
                      _searchController.text.toLowerCase(),
                    );
                  }).toList();

                  _displayedShoes = ShoeQueryUtils.sortAndLimitShoes(
                    shoes: List<Shoe>.from(_filteredShoes),
                    rawQuery: _searchController.text.toLowerCase(),
                    sortField: _sortField,
                    sortAscending: _sortAscending,
                  );

                  if (_displayedShoes.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Text('No shoes found matching "$_searchQuery".'),
                    );
                  }

                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    controller: _scrollController,
                    itemCount: _displayedShoes.length,
                    itemBuilder: (context, index) {
                      final shoe = _displayedShoes[index];
                      return ShoeListItem(
                        shoe: shoe,
                        onCopyDataPressed: _onCopyShoe,
                        onShareDataPressed: _onShareShoe,
                        onEdit: () => showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ShoeFormDialogContent(
                              shoe: shoe,
                              firebaseService: firebaseService,
                              existingShoes: streamShoes,
                            );
                          },
                        ),
                        onDelete: () {
                          _deleteShoe(shoe);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // 🎯 FIX: Wrap the FAB with an AnimatedOpacity
      floatingActionButton: IgnorePointer(
        ignoring: !_isFabVisible,
        child: AnimatedOpacity(
          opacity: _isFabVisible ? 1.0 : 0.0, // Control visibility
          duration: const Duration(milliseconds: 300), // Smooth animation
          child: FloatingActionButton(
            onPressed: () => showDialog(
              context: context,
              builder: (BuildContext context) {
                return ShoeFormDialogContent(
                  // Use context.read for dependency
                  firebaseService: firebaseService,
                  existingShoes: streamShoes,
                );
              },
            ),
            tooltip: 'Add New Shoe',
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
