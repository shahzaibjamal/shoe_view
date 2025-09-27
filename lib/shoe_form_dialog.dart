import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import 'shoe_model.dart';
import 'firebase_service.dart';

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

/// Displays the modal form for adding or editing a shoe entry.
Future<void> showShoeFormDialog({
  required BuildContext context,
  required FirebaseService firebaseService,
  Shoe? shoe,
  String? originalLocalPath,
}) async {
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

  // Track if the shoe is new
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
                    enabled: !isEditing && !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Item ID (e.g., 123)',
                      helperText: isEditing ? 'Item ID cannot be changed.' : null,
                    ),
                  ),
                  TextField(
                    controller: shipmentIdController,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    // Disable editing Shipment ID when updating
                    enabled: !isEditing && !isLoading,
                    decoration: InputDecoration(
                        labelText: 'Shipment ID (e.g., 123)',
                        helperText: isEditing ? 'Shipment ID cannot be changed.' : null,
                    ),
                  ),
                  TextField(
                    controller: nameController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(labelText: 'Shoe Name/Detail'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sizeEurController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          maxLength: 4,
                          enabled: !isLoading,
                          decoration: const InputDecoration(labelText: 'Size EUR'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: sizeUkController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          maxLength: 4,
                          enabled: !isLoading,
                          decoration: const InputDecoration(labelText: 'Size UK'),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !isLoading,
                    decoration: const InputDecoration(labelText: 'Selling Price (Rs.)'),
                  ),
                  TextField(
                    controller: instagramController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(labelText: 'Instagram Link'),
                  ),
                  TextField(
                    controller: tiktokController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(labelText: 'TikTok Link'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Pick Image'),
                        onPressed: isLoading ? null : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                          if (picked != null) {
                            dialogSetState(() {
                              dialogImageFile = File(picked.path);
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
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  // 1. Data Validation
                  final itemId = _safeIntParse(shoeIdController.text);
                  final shipmentId = shipmentIdController.text.trim();
                  final name = nameController.text.trim();
                  
                  if (itemId == 0 || shipmentId.isEmpty || name.isEmpty) {
                    // In a real app, you'd show an error message
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
                    remoteImageUrl: currentRemoteImageUrl,
                    isUploaded: shoe?.isUploaded ?? false,
                  );

                  // Start loading state
                  dialogSetState(() {
                    isLoading = true;
                  });
                  
                  try {
                    // 3. Save the data via the service
                    await firebaseService.saveShoe(newShoe, localImageFile: dialogImageFile);
                    
                    // 4. Close dialog on success
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    debugPrint('Error saving shoe: $e');
                    dialogSetState(() {
                      isLoading = false;
                    });
                    // NOTE: Show error feedback here in a production app
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
