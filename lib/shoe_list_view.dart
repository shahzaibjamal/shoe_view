import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:math'; // Added for price comparison logic
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoe_view/Image/collage_builder.dart';
import 'package:shoe_view/list_header.dart';
import 'package:shoe_view/shoe_form_dialog.dart';
import 'package:shoe_view/shoe_list_item.dart';
import 'package:path_provider/path_provider.dart';

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
  String _sortField = 'itemId'; // Options: 'itemId', 'sellingPrice'
  bool _sortAscending = true;
  String _searchQuery = ''; // Tracks the text in the search bar
  List<Shoe> _filteredShoes = [];
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

  void _onSearchChangedText(String value) {
    // Update the search query state immediately on text change
    setState(() {
      _searchQuery = value.toLowerCase().trim();
    });
  }

  // Helper function for safe parsing
  double _safeDoubleParse(String? text) {
    if (text == null || text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  // ------------------------------------

  /// New Smart Query Logic:
  /// 1. If any price operator (<, >, =) is present, filter ONLY by price.
  /// 2. If the query is a pure number (including decimals), filter ONLY by size (exact match string).
  /// 3. Otherwise, filter by shoeDetail (text search).
  bool _doesShoeMatchSmartQuery(Shoe shoe) {
    final query = _searchQuery;
    if (query.isEmpty) return true;

    // Regex to identify price operators and values: [<>=]\s*(\d+\.?\d*)
    final priceRegex = RegExp(r'([<>=])\s*(\d+\.?\d*)');
    final matches = priceRegex.allMatches(query);

    // --- 1. PRICE FILTERING ---
    if (matches.isNotEmpty) {
      // If any price condition is present, assume user is looking for price.

      double? lowerBound;
      double? upperBound;
      double? exactPrice;

      for (var match in matches) {
        final operator = match.group(1); // <, >, or =
        final valueStr = match.group(
          2,
        ); // The number part (e.g., "2500" or "1500.50")
        final value = _safeDoubleParse(valueStr);

        if (operator == '=') {
          // Exact match takes precedence, stop processing bounds
          exactPrice = value;
          break;
        } else if (operator == '<') {
          // Keep the tightest upper bound (minimum value with '<')
          upperBound = upperBound == null ? value : min(upperBound, value);
        } else if (operator == '>') {
          // Keep the tightest lower bound (maximum value with '>')
          lowerBound = lowerBound == null ? value : max(lowerBound, value);
        }
      }

      final price = shoe.sellingPrice;

      if (exactPrice != null) {
        // Exact match check
        return price == exactPrice;
      }

      if (lowerBound != null && price < lowerBound) {
        return false; // Fails lower bound check
      }

      if (upperBound != null && price > upperBound) {
        return false; // Fails upper bound check
      }

      // If we reach here, and we had valid price criteria, the shoe matches.
      return lowerBound != null || upperBound != null;
    }

    // Clean query of spaces for number check (e.g., "42 5" should fail, "42.5" should pass)
    final cleanQuery = query.replaceAll(' ', '');
    final isPureNumber = RegExp(r'^\d+(\.\d+)?$').hasMatch(cleanQuery);

    // --- 2. SIZE FILTERING (Pure Number/Decimal) ---
    if (isPureNumber) {
      // Treat as size search (exact match on EUR or UK size strings).
      final sizeStr = cleanQuery;

      final matchesSize =
          shoe.sizeEur.trim() == sizeStr || shoe.sizeUk.trim() == sizeStr;

      return matchesSize;
    }

    // --- 3. TEXT FILTERING (Default) ---
    // If no specific pattern (price or pure size number) was found, treat as shoe detail search.
    return shoe.shoeDetail.toLowerCase().contains(query);
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
            child: 
            SizedBox.fromSize(
              child: CollageBuilder(shoes: shoesToShare, text: _copyData(shoesToShare)),
            ),
          ),
        );
      },
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
              onSortFieldChanged: _onSearchChangedText,
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
                  _filteredShoes = shoes.where((shoe) {
                    return _doesShoeMatchSmartQuery(shoe);
                  }).toList();

                  if (_filteredShoes.isEmpty) {
                    return Center(
                      child: Text('No shoes found matching "$_searchQuery".'),
                    );
                  }
                  // ---------------------------

                  // --- Client-Side Sorting Logic (applied to the filtered list) ---
                  final sortedShoes = List<Shoe>.from(_filteredShoes);
                  sortedShoes.sort((a, b) {
                    int comparison = 0;
                    if (_sortField == 'itemId') {
                      // Sort by Item ID (int)
                      comparison = a.itemId.compareTo(b.itemId);
                    } else if (_sortField == 'sellingPrice') {
                      // Sort by Selling Price (double)
                      comparison = a.sellingPrice.compareTo(b.sellingPrice);
                    }
                    // Apply ascending/descending direction
                    return _sortAscending ? comparison : -comparison;
                  });
                  // -------------------------------------

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
