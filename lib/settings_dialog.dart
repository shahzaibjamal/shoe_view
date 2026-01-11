import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/quota_circle.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Helpers/version_footer.dart';
import 'package:shoe_view/Services/firebase_service.dart';
import 'package:shoe_view/app_status_notifier.dart';

class SettingsDialog extends StatefulWidget {
  final FirebaseService firebaseService;

  const SettingsDialog({super.key, required this.firebaseService});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  File? _logoFile;

  bool _hasTestModePermission = false;
  // Local State
  ThemeMode _selectedTheme = ThemeMode.light;
  String _currencyCode = 'USD';
  bool _isMultiSize = false;
  bool _isTest = false;
  bool _isSalePrice = false;
  bool _isRepairedInfoAvailable = false;
  bool _isHighResCollage = false;
  bool _isAllShoesShare = false;
  bool _isFlatSale = false;
  bool _isPriceHidden = false;
  bool _isInfoCopied = false;

  // Controllers
  late TextEditingController _sampleController;
  late TextEditingController _lowDiscountController;
  late TextEditingController _highDiscountController;
  late TextEditingController _flatDiscountController;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _sampleController = TextEditingController();
    _lowDiscountController = TextEditingController();
    _highDiscountController = TextEditingController();
    _flatDiscountController = TextEditingController();

    _loadLogo();
    _loadSettingsFromNotifier();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _sampleController.dispose();
    _lowDiscountController.dispose();
    _highDiscountController.dispose();
    _flatDiscountController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --- Data Loading ---

