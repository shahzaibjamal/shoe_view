import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Added for CupertinoPicker
import 'package:flutter/services.dart'; // Added for input formatters
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; // Needed for firstWhereOrNull in validation

import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/firebase_service.dart';
import 'package:shoe_view/shoe_model.dart';

// NOTE: Assumed imports (Shoe, FirebaseService, ErrorDialog) are expected to be imported from
// the user's main project files.

// --- SIZE CONVERSION DATA ---
// A reliable mapping based on standard shoe conversion charts for sports shoes.
const Map<String, String> _eurToUk = {
  // Start (38 - 39.5)
  '38': '5',
  '38.5': '5.5',
  '39': '6',
  '39.5': '6.5', // Filled step
  // Mid-range (40 - 43.5)
  '40': '6.5', // Original value retained
  '40.5': '7',
  '41': '7.5',
  '41.5': '7.5', // Filled step (often 41.5 is the same as 41 or 42 is an 8)
  '42': '8',
  '42.5': '8.5',
  '43': '9',
  '43.5': '9.5', // Filled step
  // Upper Mid-range (44 - 47)
  '44': '9.5', // Original value retained
  '44.5': '10',
  '45': '10.5',
  '45.5': '11', // Filled step
  '46': '11', // Original value retained
  '46.5': '11.5', // Filled step
  '47': '12', // Original value retained
  // Extended range (47.5 - 49.5)
  '47.5': '12.5',
  '48': '13',
  '48.5': '13.5',
  '49': '14',
  '49.5': '14.5',
};

// Generate reverse map (UK to EUR)
final Map<String, String> _ukToEur = Map.fromEntries(
  _eurToUk.entries.map((e) => MapEntry(e.value, e.key)),
);

// Lists for the CupertinoPicker
const List<String> _eurSizesList = [
  '38',
  '38.5',
  '39',
  '39.5',
  '40',
  '40.5',
  '41',
  '41.5',
  '42',
  '42.5',
  '43',
  '43.5',
  '44',
  '44.5',
  '45',
  '45.5',
  '46',
  '46.5',
  '47',
  '47.5',
  '48',
  '48.5',
  '49',
  '49.5',
];
final List<String> _ukSizesList = _eurToUk.values.toSet().toList()
  ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));

// ----------------------------------------------------------------------
// 3. ShoeFormDialog Component (The complex content inside the AlertDialog)
// ----------------------------------------------------------------------
class ShoeFormDialogContent extends StatefulWidget {
  final Shoe? shoe;
  final FirebaseService firebaseService;
  final List<Shoe> existingShoes;

  const ShoeFormDialogContent({
    super.key,
    this.shoe,
    required this.firebaseService,
    required this.existingShoes,
  });

  @override
  State<ShoeFormDialogContent> createState() => _ShoeFormDialogContentState();
}

class _ShoeFormDialogContentState extends State<ShoeFormDialogContent> {
  // Key for Form validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for TextField inputs
  late final TextEditingController _shoeIdController;
  late final TextEditingController _shipmentIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;

  // Local State
  File? _dialogImageFile;
  String _currentRemoteImageUrl = '';
  bool _isLoading = false;
  bool _isEditing;
  String _status = 'Available';

  late String _selectedEurSize;
  late String _selectedUkSize;

  // State for real-time ID validation feedback
  String? _itemIdError;
  String? _shipmentIdError;

  _ShoeFormDialogContentState() : _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.shoe != null;

    // Initialize size state from existing shoe or defaults
    _selectedEurSize = widget.shoe?.sizeEur ?? _eurSizesList.first;
    _selectedUkSize = widget.shoe?.sizeUk ?? _ukSizesList.first;
    _status = widget.shoe?.status ?? 'Available';

    _shoeIdController = TextEditingController(
      text: widget.shoe != null ? widget.shoe!.itemId.toString() : '',
    );
    _shipmentIdController = TextEditingController(
      text: widget.shoe?.shipmentId ?? '',
    );
    _nameController = TextEditingController(
      text: widget.shoe?.shoeDetail ?? '',
    );
    _priceController = TextEditingController(
      // Ensure price is displayed as an integer if it's an existing double (e.g., 5800.0 -> '5800')
      text: widget.shoe != null
          ? widget.shoe!.sellingPrice.round().toString()
          : '',
    );
    _instagramController = TextEditingController(
      text: widget.shoe?.instagramLink ?? '',
    );
    _tiktokController = TextEditingController(
      text: widget.shoe?.tiktokLink ?? '',
    );

    _dialogImageFile = null;
    _currentRemoteImageUrl = widget.shoe?.remoteImageUrl ?? '';

