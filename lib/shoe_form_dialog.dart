import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Added for CupertinoPicker
import 'package:flutter/services.dart'; // Added for input formatters
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; // Needed for firstWhereOrNull
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/analytics_service.dart';
import 'package:shoe_view/app_status_notifier.dart';

import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/firebase_service.dart';
import 'package:shoe_view/shoe_model.dart';

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

  // NEW: Condition, Quantity, and Multi-Size State
  late String _selectedCondition;
  late final TextEditingController _quantityController;

  // NEW: Combined Size Management
  // This Set stores all sizes selected. If length is 1, it's single-size mode.
  Set<String> _currentEurSizes = {};

  // These variables are only used for display purposes when in Single Size Mode
  late String _displayEurSize;
  late String _displayUkSize;

  bool _isBound = true; // true = changing one auto-updates the other (default)

  // Local State
  File? _dialogImageFile;
  String _currentRemoteImageUrl = '';
  bool _isLoading = false;
  bool _isEditing;
  String _status = 'Available';
  String currency = '\$';

  // State for real-time ID validation feedback
  String? _itemIdError;
  String? _shipmentIdError;

  _ShoeFormDialogContentState() : _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.shoe != null;
    _isBound = true;

    // --- INITIALIZATION ---

    // Condition, Quantity, and Status
    _selectedCondition = widget.shoe?.condition.toStringAsFixed(1) ?? '10.0';

    _status = widget.shoe?.status ?? 'Available';
    _isBound = widget.shoe?.isSizeLinked ?? true;
    _quantityController = TextEditingController(
      text: widget.shoe?.quantity.toString() ?? '1',
    );

    // Text Controllers
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

    // Image
    _dialogImageFile = null;
    _currentRemoteImageUrl = widget.shoe?.remoteImageUrl ?? '';

    // We no longer need to check list length to set _isMultiSize.
    // The logic below handles the size data regardless of the setting.
    final List<String> eurList =
        widget.shoe?.sizeEur ?? [ShoeQueryUtils.eurSizesList.first];
    final List<String> ukList =
        widget.shoe?.sizeUk ?? [ShoeQueryUtils.ukSizesList.first];

    // Set the main source of truth for EUR sizes
    _currentEurSizes = eurList.toSet();

    // Set display sizes (used ONLY when multi-size is OFF)
    _displayEurSize =
        eurList.firstWhereOrNull((_) => true) ??
        ShoeQueryUtils.eurSizesList.first;
    _displayUkSize =
        ukList.firstWhereOrNull((_) => true) ??
        ShoeQueryUtils.ukSizesList.first;

    // Listeners & Currency
    _shoeIdController.addListener(_validateIds);
    _shipmentIdController.addListener(_validateIds);
    final code = context.read<AppStatusNotifier>().currencyCode;
    currency = ShoeQueryUtils.getSymbolFromCode(code);
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
    _quantityController.dispose();
    super.dispose();
  }

  // --- Real-time Validation ---
  void _validateIds() {
    final currentItemId = _safeIntParse(_shoeIdController.text);
    final currentShipmentId = _shipmentIdController.text.trim();
    final conflictingShoe = widget.existingShoes.firstWhereOrNull(
      (existingShoe) =>
          existingShoe.documentId != (widget.shoe?.documentId) &&
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
        _currentRemoteImageUrl = '';
      });
    }
  }

  // --- Size/Condition Handlers ---

  // Handle EUR size selection for SINGLE-SIZE MODE
  void _handleDisplayEurSizeSelected(String newEurSize) {
    if (_displayEurSize == newEurSize) return;

    final String? newUkSize = ShoeQueryUtils.eurToUk[newEurSize];

    setState(() {
      _displayEurSize = newEurSize;
      _currentEurSizes = {newEurSize}; // Keep the set in sync (as single item)

      // Automatic UK conversion
      if (_isBound && newUkSize != null) {
        _displayUkSize = newUkSize;
      }
    });
  }

  // Handle UK size selection for SINGLE-SIZE MODE
  void _handleDisplayUkSizeSelected(String newUkSize) {
    if (_displayUkSize == newUkSize) return;

    final String? newEurSize = ShoeQueryUtils.ukToEur[newUkSize];

    setState(() {
      _displayUkSize = newUkSize;

      // Automatic EUR conversion
      if (_isBound && newEurSize != null) {
        _displayEurSize = newEurSize;
        _currentEurSizes = {newEurSize}; // Important: EUR must be updated here
      }
    });
  }

  // Handle Condition selection
  void _handleConditionSelected(String newCondition) {
    if (_selectedCondition == newCondition) return;

    setState(() {
      _selectedCondition = newCondition;
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

  // --- Helper method for Multi-Size Picker UI ---
  Widget _buildMultiSizePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected EUR Sizes:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: ShoeQueryUtils.eurSizesList.map((size) {
            final isSelected = _currentEurSizes.contains(size);
            return FilterChip(
              label: Text(size),
              selected: isSelected,
              onSelected: _isLoading
                  ? null
                  : (bool selected) {
                      setState(() {
                        if (selected) {
                          _currentEurSizes.add(size);
                        } else {
                          // Prevent deselecting if it's the only one left
                          if (_currentEurSizes.length > 1) {
                            _currentEurSizes.remove(size);
                          }
                        }
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (_currentEurSizes.isEmpty)
          const Text(
            'Please select at least one size.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
      ],
    );
  }

  // --- Data Conversion & Validation Helpers ---
  int _safeIntParse(String? text) {
    if (text == null || text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }

  String? _validateLink(String? value, String requiredDomain) {
    if (value == null || value.trim().isEmpty) {
      return null; // Links are optional
    }
    if (!value.toLowerCase().contains(requiredDomain)) {
      return 'If provided, must contain "$requiredDomain".';
    }
    return null;
  }

  // --- SAVE SHOE LOGIC (CRITICALLY UPDATED) ---
  Future<void> _saveShoe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_isEditing) _validateIds();
    if (_itemIdError != null || _shipmentIdError != null) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: 'Duplicate ID Found',
          message: 'The Item ID and Shipment ID combination is already in use.',
          onDismissed: () => const {},
        ),
      );
      return;
    }

    final itemId = _safeIntParse(_shoeIdController.text);
    final shipmentId = _shipmentIdController.text.trim();
    final name = _nameController.text.trim();
    final priceValue = _safeIntParse(_priceController.text);
    final conditionValue = double.tryParse(_selectedCondition) ?? 0.0;
    final quantity = _safeIntParse(_quantityController.text);

    if (_currentEurSizes.isEmpty ||
        quantity < 1 ||
        itemId == 0 ||
        shipmentId.isEmpty ||
        name.isEmpty ||
        priceValue == 0) {
      // Show combined missing fields error
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: 'Missing Required Fields',
          message:
              'All required fields, including at least one size and a quantity of 1 or more, must be valid.',
          onDismissed: () => const {},
        ),
      );
      return;
    }

    // 1. Determine final size lists from the set
    final List<String> finalEurList = _currentEurSizes.toList()..sort();

    // if the multi-size mode is globally enabled.
    final bool isMultiSizeModeEnabled = context
        .read<AppStatusNotifier>()
        .isMultiSizeModeEnabled;
    final bool shouldAutoGenerateUk = _isBound || isMultiSizeModeEnabled;

    // 2. Determine UK list based on the combined condition.
    final List<String> finalUkList = shouldAutoGenerateUk
        ? finalEurList // If linked OR multi-size enabled, calculate UK list from the EUR list.
              .map((eur) => ShoeQueryUtils.eurToUk[eur] ?? 'N/A')
              .toList()
        : ([_displayUkSize]);
    // 3. Prepare new/updated Shoe object
    final newShoe = (widget.shoe ?? Shoe.empty()).copyWith(
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: name,

      // Use the combined LIST fields (Requires Shoe Model Update)
      sizeEur: finalEurList,
      sizeUk: finalUkList,

      condition: conditionValue,
      sellingPrice: priceValue.toDouble(),
      quantity: quantity,

      instagramLink: _instagramController.text.trim().isEmpty
          ? null
          : _instagramController.text.trim(),
      tiktokLink: _tiktokController.text.trim().isEmpty
          ? null
          : _tiktokController.text.trim(),
      localImagePath: _dialogImageFile?.path ?? '',
      status: _status,
      remoteImageUrl: _currentRemoteImageUrl,
      isUploaded: widget.shoe?.isUploaded ?? false,
      isSizeLinked: _isBound,
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

      bool isTest = context.read<AppStatusNotifier>().isTest;
      final response = await widget.firebaseService.updateShoe(
        newShoe,
        base64Image,
        isTest: isTest, // will be null if no image
      );
      // ShoeQueryUtils.logDynamic(response);

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
      if (!_isEditing) {
        await AnalyticsService.logCustomEvent(
          name: 'add_shoe',
          parameters: {
            'item_name': newShoe.shoeDetail,
            'item_size': ShoeQueryUtils.formatSizes(newShoe.sizeEur),
            'item_size_uk': ShoeQueryUtils.formatSizes(newShoe.sizeUk),
            'item_condition': newShoe.condition,
            'item_price': newShoe.sellingPrice,
          },
        );
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
            onDismissed: () => const {},
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

    final bool isMultiSizeModeEnabled = context
        .watch<AppStatusNotifier>()
        .isMultiSizeModeEnabled;
    bool isSingleSize = !isMultiSizeModeEnabled;

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
              // --- Item ID Field ---
              TextFormField(
                controller: _shoeIdController,
                keyboardType: TextInputType.number,
                maxLength: 3,
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
              // --- Shipment ID Field ---
              TextFormField(
                controller: _shipmentIdController,
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
              // --- CONDITIONAL SIZE INPUTS ---
              if (isSingleSize)
                // A. SINGLE-SIZE PICKERS (EUR/UK linked automatically via handlers)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isBound
                              ? 'Sizes are linked (Auto-convert enabled)'
                              : 'Sizes are independent (Manual entry)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                          ),
                        ),
                        Switch(
                          value: _isBound,
                          onChanged: _isLoading
                              ? null
                              : (bool value) {
                                  setState(() {
                                    _isBound = value;
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizeDisplayCard(
                            title: 'Size EUR',
                            value: _displayEurSize,
                            // ⭐️ EUR Picker is always enabled in single-size mode
                            onTap: _isLoading
                                ? null
                                : () => _showSizePicker(
                                    _displayEurSize,
                                    ShoeQueryUtils.eurSizesList,
                                    _handleDisplayEurSizeSelected,
                                    'Select EUR Size',
                                  ),
                            isBound:
                                _isBound, // Pass bound status for visual feedback
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizeDisplayCard(
                            title: 'Size UK',
                            value: _displayUkSize,
                            // ⭐️ UK Picker is always enabled in single-size mode
                            onTap: _isLoading
                                ? null
                                : () => _showSizePicker(
                                    _displayUkSize,
                                    ShoeQueryUtils.ukSizesList,
                                    _handleDisplayUkSizeSelected,
                                    'Select UK Size',
                                  ),
                            isBound:
                                _isBound, // Pass bound status for visual feedback
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                // B. MULTI-SIZE CHIP PICKER
                _buildMultiSizePicker(context),

              const SizedBox(height: 16),

              // --- QUANTITY FIELD (NEW) ---
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantity in Stock',
                  helperText: 'Used for inventory tracking. Must be 1 or more.',
                ),
                validator: (value) {
                  if (value == null || _safeIntParse(value) < 1) {
                    return 'Quantity must be 1 or more.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              if (isSingleSize)
                SizeDisplayCard(
                  title: 'Condition (1.0 - 10.0)',
                  value: _selectedCondition,
                  onTap: _isLoading
                      ? null
                      : () => _showSizePicker(
                          _selectedCondition,
                          ShoeQueryUtils
                              .conditionList, // Use the corrected list
                          _handleConditionSelected,
                          'Select Condition',
                        ),
                ),
              const SizedBox(height: 16),

              // --- STATUS RADIO GROUP (Unchanged) ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Row(
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

              // --- Price Field (Unchanged) ---
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: 'Selling Price ($currency)',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Price is required.'
                    : null,
              ),

              // --- Instagram/TikTok Fields (Unchanged) ---
              TextFormField(
                controller: _instagramController,
                enabled: !_isLoading,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Instagram Link'),
                validator: (value) => _validateLink(value, 'instagram.com'),
              ),
              TextFormField(
                controller: _tiktokController,
                enabled: !_isLoading,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'TikTok Link'),
                validator: (value) => _validateLink(value, 'tiktok.com'),
              ),
              const SizedBox(height: 16),

              // --- IMAGE PICKER (Unchanged) ---
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Image'),
                    onPressed: _isLoading ? null : _pickImage,
                  ),
                  const SizedBox(width: 26),
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
// 4. SizeDisplayCard (Helper Widget for cleaner UI)
// ----------------------------------------------------------------------
class SizeDisplayCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool isBound;

  const SizeDisplayCard({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.isBound = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = onTap == null
        ? Colors.grey.shade300
        : isBound
        ? Theme.of(context).primaryColor
        : Colors.grey.shade400;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: isBound ? 2.0 : 1.0),
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
