// ----------------------------------------------------------------------
// 3. ShoeFormDialog Component (The complex content inside the AlertDialog)
// ----------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';
import 'package:shoe_view/error_dialog.dart';

// Assuming these imports exist and are available
import 'shoe_model.dart';
import 'dart:convert';
import 'firebase_service.dart';

class ShoeFormDialogContent extends StatefulWidget {
  final Shoe? shoe;
  final FirebaseService firebaseService;

  const ShoeFormDialogContent({this.shoe, required this.firebaseService});

  @override
  State<ShoeFormDialogContent> createState() => _ShoeFormDialogContentState();
}

class _ShoeFormDialogContentState extends State<ShoeFormDialogContent> {
  // Controllers
  late final TextEditingController _shoeIdController;
  late final TextEditingController _shipmentIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _sizeEurController;
  late final TextEditingController _sizeUkController;
  late final TextEditingController _priceController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;

  // Local State for Image and Loading
  File? _dialogImageFile;
  String _currentRemoteImageUrl = '';
  bool _isLoading = false;
  bool _isEditing;
  String _status = 'Available';

  _ShoeFormDialogContentState()
    : _isEditing = false; // Initializer needed for late

  @override
  void initState() {
    super.initState();
    _isEditing = widget.shoe != null;

    _shoeIdController = TextEditingController(
      text: widget.shoe != null ? widget.shoe!.itemId.toString() : '',
    );
    _shipmentIdController = TextEditingController(
      text: widget.shoe?.shipmentId ?? '',
    );
    _nameController = TextEditingController(
      text: widget.shoe?.shoeDetail ?? '',
    );
    _sizeEurController = TextEditingController(
      text: widget.shoe?.sizeEur ?? '',
    );
    _sizeUkController = TextEditingController(text: widget.shoe?.sizeUk ?? '');
    _priceController = TextEditingController(
      text: widget.shoe != null ? widget.shoe!.sellingPrice.toString() : '',
    );
    _instagramController = TextEditingController(
      text: widget.shoe?.instagramLink ?? '',
    );
    _tiktokController = TextEditingController(
      text: widget.shoe?.tiktokLink ?? '',
    );

    _dialogImageFile = null;
    _currentRemoteImageUrl = widget.shoe?.remoteImageUrl ?? '';
  }

  @override
  void dispose() {
    _shoeIdController.dispose();
    _shipmentIdController.dispose();
    _nameController.dispose();
    _sizeEurController.dispose();
    _sizeUkController.dispose();
    _priceController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
    );
    if (picked != null) {
      setState(() {
        _dialogImageFile = File(picked.path);
        // Clear remote URL if a new image is picked
        _currentRemoteImageUrl = '';
      });
    }
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

  Future<void> _saveShoe() async {
    // 1. Data Validation
    final itemId = _safeIntParse(_shoeIdController.text);
    final shipmentId = _shipmentIdController.text.trim();
    final name = _nameController.text.trim();

    if (itemId == 0 || shipmentId.isEmpty || name.isEmpty) {
      // Basic validation failure (a proper app would show a snackbar)
      return;
    }

    // 2. Prepare new/updated Shoe object
    final newShoe = (widget.shoe ?? Shoe.empty()).copyWith(
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: name,
      sizeEur: _sizeEurController.text.trim(),
      sizeUk: _sizeUkController.text.trim(),
      sellingPrice: _safeDoubleParse(_priceController.text),
      instagramLink: _instagramController.text.trim(),
      tiktokLink: _tiktokController.text.trim(),
      localImagePath: _dialogImageFile?.path ?? '',
      status: _status,
      remoteImageUrl:
          _currentRemoteImageUrl, // Maintain remote URL if no new image
      isUploaded: widget.shoe?.isUploaded ?? false,
    );

    // Start loading state
    setState(() {
      _isLoading = true;
    });

    try {
      print(_currentRemoteImageUrl);

      File? imageFile = _dialogImageFile;
      String? base64Image;

      if (imageFile != null && await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        if (imageBytes.isNotEmpty) {
          base64Image = base64Encode(imageBytes);
        }
      }

      final response = await widget.firebaseService.updateShoe(
        newShoe,
        base64Image, // ✅ will be null if no image
      );
      if (response['success'] == false) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Something went wrong.',
            message: response['message'],
            onDismissed: _onDismissed,
          ),
        );
        return;
      }

      _onDismissed();
    } catch (e) {
      debugPrint('Error saving shoe: $e');
      // If saving fails, reset loading state and let user try again/fix input
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onDismissed() {
    if (mounted) {
    Navigator.of(context).pop();
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Helper method to build the image widget (network or file)
  Widget _buildShoeImage(String remoteImageUrl) {
    // Priority 1: Remote URL (from Firestore)
    if (remoteImageUrl.isNotEmpty) {
      return ShoeNetworkImage(
        imageUrl: remoteImageUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
      );
    }
    // Fallback: No image available
    return const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    // Build the image preview widget
    Widget imagePreview(double width, double height) {
      if (_dialogImageFile != null) {
        // Show newly picked local image
        return Image.file(
          _dialogImageFile!,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      } else if (_currentRemoteImageUrl.isNotEmpty) {
        // Show remote image if editing existing shoe
        return _buildShoeImage(_currentRemoteImageUrl); // Reusing the helper
      }
      return const Icon(
        Icons.image_not_supported,
        size: 60,
        color: Colors.grey,
      );
    }

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Shoe' : 'Add New Shoe'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _shoeIdController,
              keyboardType: TextInputType.number,
              maxLength: 3,
              // Disable editing Item ID when updating existing shoe
              enabled: !_isEditing && !_isLoading,
              decoration: InputDecoration(
                labelText: 'Item ID (e.g., 123)',
                helperText: _isEditing ? 'Item ID cannot be changed.' : null,
              ),
            ),
            TextField(
              controller: _shipmentIdController,
              keyboardType: TextInputType.number,
              maxLength: 3,
              enabled: !_isEditing && !_isLoading,
              decoration: InputDecoration(
                labelText: 'Shipment ID (e.g., 123)',
                helperText: _isEditing
                    ? 'Shipment ID cannot be changed.'
                    : null,
              ),
            ),
            TextField(
              controller: _nameController,
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'Shoe Name/Detail'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sizeEurController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    maxLength: 4,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(labelText: 'Size EUR'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _sizeUkController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    maxLength: 4,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(labelText: 'Size UK'),
                  ),
                ),
              ],
            ),
            RadioGroup<String>(
              groupValue: _status,
              onChanged: (value) => setState(() => _status = value!),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(value: 'Available'),
                      Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(value: 'Sold'),
                      Text(
                        'Sold',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(value: 'Repaired'),
                      Text(
                        'Repaired',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Selling Price (Rs.)',
              ),
            ),
            TextField(
              controller: _instagramController,
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'Instagram Link'),
            ),
            TextField(
              controller: _tiktokController,
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'TikTok Link'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick Image'),
                  onPressed: _isLoading ? null : _pickImage,
                ),
                const SizedBox(width: 26),
                // Image Preview
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),

                    child: imagePreview(90, 90),
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
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveShoe,
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_isEditing ? 'Update' : 'Add Shoe'),
        ),
      ],
    );
  }
}
