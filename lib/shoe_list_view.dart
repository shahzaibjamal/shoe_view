import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:math'; // Added for price comparison logic
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Image/collage_builder.dart';
import 'package:shoe_view/app_status_notifier.dart';
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
  // Define a small tolerance for robust floating point comparison at boundaries
  static const double _epsilon = 1e-9;

  // Initialize the Firebase service
  final FirebaseService _firebaseService = FirebaseService();

  // --- State Variables for Sorting & Searching ---
  String _sortField = 'ItemId'; // Options: 'ItemId', 'size', 'sellingPrice'
  bool _sortAscending = true;
  bool _isLoadingExternalData = false;
  String _searchQuery = ''; // Tracks the text in the search bar
  List<Shoe> _filteredShoes = []; // Stores the result of the filtering step

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

  // Helper function for safe parsing
  double _safeDoubleParse(String? text) {
    if (text == null || text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  /// The shoe must match ALL filter requirements derived from the query tokens.
  String _formatSizeForComparison(dynamic size) {
    if (size == null) return '';
    // Convert to string, trim, and remove trailing .0 if it's a whole number
    return size.toString().trim().replaceAll(RegExp(r'\.0$'), '');
  }


  /// The shoe must match ALL filter requirements derived from the query tokens.
  bool _doesShoeMatchSmartQuery(Shoe shoe) {
    final rawQuery = _searchQuery;
    if (rawQuery.isEmpty) return true;

    // 1. Tokenize the query and EXCLUDE 'lim' commands
    final queryTokens = rawQuery
        .toLowerCase()
        .split(RegExp(r'\s+')) // Split by one or more spaces
        .where((s) => s.isNotEmpty && !s.startsWith('lim'))
        .toList();

    if (queryTokens.isEmpty) return true;

    bool allFiltersMatch = true;
    bool isPriceFilterActive = false;

    // Regex for price tokens and any text/size tokens
    final priceRegex = RegExp(r'^([<>=~])(\d+\.?\d*)$');

    // --- 2. Process tokens for individual/instant checks (Shipment ID, Size OR, Pure Size, Text) ---
    for (final token in queryTokens) {
      final priceMatch = priceRegex.firstMatch(token);

      if (priceMatch != null) {
        // Price filter token: Mark price filter active, continue to process other tokens
        isPriceFilterActive = true;
        continue;
      }
      // Shipment ID Filter (e.g., #12345): Must match or fail
      else if (token.startsWith('#')) {
        final idQuery = token.substring(1).trim();
        // Convert integer shipmentId to string for comparison
        if (!shoe.shipmentId.toString().contains(idQuery)) {
          allFiltersMatch = false;
          break; // Failed Shipment ID filter
        }
      }
      // Size OR Filter (e.g., 42|43): Must match any size in the OR list or fail
      else if (token.contains('|')) {
        final rawSizeCriteria = token
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        
        // MODIFIED: Expand criteria to include the next +0.5 size for every input
        final Set<String> targetSizes = {}; // Use Set to automatically handle duplicates
        
        for (final sizeStr in rawSizeCriteria) {
          // 1. Add the exact input size (formatted for comparison)
          targetSizes.add(_formatSizeForComparison(sizeStr));
          
          // 2. Calculate and add the next half size (e.g., 44.5 input includes 45)
          final inputSize = double.tryParse(sizeStr);
          if (inputSize != null) {
              final nextHalfSize = inputSize + 0.5;
              targetSizes.add(_formatSizeForComparison(nextHalfSize));
          }
        }
        
        // Use helper for clean shoe sizes
        final shoeSizeEur = _formatSizeForComparison(shoe.sizeEur);
        final shoeSizeUk = _formatSizeForComparison(shoe.sizeUk);
        
        // Check if either shoe size is in the list of expanded target sizes
        bool matchesSizeOr = targetSizes.any(
          (targetStr) =>
              shoeSizeEur == targetStr || shoeSizeUk == targetStr,
        );

        if (!matchesSizeOr) {
          allFiltersMatch = false;
          break; // Failed Size OR filter
        }
      }
      // Pure Number / Text Filter: Token must match EITHER exact size OR text detail
      else {
        final isPureNumber = RegExp(r'^\d+(\.\d+)?$').hasMatch(token);

        if (isPureNumber) {
          // Treat as exact size search (e.g., "42" or "42.5")
          final sizeStr = token;

          // MODIFIED: Auto-include the next half size for any numeric input
          final Set<String> targetSizeStrings = {};
          
          // 1. Add the exact input size (formatted for comparison)
          targetSizeStrings.add(_formatSizeForComparison(sizeStr));
          
          // 2. Calculate and add the next half size
          final inputSize = double.tryParse(sizeStr);
          if (inputSize != null) {
              final nextHalfSize = inputSize + 0.5;
              targetSizeStrings.add(_formatSizeForComparison(nextHalfSize));
          }
          
          // Get the shoe sizes as strings for comparison (maintaining safety)
          final shoeSizeEurStr = _formatSizeForComparison(shoe.sizeEur);
          final shoeSizeUkStr = _formatSizeForComparison(shoe.sizeUk);
          
          // Check for exact match (e.g. "44.5") OR next half-size match (e.g. "45") in either EUR or UK
          final matchesSize = targetSizeStrings.any(
            (targetStr) =>
                shoeSizeEurStr == targetStr || shoeSizeUkStr == targetStr,
          );
          
          if (!matchesSize) {
            allFiltersMatch = false;
            break; // Failed Pure Number Size filter
          }
        } else {
          // Treat as standard text search (e.g., "adidas")
          if (!shoe.shoeDetail.toLowerCase().contains(token)) {
            allFiltersMatch = false;
            break; // Failed Text filter
          }
        }
      }
    }

    // If any non-price filter failed in the first pass, return false immediately
    if (allFiltersMatch == false) {
      return false;
    }

    // --- 3. Evaluate Combined Price Filter (if active) ---
    if (isPriceFilterActive) {
      double? lowerBound;
      double? upperBound;
      double? exactPrice;

      for (final token in queryTokens) {
        final match = priceRegex.firstMatch(token);
        if (match == null) continue; // Skip non-price tokens

        final operator = match.group(1); // <, >, =, or ~
        final valueStr = match.group(2);
        final value = _safeDoubleParse(valueStr);

        if (operator == '=') {
          exactPrice = value;
        } else if (operator == '<') {
          upperBound = upperBound == null ? value : min(upperBound, value);
        } else if (operator == '>') {
          lowerBound = lowerBound == null ? value : max(lowerBound, value);
        } else if (operator == '~') {
          // Range filter (~1500 means 1000 to 2000, i.e., +/- 500)
          const range = 500.0;
          lowerBound = lowerBound == null
              ? value - range
              : max(lowerBound, value - range);
          upperBound = upperBound == null
              ? value + range
              : min(upperBound, value + range);
        }
      }

      final price = shoe.sellingPrice;

      if (exactPrice != null) {
        // Exact match check with tolerance
        return (price - exactPrice).abs() < _epsilon;
      }

      // Check bounds with tolerance for floating point safety
      if (lowerBound != null && price < lowerBound - _epsilon) {
        return false;
      }

      if (upperBound != null && price > upperBound + _epsilon) {
        return false;
      }
      // If it got this far, it passed the price filter.
      return true;
    }

    // If we reach here, and all individual filters passed (and no price filter was active), we match.
    return true;
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
      await _firebaseService.deleteShoeFromCloud(shoe);
      // The StreamBuilder handles the UI update automatically
    }
  }

  void _onShareShoe(Shoe shoe) {
    _ShareData([shoe]);
  }

  // --- Share All Data as Collage ---
  void _onShareAll() {
    _ShareData(_filteredShoes);
  }

  void _ShareData(List<Shoe> shoesToShare) {
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
                shoes: shoesToShare,
                text: _copyData(shoesToShare),
              ),
            ),
          ),
        );
      },
    );
  }

  void _checkForTrialExpiration() {
    // Place trial expiration logic here if needed
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
    print(shoeList.length);
    if (shoeList.length > 1) {
      buffer.writeln('Kick Hive Drop - ${shoeList.length} Pairs\n');
    }

    for (int i = 0; i < shoeList.length; i++) {
      final shoe = shoeList[i];
      final numbering = '${i + 1}.';
      final indent = ' ' * (numbering.length + gap.length);

      buffer.writeln('${numbering}${gap}${shoe.shoeDetail}');
      buffer.writeln(
        '${indent}${tab}Sizes: EUR ${shoe.sizeEur}, UK ${shoe.sizeUk}',
      );
      buffer.writeln('${indent}${tab}Price: Rs.${shoe.sellingPrice}/-');
      buffer.writeln('${indent}${tab}Instagram: ${shoe.instagramLink}');
      buffer.writeln('${indent}${tab}TikTok: ${shoe.tiktokLink}');
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
                  final streamShoes = snapshot.data ?? [];
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
                    return _doesShoeMatchSmartQuery(shoe);
                  }).toList();

                  // --- 3. Client-Side Sorting Logic (applied to the filtered list) ---
                  // Start with the filtered list
                  List<Shoe> displayedShoes = List<Shoe>.from(_filteredShoes);

                  displayedShoes.sort((a, b) {
                    // First: sort by shipmentId (always ascending)
                    final shipmentA = int.tryParse(a.shipmentId) ?? 0;
                    final shipmentB = int.tryParse(b.shipmentId) ?? 0;
                    int comparison = shipmentA.compareTo(shipmentB);

                    // If shipmentId is equal, sort by selected field
                    if (comparison == 0) {
                      if (_sortField == 'size') {
                        final sizeA = double.tryParse(a.sizeEur) ?? 0.0;
                        final sizeB = double.tryParse(b.sizeEur) ?? 0.0;
                        comparison = sizeA.compareTo(sizeB);
                      } else if (_sortField == 'sellingPrice') {
                        comparison = a.sellingPrice.compareTo(b.sellingPrice);
                      } else if (_sortField == 'ItemId') {
                        comparison = a.itemId.compareTo(b.itemId);
                      }

                      // Apply ascending/descending to secondary field only
                      if (!_sortAscending) {
                        comparison = -comparison;
                      }
                    }

                    return comparison;
                  });

                  // --- 4. Limiting and Randomization Logic (Applied AFTER Filtering & Sorting) ---
                  final rawQuery = _searchController.text.toLowerCase();
                  final limRegex = RegExp(r'lim([<>]|~)(\d+)');
                  final limMatch = limRegex.firstMatch(rawQuery);

                  if (limMatch != null) {
                    final operator = limMatch.group(1);
                    final limitValue =
                        int.tryParse(limMatch.group(2) ?? '0') ?? 0;

                    if (limitValue > 0) {
                      if (operator == '<') {
                        // lim<N: Show only the top N shoes (Limit)
                        displayedShoes = displayedShoes
                            .take(limitValue)
                            .toList();
                      } else if (operator == '>') {
                        // lim>N: Show shoes starting from the N+1-th position (Offset/Skip)
                        if (displayedShoes.length > limitValue) {
                          displayedShoes = displayedShoes
                              .skip(limitValue)
                              .toList();
                        } else {
                          displayedShoes =
                              []; // Show none if offset is too large
                        }
                      } else if (operator == '~') {
                        // lim~N: Randomly select N shoes
                        final random = Random();
                        displayedShoes = List<Shoe>.from(displayedShoes)
                          ..shuffle(random)
                          ..take(limitValue)
                          ..toList();
                      }
                    }
                  }
                  // -----------------------------------------------------------------

                  // Check if filtering/limiting resulted in an empty list
                  if (displayedShoes.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Text('No shoes found matching "$_searchQuery".'),
                    );
                  }

                  // --- Display Data ---
                  return ListView.builder(
                    itemCount: displayedShoes.length,
                    itemBuilder: (context, index) {
                      final shoe =
                          displayedShoes[index]; // Use the final limited/sorted list
                      return ShoeListItem(
                        shoe: shoe,
                        onCopyDataPressed: _onCopyShoe,
                        onShareDataPressed: _onShareShoe,
                        onEdit: (localImagePath) => showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return ShoeFormDialogContent(
                              shoe: shoe,
                              firebaseService: FirebaseService(),
                              originalLocalPath: localImagePath,
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
            return ShoeFormDialogContent(firebaseService: FirebaseService());
          },
        ),
        tooltip: 'Add New Shoe',
        child: const Icon(Icons.add),
      ),
    );
  }
}
