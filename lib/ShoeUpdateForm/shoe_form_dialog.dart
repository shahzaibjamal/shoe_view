import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Added for CupertinoPicker
import 'package:flutter/services.dart'; // Added for input formatters
import 'dart:io';
import 'dart:convert';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart'; // Needed for firstWhereOrNull
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/ShoeUpdateForm/shoe_condition_picker.dart';
import 'package:shoe_view/ShoeUpdateForm/shoe_image_picker.dart';
import 'package:shoe_view/ShoeUpdateForm/shoe_size_picker.dart';
import 'package:shoe_view/ShoeUpdateForm/shoe_status_selector.dart';
import 'package:shoe_view/Services/analytics_service.dart';
import 'package:shoe_view/app_status_notifier.dart';

import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/Services/firebase_service.dart';
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
  String _repairNotes = '';
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
    _repairNotes = widget.shoe?.notes ?? 'None';

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
    final currentItemId = ShoeQueryUtils.safeIntParse(_shoeIdController.text);
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

    final itemId = ShoeQueryUtils.safeIntParse(_shoeIdController.text);
    final shipmentId = _shipmentIdController.text.trim();
    final name = _nameController.text.trim();
    final priceValue = ShoeQueryUtils.safeIntParse(_priceController.text);
    final conditionValue = double.tryParse(_selectedCondition) ?? 0.0;
    final quantity = ShoeQueryUtils.safeIntParse(_quantityController.text);

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
      notes: _repairNotes,

      // Use the combined LIST fields (Requires Shoe Model Update)
      sizeEur: finalEurList,
      sizeUk: finalUkList,

      condition: conditionValue,
      sellingPrice: priceValue.toDouble(),
      quantity: quantity,

      instagramLink: _instagramController.text.trim().isEmpty
          ? null
          : ShoeQueryUtils.cleanLink(_instagramController.text.trim()),
      tiktokLink: _tiktokController.text.trim().isEmpty
          ? null
          : ShoeQueryUtils.cleanLink(_tiktokController.text.trim()),
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
        isTest: isTest,
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

  @override
  Widget build(BuildContext context) {
    // Build the image preview widget
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
              ShoeSizePicker(
                isSingleSize: isSingleSize,
                isBound: _isBound,
                isLoading: _isLoading,
                displayEurSize: _displayEurSize,
                displayUkSize: _displayUkSize,
                currentEurSizes: _currentEurSizes,
                onBoundChanged: (val) => setState(() => _isBound = val),
                onEurSizeSelected: _handleDisplayEurSizeSelected,
                onUkSizeSelected: _handleDisplayUkSizeSelected,
                onMultiSizeChanged: (sizes) =>
                    setState(() => _currentEurSizes = sizes),
              ),
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
                  if (value == null || ShoeQueryUtils.safeIntParse(value) < 1) {
                    return 'Quantity must be 1 or more.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ShoeConditionPicker(
                selectedCondition: _selectedCondition,
                isLoading: _isLoading,
                onConditionSelected: _handleConditionSelected,
              ),
              const SizedBox(height: 16),

              ShoeStatusSelector(
                selectedStatus: _status,
                repairNotes: _repairNotes,
                isLoading: _isLoading,
                onStatusChanged: (newStatus) => setState(() {
                  _status = newStatus;
                  if (newStatus != 'Repaired') _repairNotes = '';
                }),
                onRepairNotesChanged: (notes) => setState(() {
                  _repairNotes = notes;
                }),
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
                validator: (value) =>
                    ShoeQueryUtils.validateLink(value, 'instagram.com'),
              ),
              TextFormField(
                controller: _tiktokController,
                enabled: !_isLoading,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'TikTok Link'),
                validator: (value) =>
                    ShoeQueryUtils.validateLink(value, 'tiktok.com'),
              ),
              const SizedBox(height: 16),

              // --- IMAGE PICKER (Unchanged) ---
              ShoeImagePicker(
                imageFile: _dialogImageFile,
                remoteImageUrl: _currentRemoteImageUrl,
                isLoading: _isLoading,
                onImagePicked: (file) {
                  setState(() {
                    _dialogImageFile = file;
                    _currentRemoteImageUrl = '';
                  });
                },
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