  void _loadSettingsFromNotifier() async {
    final app = context.read<AppStatusNotifier>();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasTestModePermission =
          prefs.getBool('isTestModeEnabled_Permission') ??
          app.isTestModeEnabled;
      _selectedTheme = app.themeMode;
      _currencyCode = app.currencyCode;
      _isMultiSize = app.isMultiSizeModeEnabled;
      _isTest = app.isTest;
      _isSalePrice = app.isSalePrice;
      _isRepairedInfoAvailable = app.isRepairedInfoAvailable;
      _isHighResCollage = app.isHighResCollage;
      _isAllShoesShare = app.isAllShoesShare;
      _isFlatSale = app.isFlatSale;
      _isPriceHidden = app.isPriceHidden;
      _isInfoCopied = app.isInfoCopied;

      _sampleController.text = app.sampleShareCount.toString();
      _lowDiscountController.text = app.lowDiscount.toString();
      _highDiscountController.text = app.highDiscount.toString();
      _flatDiscountController.text = app.flatDiscount.toString();
    });
  }

  Future<void> _loadLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) {
      setState(() => _logoFile = logoPath);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    Color confirmColor = Colors.red,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  confirmLabel,
                  style: TextStyle(color: confirmColor),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- Logic Actions ---

  Future<void> _saveSettings() async {
    final int finalSampleCount = int.tryParse(_sampleController.text) ?? 4;
    final double finalLow = double.tryParse(_lowDiscountController.text) ?? 7.0;
    final double finalHigh =
        double.tryParse(_highDiscountController.text) ?? 10.0;
    final double finalFlat =
        double.tryParse(_flatDiscountController.text) ?? 0.0;

    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.setString('themeMode', _selectedTheme.name),
      prefs.setString('currency', _currencyCode),
      prefs.setBool('multiSize', _isMultiSize),
      prefs.setBool('isTest', _isTest),
      prefs.setBool('isSalePrice', _isSalePrice),
      prefs.setBool('isFlatSale', _isFlatSale),
      prefs.setBool('isPriceHidden', _isPriceHidden),
      prefs.setBool('isInfoCopied', _isInfoCopied),
      prefs.setDouble('lowDiscount', finalLow),
      prefs.setDouble('highDiscount', finalHigh),
      prefs.setDouble('flatDiscount', finalFlat),
      prefs.setInt('sampleShareCount', finalSampleCount),
    ]);

    if (mounted) {
      context.read<AppStatusNotifier>().updateAllSettings(
        themeMode: _selectedTheme,
        currencyCode: _currencyCode,
        isMultiSize: _isMultiSize,
        isTest: _isTest,
        isSalePrice: _isSalePrice,
        isRepairedInfoAvailable: _isRepairedInfoAvailable,
        isHighResCollage: _isHighResCollage,
        isAllShoesShare: _isAllShoesShare,
        sampleShareCount: finalSampleCount,
        isFlatSale: _isFlatSale,
        lowDiscount: finalLow,
        highDiscount: finalHigh,
        flatDiscount: finalFlat,
        isPriceHidden: _isPriceHidden,
        isInfoCopied: _isInfoCopied,
      );
      Navigator.pop(context);
    }

    await widget.firebaseService.updateUserProfile({
      'isMultiSize': _isMultiSize,
      'currencyCode': _currencyCode,
    });
  }

  Future<void> _handleClearData() async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear Data',
      content:
          'This will delete all local settings, your business logo, and your cloud data. This cannot be undone.',
      confirmLabel: 'Clear Everything',
    );

    if (confirmed && mounted) {
      _performClearAppData();
    }
  }

  Future<void> _performClearAppData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _removeLogo();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await widget.firebaseService.deleteUserData();

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/main', (route) => false);
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await _showConfirmDialog(
      title: 'Sign Out',
      content: 'Are you sure you want to sign out of your account?',
      confirmLabel: 'Sign Out',
      confirmColor: Colors.blue,
    );

    if (confirmed && mounted) {
      try {
        await GoogleSignIn.instance.signOut();
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          context.read<AppStatusNotifier>().reset();
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/main', (route) => false);
        }
      } catch (e) {
        debugPrint('Sign out error: $e');
      }
    }
  }

  Future<void> _pickLogoImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 150,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final dir = await getApplicationDocumentsDirectory();
    final savedFile = File('${dir.path}/logo.jpg');
    await savedFile.writeAsBytes(bytes);
    setState(() => _logoFile = savedFile);
  }

  Future<void> _removeLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) await logoPath.delete();
    setState(() => _logoFile = null);
  }

  // --- UI Builders ---

  Widget _buildNumField(
    String label,
    TextEditingController ctrl, {
    String suffix = '%',
  }) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStatusNotifier>();

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Logo Section
              const Text(
                'Business Logo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickLogoImage,
                    onLongPress: () async {
                      if (_logoFile != null) {
                        await HapticFeedback.mediumImpact();
                        _removeLogo();
                      }
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _logoFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_logoFile!, fit: BoxFit.cover),
                            )
                          : const Icon(
                              Icons.add_a_photo,
                              size: 20,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tap to upload.\nLong-press to remove.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),

              const Divider(height: 32),

              // Appearance
              const Text(
                'Appearance',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: ThemeMode.values
                    .map(
                      (mode) => Expanded(
                        child: RadioListTile<ThemeMode>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            mode.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: mode,
                          groupValue: _selectedTheme,
                          onChanged: (v) => setState(() => _selectedTheme = v!),
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 16),

              // Currency
              const Text(
                'Currency',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ShoeQueryUtils.currencies
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c['code']!),
                            selected: _currencyCode == c['code'],
                            onSelected: (_) =>
                                setState(() => _currencyCode = c['code']!),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const Divider(height: 32),

              // Inventory
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Multi-Size Inventory'),
                value: _isMultiSize,
                onChanged: (v) => setState(() => _isMultiSize = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sample Share Count'),
                trailing: SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _sampleController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ),

              // Test Mode
              if (app.isTestModeEnabled) ...[
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable Test Mode',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: _isTest,
                  onChanged: (v) => setState(() => _isTest = v),
                ),
                if (_isTest) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Repaired Info'),
                    subtitle: const Text(
                      'Also include repaired notes',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isRepairedInfoAvailable,
                    onChanged: (v) =>
                        setState(() => _isRepairedInfoAvailable = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Copy Info'),
                    subtitle: const Text(
                      'Copies data to clipboard when sharing',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isInfoCopied,
                    onChanged: (v) => setState(() => _isInfoCopied = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide Prices'),
                    value: _isPriceHidden,
                    onChanged: (v) => setState(() => _isPriceHidden = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('High Res Collage'),
                    value: _isHighResCollage,
                    onChanged: (v) => setState(() => _isHighResCollage = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share All Shoes'),
                    subtitle: const Text(
                      'Active, Unreleased and repaired',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isAllShoesShare,
                    onChanged: (v) => setState(() => _isAllShoesShare = v),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pricing Simulation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Crossed-out Sale Price'),
                    subtitle: const Text(
                      'Shows range: Min% - Max%',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isSalePrice,
                    onChanged: (v) => setState(() {
                      _isSalePrice = v;
                      if (v) _isFlatSale = false;
                    }),
                  ),
                  if (_isSalePrice)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildNumField(
                              "Min %",
                              _lowDiscountController,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildNumField(
                              "Max %",
                              _highDiscountController,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Apply Flat Discount'),
                    subtitle: const Text(
                      'Applies single % to all',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isFlatSale,
                    onChanged: (v) => setState(() {
                      _isFlatSale = v;
                      if (v) _isSalePrice = false;
                    }),
                  ),
                  if (_isFlatSale)
                    _buildNumField(
                      "Discount Percentage",
                      _flatDiscountController,
                    ),
                ],
              ],
              const SizedBox(height: 32),
              // Actions
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save and Apply Changes'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleClearData,
                      child: const Text(
                        'Clear Data',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleSignOut,
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bottom Left: Shares Used
                  QuotaCircle(
                    label: "SHARES",
                    used: app.dailyShares,
                    limit: app.dailySharesLimit,
                    color: Colors.green,
                  ),

                  // Center: Tier & Version
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TIER: ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w400, // Lighter for the label
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              '${app.tier}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight
                                    .bold, // Heavier for the actual value
                                color: Colors.blue,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const VersionFooter(),
                      Text(
                        'User: ${app.email}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  // Bottom Right: Writes Used
                  QuotaCircle(
                    label: "WRITES",
                    used: app.dailyWrites,
                    limit: app.dailyWritesLimit,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
