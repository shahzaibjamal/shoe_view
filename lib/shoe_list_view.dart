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
  // Initialize the Firebase service
  final FirebaseService _firebaseService = FirebaseService();

  // --- State Variables for Sorting & Searching ---
  String _sortField = 'size'; // Options: 'size', 'sellingPrice'
  bool _sortAscending = true;
  String _searchQuery = ''; // Tracks the text in the search bar
  static const double _epsilon = 1e-9;
  List<Shoe> _filteredShoes = [];
  final TextEditingController _searchController =
      TextEditingController(); // Controller for search input
  // ---------------------------------------

  @override
  void initState() {
    super.initState();
    // 1. Add listener for real-time search filtering as the user types
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForTrialExpiration(); // or show your Snackbar/Dialog here
    });
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

  /// Refactored Smart Query Logic:
  /// The shoe must match ALL filter requirements derived from the query tokens:
  /// 1. Price: Must match combined range/exact price condition (if [<>=~] is present).
  /// 2. Shipment ID: Must contain ID (if # is present).
  /// 3. Size/Text: Any remaining token must match EITHER exact size OR shoeDetail text.
  bool _doesShoeMatchSmartQuery(Shoe shoe) {
    final rawQuery = _searchQuery;
    if (rawQuery.isEmpty) return true;

    // 1. Tokenize the query and remove 'lim' commands
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
        final sizeCriteria = token
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        bool matchesSizeOr = sizeCriteria.any(
          (sizeStr) =>
              shoe.sizeEur.trim() == sizeStr || shoe.sizeUk.trim() == sizeStr,
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
          // Treat as exact size search (e.g., "42")
          final sizeStr = token;
          final matchesSize =
              shoe.sizeEur.trim() == sizeStr || shoe.sizeUk.trim() == sizeStr;

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

  List<Shoe> getFilteredShoes(List<Shoe> shoes) {
    final rawQuery = _searchQuery.trim().toLowerCase();
    if (rawQuery.isEmpty) return shoes;

    final tokens = rawQuery
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    // Extract lim token
    String? limType;
    int? limCount;
    final limRegex = RegExp(r'^lim([<>=~])(\d+)$');

    final filterTokens = <String>[];
    for (final token in tokens) {
      final match = limRegex.firstMatch(token);
      if (match != null) {
        limType = match.group(1); // <, >, ~
        limCount = int.tryParse(match.group(2)!);
      } else {
        filterTokens.add(token);
      }
    }

    // Apply filtering
    final filteredShoes = shoes.where((shoe) {
      _searchQuery = filterTokens.join(' ');
      return _doesShoeMatchSmartQuery(shoe);
    }).toList();

    // Apply limiting
    if (limType != null && limCount != null && limCount > 0) {
      if (limType == '<') {
        filteredShoes.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
        return filteredShoes.take(limCount).toList();
      } else if (limType == '>') {
        filteredShoes.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
        return filteredShoes.take(limCount).toList();
      } else if (limType == '~') {
        filteredShoes.shuffle();
        return filteredShoes.take(limCount).toList();
      }
    }

    return filteredShoes;
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
      // Delete the document and the image from Firebase
      await _firebaseService.deleteShoe(shoe);
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
    // Implement trial expiration logic here
    // For example, check if the trial period has ended and update the UI or state accordingly
    final isTrial = context.watch<AppStatusNotifier>().isTrial;

    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(SnackBar(content: Text('This is a trial!')));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trial Expired'),
        content: Text('${isTrial ? '' : 'Your trial period has ended.'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onCopyShoe(Shoe shoe) {
    _copyData([shoe]);
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

    for (int i = 0; i < shoeList.length; i++) {
      final shoe = shoeList[i];
      final numbering = '${i + 1}.';
      final indent = ' ' * (numbering.length + gap.length);

      buffer.writeln('${numbering}${gap}Name: ${shoe.shoeDetail}');
      buffer.writeln('${indent}Sizes: EUR ${shoe.sizeEur}, UK ${shoe.sizeUk}');
      buffer.writeln('${indent}Price: Rs.${shoe.sellingPrice}');
      buffer.writeln('${indent}Instagram: ${shoe.instagramLink}');
      buffer.writeln('${indent}TikTok: ${shoe.tiktokLink}');
      buffer.writeln(); // blank line for separation
    }

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
            ),

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

                  final shoes = snapshot.data;

                  // --- Data State Handling ---
                  if (shoes == null || shoes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No shoes added yet. Click "+" to add the first entry!',
                      ),
                    );
                  }

                  // --- Filter Logic (using the new smart query acceptor) ---
                  // _filteredShoes = shoes.where((shoe) {
                  //   return _doesShoeMatchSmartQuery(shoe);
                  // }).toList();
                  _filteredShoes = getFilteredShoes(shoes);
                  print('before  ${_filteredShoes.length}');
                  if (_filteredShoes.isEmpty) {
                    return Center(
                      child: Text('No shoes found matching "$_searchQuery".'),
                    );
                  }
                  // ---------------------------

                  // --- Client-Side Sorting Logic (applied to the filtered list) ---
                  final sortedShoes = List<Shoe>.from(_filteredShoes);
                  print('sortedShoes  ${_filteredShoes.length}');
                  sortedShoes.sort((a, b) {
                    int comparison = 0;
                    if (_sortField == 'size') {
                      // FIX: Parse size strings to double for correct numerical comparison
                      final sizeA = double.tryParse(a.sizeEur) ?? 0.0;
                      final sizeB = double.tryParse(b.sizeEur) ?? 0.0;
                      comparison = sizeA.compareTo(sizeB);
                    } else if (_sortField == 'sellingPrice') {
                      // Sort by Selling Price (double)
                      comparison = a.sellingPrice.compareTo(b.sellingPrice);
                    }
                    // Apply ascending/descending direction
                    return _sortAscending ? comparison : -comparison;
                  });
                  // -------------------------------------
                  print('sortedShoes after ${_filteredShoes.length}');

                  // --- Display Data ---
                  return ListView.builder(
                    itemCount: sortedShoes.length,
                    itemBuilder: (context, index) {
                      final shoe = sortedShoes[index]; // Use the sorted list
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
