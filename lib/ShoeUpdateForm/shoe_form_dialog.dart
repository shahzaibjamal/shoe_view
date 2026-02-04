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
  late final TextEditingController _soldToController;

  // NEW: Combined Size Management
  // This Set stores all sizes selected. If length is 1, it's single-size mode.
  Set<String> _currentEurSizes = {};

  // These variables are only used for display purposes when in Single Size Mode
  late String _displayEurSize;
  late String _displayUkSize;
  String _repairNotes = '';
  String _imagesLink = '';
  bool _isBound = true; // true = changing one auto-updates the other (default)

  // Local State
  File? _dialogImageFile;
  String _currentRemoteImageUrl = '';
  bool _isLoading = false;
  bool _isEditing;
  String _status = 'Available';
  DateTime? _lastEdit;
  DateTime? _soldOn;
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
    _imagesLink = widget.shoe?.imagesLink ?? '';

    _status = widget.shoe?.status ?? 'Available';
    _isBound = widget.shoe?.isSizeLinked ?? true;
    _quantityController = TextEditingController(
      text: widget.shoe?.quantity.toString() ?? '1',
    );
    _lastEdit = widget.shoe?.lastEdit;
    _soldOn = widget.shoe?.soldOn;

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
    _soldToController = TextEditingController(
      text: widget.shoe?.soldTo ?? '',
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
    _soldToController.dispose();
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
      imagesLink: _imagesLink,

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
      lastEdit: DateTime.now(),
      soldOn: (_status == 'Sold') 
          ? (widget.shoe?.status == 'Sold' ? _soldOn : DateTime.now())
          : null,
      soldTo: _status == 'Sold' ? _soldToController.text.trim() : '',
    );

    // Start loading state
    final appStatus = context.read<AppStatusNotifier>();
    final uniqueId = '${newShoe.itemId}_${newShoe.shipmentId}';
    
    setState(() {
      _isLoading = true;
    });
    
    // Set as pending for "Instant" feel
    appStatus.setItemPendingSync(uniqueId, true);

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

      // Successfully processed, remove from pending
      appStatus.setItemPendingSync(uniqueId, false);

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
      appStatus.setItemPendingSync(uniqueId, false);
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
    final bool isMultiSizeModeEnabled =
        context.watch<AppStatusNotifier>().isMultiSizeModeEnabled;
    bool isSingleSize = !isMultiSizeModeEnabled;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEditing ? 'Update Shoe Details' : 'Add New Kick',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // --- Content ---
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Identification', Icons.tag_rounded),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _shoeIdController,
                                label: 'Item ID',
                                icon: Icons.numbers_rounded,
                                keyboardType: TextInputType.number,
                                maxLength: 3,
                                enabled: !_isEditing && !_isLoading,
                                errorText: _itemIdError,
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                helper: _isEditing ? 'Locked' : 'Req.',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _shipmentIdController,
                                label: 'Shipment',
                                icon: Icons.local_shipping_rounded,
                                keyboardType: TextInputType.number,
                                maxLength: 3,
                                enabled: !_isEditing && !_isLoading,
                                errorText: _shipmentIdError,
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                                helper: _isEditing ? 'Locked' : 'Req.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Shoe Name / Detail',
                          icon: Icons.abc_rounded,
                          maxLength: 30,
                          enabled: !_isLoading,
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Detail required' : null,
                        ),

                        const SizedBox(height: 24),
                        _buildSectionHeader('Sizing & Stock', Icons.straighten_rounded),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ShoeSizePicker(
                            isSingleSize: isSingleSize,
                            isBound: _isBound,
                            isLoading: _isLoading,
                            displayEurSize: _displayEurSize,
                            displayUkSize: _displayUkSize,
                            currentEurSizes: _currentEurSizes,
                            onBoundChanged: (val) => setState(() => _isBound = val),
                            onEurSizeSelected: _handleDisplayEurSizeSelected,
                            onUkSizeSelected: _handleDisplayUkSizeSelected,
                            onMultiSizeChanged: (sizes) => setState(() => _currentEurSizes = sizes),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _quantityController,
                          label: 'Inventory Quantity',
                          icon: Icons.inventory_2_rounded,
                          keyboardType: TextInputType.number,
                          enabled: !_isLoading,
                          maxLength: 3,
                          validator: (val) => (val == null || ShoeQueryUtils.safeIntParse(val) < 1) ? 'Min 1' : null,
                        ),

                        const SizedBox(height: 24),
                        _buildSectionHeader('Condition & Status', Icons.stars_rounded),
                        const SizedBox(height: 12),
                        ShoeConditionPicker(
                          selectedCondition: _selectedCondition,
                          isLoading: _isLoading,
                          onConditionSelected: _handleConditionSelected,
                        ),
                        const SizedBox(height: 16),
                        ShoeStatusSelector(
                          selectedStatus: _status,
                          repairNotes: _repairNotes,
                          imagesLink: _imagesLink,
                          isLoading: _isLoading,
                          onStatusChanged: (newStatus) => setState(() {
                            _status = newStatus;
                            if (newStatus != 'Repaired') _repairNotes = '';
                          }),
                          onRepairNotesChanged: (notes) => setState(() => _repairNotes = notes),
                          onImagesLinkChanged: (imagesLink) => setState(() => _imagesLink = imagesLink),
                        ),

                        if (_status == 'Sold') ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _soldToController,
                            label: 'Sold To (Name, @Handle, or #)',
                            icon: Icons.person_add_alt_1_rounded,
                            enabled: !_isLoading,
                            helper: 'Track your customer for future reference.',
                          ),
                        ],
                        
                        // NEW: Last Edit & Sold On Display (ReadOnly)
                        if (_isEditing) ...[
                          const SizedBox(height: 16),
                          _buildAuditInfo(),
                        ],

                        const SizedBox(height: 24),
                        _buildSectionHeader('Pricing & Media', Icons.payments_rounded),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _priceController,
                          label: 'Price ($currency)',
                          icon: Icons.sell_rounded,
                          keyboardType: TextInputType.number,
                          enabled: !_isLoading,
                          maxLength: 6,
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                        ),
                        
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _status != 'Repaired' ? Column(
                            key: const ValueKey('social_fields'),
                            children: [
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _instagramController,
                                label: 'Instagram Link',
                                icon: Icons.camera_alt_rounded,
                                keyboardType: TextInputType.url,
                                enabled: !_isLoading,
                                validator: (val) => ShoeQueryUtils.validateLink(val, 'instagram.com'),
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _tiktokController,
                                label: 'TikTok Link',
                                icon: Icons.video_collection_rounded,
                                keyboardType: TextInputType.url,
                                enabled: !_isLoading,
                                validator: (val) => ShoeQueryUtils.validateLink(val, 'tiktok.com'),
                              ),
                            ],
                          ) : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),
              ),

              // --- Actions ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        HapticFeedback.mediumImpact();
                        _saveShoe();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isEditing ? 'Update Shoe' : 'Add to Collection',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey[400]),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey[400],
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    int? maxLength,
    TextInputType? keyboardType,
    String? errorText,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        errorText: errorText,
        helperText: helper,
        counterText: '',
        filled: true,
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildAuditInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: Colors.blueGrey[400]),
              const SizedBox(width: 8),
              Text(
                'Audit Information',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[400],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAuditRow('Last Edit:', _formatDate(_lastEdit)),
          if (_status == 'Sold') ...[
            const SizedBox(height: 4),
            _buildAuditRow('Sold On:', _formatDate(_soldOn), color: Colors.green[700]),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.blueGrey[800],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    // Simple format: DD/MM/YYYY HH:MM
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