    // Add listeners for real-time duplicate check (only on Item ID and Shipment ID)
    _shoeIdController.addListener(_validateIds);
    _shipmentIdController.addListener(_validateIds);
  }

  @override
  void dispose() {
    _shoeIdController.removeListener(_validateIds);
    _shipmentIdController.removeListener(_validateIds);
    _shoeIdController.dispose();
    _shipmentIdController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  // --- Real-time Validation ---
  void _validateIds() {
    // This function remains the same, checking for existing ID/Shipment combinations
    final currentItemId = _safeIntParse(_shoeIdController.text);
    final currentShipmentId = _shipmentIdController.text.trim();

    // Check if the current combination conflicts with any other shoe
    final conflictingShoe = widget.existingShoes.firstWhereOrNull(
      (existingShoe) =>
          existingShoe.documentId !=
              (widget.shoe?.documentId) && // Ignore self when editing
          existingShoe.itemId == currentItemId &&
          existingShoe.shipmentId == currentShipmentId,
    );

    setState(() {
      if (conflictingShoe != null) {
        _itemIdError = 'Duplicate combination.';
        _shipmentIdError = 'Duplicate combination.';
      } else {
        _itemIdError = null;
        _shipmentIdError = null;
      }
    });
  }

  // --- Image Handling ---

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
    );
    if (picked != null) {
      setState(() {
        _dialogImageFile = File(picked.path);
        // Clear remote URL if a new image is picked
        _currentRemoteImageUrl = '';
      });
    }
  }

  // --- Size Selection and Conversion ---

  void _handleEurSizeSelected(String newEurSize) {
    if (_selectedEurSize == newEurSize) return;

    final String? newUkSize = _eurToUk[newEurSize];

    setState(() {
      _selectedEurSize = newEurSize;
      if (newUkSize != null) {
        _selectedUkSize = newUkSize;
      }
    });
  }

  void _handleUkSizeSelected(String newUkSize) {
    if (_selectedUkSize == newUkSize) return;

    final String? newEurSize = _ukToEur[newUkSize];

    setState(() {
      _selectedUkSize = newUkSize;
      if (newEurSize != null) {
        _selectedEurSize = newEurSize;
      }
    });
  }

  // Helper function to show a modal with CupertinoPicker
  Future<void> _showSizePicker(
    String selectedSize,
    List<String> sizeList,
    Function(String) onSizeSelected,
    String title,
  ) async {
    String tempSelectedSize = selectedSize;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          // Decreased height for smaller picker box, as requested
          height: 200,
          color: Colors.white,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // Expanded ensures the picker takes up available vertical space
              Expanded(
                child: CupertinoPicker.builder(
                  scrollController: FixedExtentScrollController(
                    initialItem: !sizeList.contains(selectedSize)
                        ? 0
                        : sizeList.indexOf(selectedSize),
                  ),
                  itemExtent: 32.0,
                  onSelectedItemChanged: (int index) {
                    tempSelectedSize = sizeList[index];
                  },
                  childCount: sizeList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Center(child: Text(sizeList[index]));
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  onSizeSelected(tempSelectedSize);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Data Conversion & Validation Helpers ---

  // Custom parsing functions
  int _safeIntParse(String? text) {
    if (text == null || text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }

  // Custom validation for Instagram/TikTok links
  String? _validateLink(String? value, String requiredDomain) {
    if (value == null || value.trim().isEmpty) {
      return null; // Links are optional
    }
    if (!value.toLowerCase().contains(requiredDomain)) {
      return 'If provided, must contain "$requiredDomain".';
    }
    return null;
  }

  Future<void> _saveShoe() async {
    // 1. Trigger Form Validation (Name, Price, Links)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Critical ID Validation (Item ID and Shipment ID)
    // Check for immediate real-time conflict (this should be prevented by UI error, but check again)
    _validateIds();
    if (_itemIdError != null || _shipmentIdError != null) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: 'Duplicate ID Found',
          message: 'The Item ID and Shipment ID combination is already in use.',
          onDismissed: () => {},
        ),
      );
      return;
    }

    // Data Collection after successful validation
    final itemId = _safeIntParse(_shoeIdController.text);
    final shipmentId = _shipmentIdController.text.trim();
    final name = _nameController.text.trim();
    final priceValue = _safeIntParse(
      _priceController.text,
    ); // Price is guaranteed to be integer string

    if (itemId == 0 || shipmentId.isEmpty || name.isEmpty || priceValue == 0) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: 'Missing Required Fields',
          message:
              'Item ID, Shipment ID, Shoe Name, and Selling Price are required.',
          onDismissed: () => {},
        ),
      );
      return;
    }

    // 3. Prepare new/updated Shoe object
    final newShoe = (widget.shoe ?? Shoe.empty()).copyWith(
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: name,
      // Use the sizes selected via the pickers
      sizeEur: _selectedEurSize,
      sizeUk: _selectedUkSize,
      // Convert integer price back to double for the model
      sellingPrice: priceValue.toDouble(),
      // Store null if the field was empty to keep the database clean
      instagramLink: _instagramController.text.trim().isEmpty
          ? null
          : _instagramController.text.trim(),
      tiktokLink: _tiktokController.text.trim().isEmpty
          ? null
          : _tiktokController.text.trim(),
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
        base64Image, // will be null if no image
      );

      if (response['success'] == false) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'Transaction Failed',
              message:
                  response['message'] ??
                  'Could not save shoe due to a server error.',
              onDismissed: _onDismissed,
            ),
          );
        }
        return;
      }

      // Success: Close dialog
      _onDismissed();
    } catch (e) {
      debugPrint('Error saving shoe: $e');
      // If saving fails, reset loading state and show generic error
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Connection Error',
            message:
                'An unexpected error occurred while connecting to the server.',
            onDismissed: () => {},
          ),
        );
      }
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
  Widget _buildShoeImage(
    String remoteImageUrl, {
    double width = 70,
    double height = 70,
  }) {
    // Priority 1: Remote URL (from Firestore)
    if (remoteImageUrl.isNotEmpty) {
      // Assuming Image.network is used as a stand-in for ShoeNetworkImage

      return Image.network(
        remoteImageUrl,
        width: width,
        cacheWidth: 512, // width constraint
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.broken_image,
            size: 40,
            color: Colors.redAccent,
          );
        },
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
        return _buildShoeImage(
          _currentRemoteImageUrl,
          width: width,
          height: height,
        );
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
        // Wrap content in a Form widget to enable field validation
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Item ID Field (using TextFormField for consistency, but relying on controller listener for ID validation)
              TextFormField(
                controller: _shoeIdController,
                keyboardType: TextInputType.number,
                maxLength: 3,
                // Disable editing Item ID when updating existing shoe
                enabled: !_isEditing && !_isLoading,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Item ID is required.'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Item ID (e.g., 123)',
                  helperText: _isEditing
                      ? 'Item ID cannot be changed.'
                      : 'Required field.',
                  errorText: _itemIdError, // Real-time duplicate error
                ),
              ),
              // Shipment ID Field
              TextFormField(
                controller: _shipmentIdController,
                // Shipment ID is often alphanumeric, but keeping number type based on original context
                keyboardType: TextInputType.number,
                maxLength: 3,
                enabled: !_isEditing && !_isLoading,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Shipment ID is required.'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Shipment ID (e.g., 123)',
                  helperText: _isEditing
                      ? 'Shipment ID cannot be changed.'
                      : 'Required field.',
                  errorText: _shipmentIdError, // Real-time duplicate error
                ),
              ),
              // --- Name Field (30 Char Limit) ---
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                maxLength: 30, // MAX 30 CHARS
                decoration: const InputDecoration(
                  labelText: 'Shoe Name/Detail',
                  helperText: 'Required field',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Shoe Name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- SIZE PICKER CARDS ---
              Row(
                children: [
                  Expanded(
                    child: SizeDisplayCard(
                      title: 'Size EUR',
                      value: _selectedEurSize,
                      onTap: _isLoading
                          ? null
                          : () => _showSizePicker(
                              _selectedEurSize,
                              _eurSizesList,
                              _handleEurSizeSelected,
                              'Select EUR Size',
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizeDisplayCard(
                      title: 'Size UK',
                      value: _selectedUkSize,
                      onTap: _isLoading
                          ? null
                          : () => _showSizePicker(
                              _selectedUkSize,
                              _ukSizesList,
                              _handleUkSizeSelected,
                              'Select UK Size',
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // --- STATUS RADIO GROUP (Padding/Layout Fix) ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    // Using spaceBetween fixes the left-side padding bias
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusOption('Available'),
                      _buildStatusOption('Sold'),
                      _buildStatusOption('Repaired'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // --- Price Field (6 Char Limit, Integer Only) ---
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly, // Remove decimals, only digits allowed
                  LengthLimitingTextInputFormatter(6), // MAX 6 CHARS
                ],
                decoration: const InputDecoration(
                  labelText: 'Selling Price (Rs.)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required.';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Price must be a whole number (no decimals).';
                  }
                  return null;
                },
              ),
              // --- Instagram Link (Conditional Domain Check) ---
              TextFormField(
                controller: _instagramController,
                enabled: !_isLoading,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Instagram Link'),
                validator: (value) => _validateLink(value, 'instagram.com'),
              ),
              // --- TikTok Link (Conditional Domain Check) ---
              TextFormField(
                controller: _tiktokController,
                enabled: !_isLoading,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'TikTok Link'),
                validator: (value) => _validateLink(value, 'tiktok.com'),
              ),
              const SizedBox(height: 16),
              // --- IMAGE PICKER ---
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

  // Helper for building radio buttons
  Widget _buildStatusOption(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: _status,
          onChanged: _isLoading ? null : (v) => setState(() => _status = v!),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.left,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// 4. SizeDisplayCard (New Helper Widget for cleaner UI)
// ----------------------------------------------------------------------
class SizeDisplayCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;

  const SizeDisplayCard({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8.0),
          color: onTap == null ? Colors.grey.shade200 : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 0),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
