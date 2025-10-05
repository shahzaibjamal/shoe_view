import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Image/collage_builder.dart';
import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/in_app_purchase.dart';
import 'package:shoe_view/list_header.dart';
import 'package:shoe_view/shoe_form_dialog.dart';
import 'package:shoe_view/shoe_list_item.dart';

import 'shoe_model.dart';
import 'firebase_service.dart';

class ShoeListView extends StatefulWidget {
  // The list of shoes to display immediately while the stream connects
  final List<Shoe> initialShoes;

  const ShoeListView({
    super.key,
    this.initialShoes = const [], // Set a default to maintain optional usage
  });

  @override
  State<ShoeListView> createState() => _ShoeListViewState();
}

class _ShoeListViewState extends State<ShoeListView> {

  // Initialize the Firebase service
  final FirebaseService _firebaseService = FirebaseService();

  // --- State Variables for Sorting & Searching ---
  String _sortField = 'ItemId'; // Options: 'ItemId', 'size', 'sellingPrice'
  bool _sortAscending = true;
  bool _isLoadingExternalData = false;
  String _searchQuery = ''; // Tracks the text in the search bar
  List<Shoe> _filteredShoes = []; // Stores the result of the filtering step
  List<Shoe> _displayedShoes = []; // Stores the result of the filtering step
  List<Shoe> streamShoes = [];

  // New: Stores data manually fetched from a different source (like a different collection or query)
  List<Shoe> _manuallyFetchedShoes = [];

  final TextEditingController _searchController =
      TextEditingController(); // Controller for search input
  // ---------------------------------------

