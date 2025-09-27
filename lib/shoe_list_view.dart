import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math'; // Added for price comparison logic
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
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
  String _sortField = 'itemId'; // Options: 'itemId', 'sellingPrice'
  bool _sortAscending = true;
  String _searchQuery = ''; // Tracks the text in the search bar
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

  // Helper method to build the image widget (network or file)
  Widget _buildShoeImage(String imagePath, String remoteImageUrl) {
    // Priority 1: Remote URL (from Firestore)
    if (remoteImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remoteImageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
        errorWidget: (context, url, error) => const Icon(Icons.error, size: 40),
      );
    }
    // Priority 2: Local File Path (from ImagePicker, not yet uploaded)
    else if (imagePath.isNotEmpty) {
      try {
        return Image.file(
          File(imagePath),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      } catch (e) {
        // Fallback if the path is invalid or file is missing
        return const Icon(Icons.broken_image, size: 40);
      }
    }
    // Fallback: No image available
    return const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
  }

  // Helper function for safe parsing
  int _safeIntParse(String? text) {
    if (text == null || text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }

  // Helper function for safe parsing
  double _safeDoubleParse(String? text) {
    if (text == null || text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  // New: Full Screen Image View
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        // Black background for a typical image viewing experience
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          // Tap anywhere to dismiss the full-screen view
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.75,
            alignment: Alignment.center,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain, // Show the whole image
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, size: 80, color: Colors.red),
                  )
                : const Icon(
                    Icons.image_not_supported,
                    size: 80,
                    color: Colors.grey,
                  ),
          ),
        ),
      ),
    );
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

  void _shareToWhatsapp(Shoe shoe) async {
    final imageFile = XFile(shoe.localImagePath);
    final image = CachedNetworkImage(
      imageUrl: shoe.remoteImageUrl,
      fit: BoxFit.contain, // Show the whole image
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (context, url, error) =>
          const Icon(Icons.error, size: 80, color: Colors.red),
    );
    await Share.shareXFiles([imageFile], text: 'Check out this image!');
  }

  void _showShoeDialog({Shoe? shoe, String? originalLocalPath}) async {
    // Controllers for the form fields
    final shoeIdController = TextEditingController(
      text: shoe != null ? shoe.itemId.toString() : '',
    );
    final shipmentIdController = TextEditingController(
      text: shoe?.shipmentId ?? '',
    );
    final nameController = TextEditingController(text: shoe?.shoeDetail ?? '');
    final sizeEurController = TextEditingController(text: shoe?.sizeEur ?? '');
    final sizeUkController = TextEditingController(text: shoe?.sizeUk ?? '');
    final priceController = TextEditingController(
      text: shoe != null ? shoe.sellingPrice.toString() : '',
    );
    final instagramController = TextEditingController(
      text: shoe?.instagramLink ?? '',
    );
    final tiktokController = TextEditingController(
      text: shoe?.tiktokLink ?? '',
    );

    print('originalLocalPath: $originalLocalPath');

    // Image state management for the dialog
    File? dialogImageFile =
        originalLocalPath != null && originalLocalPath.isNotEmpty
        ? File(originalLocalPath)
        : null;
    String currentRemoteImageUrl = shoe?.remoteImageUrl ?? '';

    // Track if the shoe is new to potentially disable editing the Item ID and Shipment ID fields
    final isEditing = shoe != null;

    await showDialog(
      context: context,
      builder: (context) {
        // Local state for tracking the loading process during save/upload
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // Build the image preview widget inside the dialog
            Widget imagePreview() {
              if (dialogImageFile != null) {
                // Show newly picked local image
                return Image.file(
                  dialogImageFile!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                );
              } else if (currentRemoteImageUrl.isNotEmpty) {
                // Show remote image if editing existing shoe
                return CachedNetworkImage(
                  imageUrl: currentRemoteImageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error, size: 60),
                );
              }
              return const Icon(
                Icons.image_not_supported,
                size: 60,
                color: Colors.grey,
              );
            }

            return AlertDialog(
              title: Text(isEditing ? 'Edit Shoe' : 'Add New Shoe'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: shoeIdController,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      // Disable editing Item ID when updating existing shoe
                      enabled:
                          !isEditing &&
                          !isLoading, // Disabled while editing AND loading
                      decoration: InputDecoration(
                        labelText: 'Item ID (e.g., 123)',
                        // Hint that ID cannot be changed once set
                        helperText: isEditing
                            ? 'Item ID cannot be changed.'
                            : null,
                      ),
                    ),
                    // --- UPDATED Shipment ID Field ---
                    TextField(
                      controller: shipmentIdController,
                      // Show numpad for input
                      keyboardType: TextInputType.number,
                      // Max length 3 characters
                      maxLength: 3,
                      // Disable editing Shipment ID when updating
                      enabled: !isEditing && !isLoading,
                      decoration: InputDecoration(
                        labelText: 'Shipment ID (e.g., 123)',
                        helperText: isEditing
                            ? 'Shipment ID cannot be changed.'
                            : null,
                      ),
                    ),
                    // --- END UPDATED FIELD ---
                    TextField(
                      controller: nameController,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(
                        labelText: 'Shoe Name/Detail',
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sizeEurController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            maxLength: 4,
                            enabled: !isLoading, // Disabled while loading
                            decoration: const InputDecoration(
                              labelText: 'Size EUR',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: sizeUkController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            maxLength: 4,
                            enabled: !isLoading, // Disabled while loading
                            decoration: const InputDecoration(
                              labelText: 'Size UK',
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(
                        labelText: 'Selling Price (Rs.)',
                      ), // Currency hint
                    ),
                    TextField(
                      controller: instagramController,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(
                        labelText: 'Instagram Link',
                      ),
                    ),
                    TextField(
                      controller: tiktokController,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(
                        labelText: 'TikTok Link',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick Image'),
                          // Disable image picking while saving
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 600,
                                  );
                                  if (picked != null) {
                                    dialogSetState(() {
                                      dialogImageFile = File(picked.path);
                                      // Clear remote URL if a new image is picked
                                      currentRemoteImageUrl = '';
                                    });
                                  }
                                },
                        ),
                        const SizedBox(width: 16),
                        // Image Preview
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: imagePreview(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  // Disable cancel while loading
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  // Disable button while loading
                  onPressed: isLoading
                      ? null
                      : () async {
                          // 1. Data Validation
                          final itemId = _safeIntParse(shoeIdController.text);
                          final shipmentId = shipmentIdController.text.trim();
                          final name = nameController.text.trim();

                          if (itemId == 0 ||
                              shipmentId.isEmpty ||
                              name.isEmpty) {
                            // Basic validation failure (you might want a better UI feedback here)
                            return;
                          }

                          // 2. Prepare new/updated Shoe object
                          final newShoe = (shoe ?? Shoe.empty()).copyWith(
                            itemId: itemId,
                            shipmentId: shipmentId,
                            shoeDetail: name,
                            sizeEur: sizeEurController.text.trim(),
                            sizeUk: sizeUkController.text.trim(),
                            sellingPrice: _safeDoubleParse(
                              priceController.text,
                            ),
                            instagramLink: instagramController.text.trim(),
                            tiktokLink: tiktokController.text.trim(),
                            localImagePath: dialogImageFile?.path ?? '',
                            remoteImageUrl:
                                currentRemoteImageUrl, // Maintain remote URL if no new image
                            isUploaded:
                                shoe?.isUploaded ??
                                false, // Maintain previous state
                            // documentId: shoe?.documentId ?? 0,
                          );

                          // Start loading state
                          dialogSetState(() {
                            isLoading = true;
                          });

                          try {
                            // 3. Save the data via the service (uses itemId as document key)
                            await _firebaseService.saveShoe(
                              newShoe,
                              localImageFile: dialogImageFile,
                            );

                            // 4. Close dialog on success
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            debugPrint('Error saving shoe: $e');
                            // If saving fails, reset loading state and let user try again/fix input
                            dialogSetState(() {
                              isLoading = false;
                            });
                            // NOTE: A more robust app would show a snackbar here
                          }
                        },
                  // Show spinner while loading, otherwise show the text
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(isEditing ? 'Update' : 'Add Shoe'),
                ),
              ],
            );
          },
        );
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
      // Delete the document and the image from Firebase
      await _firebaseService.deleteShoe(shoe);
      // The StreamBuilder handles the UI update automatically
    }
  }

  // --- MODIFIED Header Widget (20% height, no title, added search) ---
  Widget _buildHeader(double height) {
    return Container(
      height: height,
      color: Colors.blueGrey.shade800,
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 20.0,
        bottom: 8.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // New: Search Input Field
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Search: Name, Size (e.g., 42), or Price (e.g., <2500, >1500, =2100)...',
                hintStyle: TextStyle(
                  color: Colors.blueGrey.shade300,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.blueGrey.shade700,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 16.0,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged(); // Manually trigger search update
                        },
                      )
                    : null,
              ),
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              // Search happens on every keystroke via the listener in initState
            ),
          ),

          // Sort controls
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Sort By:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortField,
                  dropdownColor: Colors.blueGrey.shade700,
                  icon: const Icon(Icons.sort, color: Colors.white),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _sortField = newValue;
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'itemId',
                      child: Text(
                        'ID',
                        style: TextStyle(
                          color: _sortField == 'itemId'
                              ? Colors.amberAccent
                              : Colors.white,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'sellingPrice',
                      child: Text(
                        'Price',
                        style: TextStyle(
                          color: _sortField == 'sellingPrice'
                              ? Colors.amberAccent
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Button for toggling sort direction
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                  });
                },
                tooltip: 'Toggle Sort Direction',
              ),
            ],
          ),
        ],
      ),
    );
  }
  // --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // --- MODIFIED: Calculate 20% of the screen height for the custom header ---
    final double headerHeight = MediaQuery.of(context).size.height * 0.20;

    // *** No AppBar is used, only Scaffold body ***
    return Scaffold(
      body: SafeArea(
        // Use SafeArea to avoid status bar overlap
        child: Column(
          children: [
            // Custom Header
            _buildHeader(headerHeight),

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
                  List<Shoe> filteredShoes = shoes.where((shoe) {
                    return _doesShoeMatchSmartQuery(shoe);
                  }).toList();

                  if (filteredShoes.isEmpty) {
                    return Center(
                      child: Text('No shoes found matching "$_searchQuery".'),
                    );
                  }
                  // ---------------------------

                  // --- Client-Side Sorting Logic (applied to the filtered list) ---
                  final sortedShoes = List<Shoe>.from(filteredShoes);
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
                        onEdit: (localImagePath) {
                          _showShoeDialog(
                            shoe: shoe,
                            originalLocalPath: shoe.localImagePath,
                          );
                        },
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
        onPressed: () => _showShoeDialog(),
        tooltip: 'Add New Shoe',
        child: const Icon(Icons.add),
      ),
    );
  }
}
