import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

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

  // --- New State Variables for Sorting ---
  String _sortField = 'itemId'; // Options: 'itemId', 'sellingPrice'
  bool _sortAscending = true;
  // ---------------------------------------

  // Helper method to build the image widget (network or file)
  Widget _buildShoeImage(String imagePath, String remoteImageUrl) {
    // Priority 1: Remote URL (from Firestore)
    if (remoteImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remoteImageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
        errorWidget: (context, url, error) => const Icon(Icons.error, size: 40),
      );
    }
    // Priority 2: Local File Path (from ImagePicker, not yet uploaded)
    else if (imagePath.isNotEmpty) {
      // NOTE: This assumes the imagePath is a valid File path on the device/platform
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

  void _showShoeDialog({Shoe? shoe, String? originalLocalPath}) async {
    // Controllers for the form fields
    final shoeIdController = TextEditingController(text: shoe != null ? shoe.itemId.toString() : '');
    final shipmentIdController = TextEditingController(text: shoe?.shipmentId ?? '');
    final nameController = TextEditingController(text: shoe?.shoeDetail ?? '');
    final sizeEurController = TextEditingController(text: shoe?.sizeEur ?? '');
    final sizeUkController = TextEditingController(text: shoe?.sizeUk ?? '');
    final priceController = TextEditingController(text: shoe != null ? shoe.sellingPrice.toString() : '');
    final instagramController = TextEditingController(text: shoe?.instagramLink ?? '');
    final tiktokController = TextEditingController(text: shoe?.tiktokLink ?? '');
    
    // Image state management for the dialog
    File? dialogImageFile = originalLocalPath != null && originalLocalPath.isNotEmpty ? File(originalLocalPath) : null;
    String currentRemoteImageUrl = shoe?.remoteImageUrl ?? '';

    // Track if the shoe is new to potentially disable editing the Item ID field
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
                return Image.file(dialogImageFile!, width: 60, height: 60, fit: BoxFit.cover);
              } else if (currentRemoteImageUrl.isNotEmpty) {
                // Show remote image if editing existing shoe
                return CachedNetworkImage(
                  imageUrl: currentRemoteImageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0)
                  )),
                  errorWidget: (context, url, error) => const Icon(Icons.error, size: 60),
                );
              }
              return const Icon(Icons.image_not_supported, size: 60, color: Colors.grey);
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
                      enabled: !isEditing && !isLoading, // Disabled while editing AND loading
                      decoration: InputDecoration(
                        labelText: 'Item ID (e.g., 123)',
                        // Hint that ID cannot be changed once set
                        helperText: isEditing ? 'Item ID cannot be changed.' : null, 
                      ),
                    ),
                    TextField(
                      controller: shipmentIdController,
                      keyboardType: TextInputType.text,
                      maxLength: 2,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(labelText: 'Shipment ID (e.g., S1)'),
                    ),
                    TextField(
                      controller: nameController,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(labelText: 'Shoe Name/Detail'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sizeEurController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            maxLength: 4,
                            enabled: !isLoading, // Disabled while loading
                            decoration: const InputDecoration(labelText: 'Size EUR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: sizeUkController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            maxLength: 4,
                            enabled: !isLoading, // Disabled while loading
                            decoration: const InputDecoration(labelText: 'Size UK'),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(labelText: 'Selling Price'),
                    ),
                    TextField(
                      controller: instagramController,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(labelText: 'Instagram Link'),
                    ),
                    TextField(
                      controller: tiktokController,
                      enabled: !isLoading, // Disabled while loading
                      decoration: const InputDecoration(labelText: 'TikTok Link'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick Image'),
                          // Disable image picking while saving
                          onPressed: isLoading ? null : () async { 
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
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
                  onPressed: isLoading ? null : () => Navigator.of(context).pop(), 
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  // Disable button while loading
                  onPressed: isLoading ? null : () async {
                    // 1. Data Validation
                    final itemId = _safeIntParse(shoeIdController.text);
                    final shipmentId = shipmentIdController.text.trim();
                    final name = nameController.text.trim();
                    
                    if (itemId == 0 || shipmentId.isEmpty || name.isEmpty) {
                      // Basic validation failure (you might want a better UI feedback here)
                      // For now, silently fail, relying on user to see required fields
                      return;
                    }
                    
                    // 2. Prepare new/updated Shoe object
                    final newShoe = (shoe ?? Shoe.empty()).copyWith(
                      itemId: itemId,
                      shipmentId: shipmentId,
                      shoeDetail: name,
                      sizeEur: sizeEurController.text.trim(),
                      sizeUk: sizeUkController.text.trim(),
                      sellingPrice: _safeDoubleParse(priceController.text),
                      instagramLink: instagramController.text.trim(),
                      tiktokLink: tiktokController.text.trim(),
                      localImagePath: dialogImageFile?.path ?? '',
                      remoteImageUrl: currentRemoteImageUrl, // Maintain remote URL if no new image
                      isUploaded: shoe?.isUploaded ?? false, // Maintain previous state
                      // documentId: shoe?.documentId ?? 0,
                    );

                    // Start loading state
                    dialogSetState(() {
                      isLoading = true;
                    });
                    
                    try {
                      // 3. Save the data via the service (uses itemId as document key)
                      await _firebaseService.saveShoe(newShoe, localImageFile: dialogImageFile);
                      
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shoe'),
        content: Text('Are you sure you want to delete "${shoe.shoeDetail}" (ID: ${shoe.itemId})? This action is permanent.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      // Delete the document and the image from Firebase
      await _firebaseService.deleteShoe(shoe);
      // The StreamBuilder handles the UI update automatically
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Shoe Inventory'),
        backgroundColor: Colors.blueGrey,
        actions: [
          // Dropdown for selecting sort field
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortField,
                dropdownColor: Colors.blueGrey[700],
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
                    child: Text('ID', style: TextStyle(color: _sortField == 'itemId' ? Colors.amberAccent : Colors.white)),
                  ),
                  DropdownMenuItem(
                    value: 'sellingPrice',
                    child: Text('Price', style: TextStyle(color: _sortField == 'sellingPrice' ? Colors.amberAccent : Colors.white)),
                  ),
                ],
              ),
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
          const SizedBox(width: 8.0),
        ],
      ),
      body: StreamBuilder<List<Shoe>>(
        // Use the list provided in the constructor as initial data
        initialData: widget.initialShoes, 
        stream: _firebaseService.streamShoes(),
        builder: (context, snapshot) {
          // --- Connection State Handling ---
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('Firestore Stream Error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading data: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          final shoes = snapshot.data;

          // --- Data State Handling ---
          if (shoes == null || shoes.isEmpty) {
            return const Center(child: Text('No shoes added yet. Click "+" to add the first entry!'));
          }

          // --- NEW: Client-Side Sorting Logic ---
          final sortedShoes = List<Shoe>.from(shoes);
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
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  
                  // Leading: Image or Placeholder
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: _buildShoeImage(shoe.localImagePath, shoe.remoteImageUrl),
                    ),
                  ),
                  
                  // Title: Name and IDs
                  title: Text(
                    shoe.shoeDetail,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  
                  // Subtitle: Details
                  subtitle: Text(
                    'ID: ${shoe.itemId} | Shipment: ${shoe.shipmentId}\nEUR: ${shoe.sizeEur}, UK: ${shoe.sizeUk} | Price: \$${shoe.sellingPrice.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  
                  // Trailing: Edit and Delete buttons
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        tooltip: 'Edit Shoe',
                        onPressed: () {
                          _showShoeDialog(shoe: shoe, originalLocalPath: shoe.localImagePath);
                        },
                      ),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Shoe',
                        onPressed: () => _deleteShoe(shoe),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShoeDialog(),
        tooltip: 'Add New Shoe',
        child: const Icon(Icons.add),
      ),
    );
  }
}