  @override
  void initState() {
    super.initState();
    // 1. Add listener for real-time search filtering as the user types
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Method to update the search state
  void _onSearchChanged() {
    // Update the search query state immediately on text change
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
    });
  }

  // --- FIX: Logic to refresh/add data from an external source ---
  void _onRefreshData() {
    setState(() {
      _isLoadingExternalData = true;
    });
    // 1. Fetch data from the external source/query defined in FirebaseService.
    _firebaseService
        .fetchData()
        .then((newShoes) {
          // 2. Update the state with the new data. This is crucial as it triggers
          // the StreamBuilder to rebuild and merge the lists.
          setState(() {
            // Here, we ADD the new shoes to the existing external list.
            // Use a Set to ensure only unique shoes are added (optional, but safer)
            final combinedShoes = <Shoe>{..._manuallyFetchedShoes, ...newShoes};
            _manuallyFetchedShoes = combinedShoes.toList();
            _isLoadingExternalData = false;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Fetched ${newShoes.length} item(s) and merged into the list.',
                ),
              ),
            );
          });
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to fetch external data: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        });
  }

  void _openInApp() {
    AppLogger.log('onrefresh');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SubscriptionUpgradePage(firebaseService: _firebaseService,)),
    );
  }

  // --- END FIX for _onRefreshData ---

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
      // Delete the document and the image from Firebase
      // await _firebaseService.deleteShoe(shoe);
      final response = await _firebaseService.deleteShoeFromCloud(shoe);
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

      // The StreamBuilder handles the UI update automatically
    }
  }

  void _onShareShoe(Shoe shoe) {
    _shareData([shoe]);
  }

  // --- Share All Data as Collage ---
  void _onShareAll() {
    _shareData(_displayedShoes);
  }

  void _shareData(List<Shoe> shoesToShare) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Set contentPadding to zero to remove default padding
          contentPadding: EdgeInsets.zero,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          content: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox.fromSize(
              child: CollageBuilder(
                firebaseService: _firebaseService,
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
    Clipboard.setData(ClipboardData(text: _copyData([shoe])));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shoes details copied to clipboard! ${shoe.shoeDetail}'),
      ),
    );
  }

  // --- Copy All Data to Clipboard ---
  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _copyData(_filteredShoes)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shoes details copied to clipboard! ${_filteredShoes.length}',
        ),
      ),
    );
  }

  String _copyData(List<Shoe> shoeList) {
    final buffer = StringBuffer();
    final gap = ' '; // base gap after numbering
    final tab = '     '; // base gap after numbering
    if (shoeList.length > 1) {
      buffer.writeln('Kick Hive Drop - ${shoeList.length} Pairs\n');
    }

    for (int i = 0; i < shoeList.length; i++) {
      final shoe = shoeList[i];
      final numbering = '${i + 1}.';
      final indent = ' ' * (numbering.length + gap.length);

      buffer.writeln('$numbering$gap${shoe.shoeDetail}');
      buffer.writeln(
        '$indent${tab}Sizes: EUR ${shoe.sizeEur}, UK ${shoe.sizeUk}',
      );
      buffer.writeln('$indent${tab}Price: Rs.${shoe.sellingPrice}/-');
      buffer.writeln('$indent${tab}Instagram: ${shoe.instagramLink}');
      buffer.writeln('$indent${tab}TikTok: ${shoe.tiktokLink}');
      buffer.writeln(); // blank line for separation
    }
    buffer.writeln('Tap to claim 📦');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // --- MODIFIED: Calculate 20% of the screen height for the custom header ---
    final double headerHeight = MediaQuery.of(context).size.height * 0.16;
    // *** No AppBar is used, only Scaffold body ***
    return Scaffold(
      body: SafeArea(
        // Use SafeArea to avoid status bar overlap
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
                });
              },
              onSortDirectionToggled: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                });
              },
              onCopyDataPressed: _copyAll,
              onShareDataPressed: _onShareAll,
              onRefreshDataPressed: _onRefreshData, // Now calls the new logic
              onInAppButtonPressed: _openInApp, // Now calls the new logic
            ),
            // NEW: Conditional loading indicator for manual refresh
            if (_isLoadingExternalData) const LinearProgressIndicator(),
            // Main Content Area (takes remaining space)
            Expanded(
              child: StreamBuilder<List<Shoe>>(
                // Use the list provided in the constructor as initial data
                initialData: widget.initialShoes,
                stream: _firebaseService.streamShoes(),
                builder: (context, snapshot) {
                  // --- Connection State Handling ---
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

                  // 1. Merge Stream Data and Manually Fetched Data
                  streamShoes = snapshot.data ?? [];
                  // Combine both lists and ensure uniqueness using a Set if itemIds are unique
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

                  // --- Data State Handling ---
                  if (combinedShoes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No shoes added yet. Click "+" to add the first entry!',
                      ),
                    );
                  }

                  // --- 2. Filter Logic (Applies all criteria EXCEPT 'lim' command) ---
                  _filteredShoes = combinedShoes.where((shoe) {
                    // This function already excludes 'lim' tokens for the match check
                    return ShoeQueryUtils.doesShoeMatchSmartQuery(shoe, _searchController.text.toLowerCase());
                  }).toList();
                  _displayedShoes = ShoeQueryUtils.sortAndLimitShoes(shoes: List<Shoe>.from(_filteredShoes), rawQuery: _searchController.text.toLowerCase(), sortField: _sortField, sortAscending: _sortAscending);
                  // Check if filtering/limiting resulted in an empty list
                  if (_displayedShoes.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Text('No shoes found matching "$_searchQuery".'),
                    );
                  }

                  // --- Display Data ---
                  return ListView.builder(
                    itemCount: _displayedShoes.length,
                    itemBuilder: (context, index) {
                      final shoe =
                          _displayedShoes[index]; // Use the final limited/sorted list
                      return ShoeListItem(
                        shoe: shoe,
                        onCopyDataPressed: _onCopyShoe,
                        onShareDataPressed: _onShareShoe,
                        onEdit: () => showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ShoeFormDialogContent(
                              shoe: shoe,
                              firebaseService: FirebaseService(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (BuildContext context) {
            return ShoeFormDialogContent(
              firebaseService: FirebaseService(),
              existingShoes: streamShoes,
            );
          },
        ),
        tooltip: 'Add New Shoe',
        child: const Icon(Icons.add),
      ),
    );
  }
}
