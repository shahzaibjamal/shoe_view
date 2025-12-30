import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
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

  ThemeMode _selectedTheme = ThemeMode.light;
  String _currencyCode = 'USD';
  bool _isMultiSize = false;
  bool _isTest = false;
  bool _isSalePrice = false;
  bool _isRepairedInfoAvailable = false;
  bool _isHighResCollage = false;
  bool _isAllShoesShare = false;
  int _sampleShareCount = 4;

  late TextEditingController _sampleController;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  bool _isPriceHidden = false;

  bool _isFlatSale = false;
  double _lowDiscount = 0.0;
  double _highDiscount = 0.0;
  double _flatDiscount = 0.0;

  // New Controllers
  late TextEditingController _lowDiscountController;
  late TextEditingController _highDiscountController;
  late TextEditingController _flatDiscountController;

  @override
  void initState() {
    super.initState();
    _sampleController = TextEditingController();
    _lowDiscountController = TextEditingController();
    _highDiscountController = TextEditingController();
    _flatDiscountController = TextEditingController();

    _loadLogo();
    _loadSettingsFromNotifier();

    // Smooth dialog animation
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
    _animController.dispose();
    _lowDiscountController.dispose();
    _highDiscountController.dispose();
    _flatDiscountController.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) {
      setState(() => _logoFile = logoPath);
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

    if (await logoPath.exists()) {
      await logoPath.delete();
    }

    setState(() => _logoFile = null);
  }

  void _loadSettingsFromNotifier() {
    final app = context.read<AppStatusNotifier>();

    setState(() {
      _selectedTheme = app.themeMode;
      _currencyCode = app.currencyCode;
      _isMultiSize = app.isMultiSizeModeEnabled;
      _isTest = app.isTest;
      _isSalePrice = app.isSalePrice;
      _isRepairedInfoAvailable = app.isRepairedInfoAvailable;
      _sampleShareCount = app.sampleShareCount;
      _isHighResCollage = app.isHighResCollage;
      _isAllShoesShare = app.isAllShoesShare;
      _sampleController.text = _sampleShareCount.toString();
      _isFlatSale = app.isFlatSale;
      _lowDiscount = app.lowDiscount;
      _highDiscount = app.highDiscount;
      _flatDiscount = app.flatDiscount;
      _isPriceHidden = app.isPriceHidden;

      _lowDiscountController.text = _lowDiscount.toString();
      _highDiscountController.text = _highDiscount.toString();
      _flatDiscountController.text = _flatDiscount.toString();
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('themeMode', _selectedTheme.name);
    await prefs.setString('currency', _currencyCode);
    await prefs.setBool('multiSize', _isMultiSize);
    await prefs.setBool('isTest', _isTest);
    await prefs.setBool('isSalePrice', _isSalePrice);
    await prefs.setBool('isRepairedInfoAvailable', _isRepairedInfoAvailable);
    await prefs.setBool('isHighResCollage', _isHighResCollage);
    await prefs.setBool('isAllShoesShare', _isAllShoesShare);
    await prefs.setInt('sampleShareCount', _sampleShareCount);
    await prefs.setBool('isFlatSale', _isFlatSale);
    await prefs.setBool('isPriceHidden', _isPriceHidden);
    await prefs.setDouble('lowDiscount', _lowDiscount);
    await prefs.setDouble('highDiscount', _highDiscount);
    await prefs.setDouble('flatDiscount', _flatDiscount);

    final app = context.read<AppStatusNotifier>();
    // app.updateThemeMode(_selectedTheme);
    // app.updateCurrencyCode(_currencyCode);
    // app.updateMultiSizeMode(_isMultiSize);
    // app.updateTest(_isTest);
    // app.updateSalePrice(_isSalePrice);
    // app.updateRepairedInfoAvailable(_isRepairedInfoAvailable);
    // app.updateHighResCollage(_isHighResCollage);
    // app.updateAllShoesShare(_isAllShoesShare);
    // app.updateSampleShareCount(_sampleShareCount);
    // app.updateFlatSale(_isFlatSale);
    // app.updatePriceHidden(_isPriceHidden);
    // app.updateFlatDiscountPercent(_flatDiscount);
    // app.updateLowDiscountPercent(_lowDiscount);
    // app.updateHighDiscountPercent(_highDiscount);

    app.updateAllSettings(
      themeMode: _selectedTheme,
      currencyCode: _currencyCode,
      isMultiSize: _isMultiSize,
      isTest: _isTest,
      isSalePrice: _isSalePrice,
      isRepairedInfoAvailable: _isRepairedInfoAvailable,
      isHighResCollage: _isHighResCollage,
      isAllShoesShare: _isAllShoesShare,
      sampleShareCount: _sampleShareCount,
      isFlatSale: _isFlatSale,
      lowDiscount: _lowDiscount,
      highDiscount: _highDiscount,
      flatDiscount: _flatDiscount,
      isPriceHidden: _isPriceHidden,
    );

    if (mounted) Navigator.pop(context);

    await widget.firebaseService.updateUserProfile({
      'isMultiSize': _isMultiSize,
      'currencyCode': _currencyCode,
    });
  }

  Future<void> _confirmClearData() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear All Data"),
        content: const Text(
          "This will delete all saved data and reset the app.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (result == true) _clearAppData();
  }

  Future<void> _clearAppData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final logoFile = File('${dir.path}/logo.jpg');
      if (await logoFile.exists()) {
        await logoFile.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await widget.firebaseService.deleteUserData();

      Navigator.of(context).pop();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to clear app data: $e')));
    }
  }

  Future<void> _confirmSignOut() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );

    if (result == true) _signOut();
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
      context.read<AppStatusNotifier>().reset();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Widget _buildNumField(
    String label,
    TextEditingController ctrl,
    Function(double) onUpdate,
  ) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => onUpdate(double.tryParse(v) ?? 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStatusNotifier>();
    final tier = app.tier;
    final email = app.email;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.settings, size: 32),
                  SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------------- LOGO ----------------
              const Text(
                'Your Logo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Tooltip(
                    message: _logoFile != null
                        ? 'Long press to remove logo'
                        : 'Tap to upload logo',
                    child: GestureDetector(
                      onTap: _pickLogoImage, // Simple tap to upload or change
                      onLongPress: () async {
                        if (_logoFile != null) {
                          // Haptic feedback makes the long-press feel "real"
                          await HapticFeedback.mediumImpact();
                          _removeLogo();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logo removed'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        width: 80, // Increased size for better UX/Tapping
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: _logoFile != null
                                ? Colors.blue.withOpacity(0.5)
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            if (_logoFile != null)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: _logoFile != null
                            ? Image.file(_logoFile!, fit: BoxFit.cover)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: Colors.grey.shade600,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Upload',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Tap the box to upload.\nLong-press to remove.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ---------------- THEME ----------------
              const Text(
                'Theme Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: ThemeMode.values.map((mode) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio(
                        value: mode,
                        groupValue: _selectedTheme,
                        onChanged: (v) => setState(() => _selectedTheme = v!),
                      ),
                      Text(mode.name),
                    ],
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ---------------- CURRENCY ----------------
              const Text(
                'Currency',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ShoeQueryUtils.currencies.map((currency) {
                    final code = currency['code']!;
                    final symbol = currency['symbol']!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$code ($symbol)'),
                        selected: _currencyCode == code,
                        onSelected: (_) => setState(() => _currencyCode = code),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ---------------- MULTI SIZE ----------------
              ListTile(
                title: const Text('Enable Multi-Size Inventory'),
                trailing: Switch(
                  value: _isMultiSize,
                  onChanged: (v) => setState(() => _isMultiSize = v),
                ),
              ),

              // ---------------- SAMPLE SHARE COUNT ----------------
              ListTile(
                title: const Text('Sample Share Count'),
                trailing: SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _sampleController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) {
                      final val = int.tryParse(_sampleController.text) ?? 4;
                      setState(() => _sampleShareCount = val.clamp(0, 12));
                    },
                  ),
                ),
              ),

              // ---------------- TEST MODE ----------------
              if (app.isTestModeEnabled)
                ListTile(
                  title: const Text('Enable Test Mode'),
                  trailing: Switch(
                    value: _isTest,
                    onChanged: (v) => setState(() => _isTest = v),
                  ),
                ),

              if (_isTest)
                ListTile(
                  title: const Text('Show Repaired Info'),
                  trailing: Switch(
                    value: _isRepairedInfoAvailable,
                    onChanged: (v) =>
                        setState(() => _isRepairedInfoAvailable = v),
                  ),
                ),
              if (_isTest)
                ListTile(
                  title: const Text('Hide Prices'),
                  trailing: Switch(
                    value: _isPriceHidden,
                    onChanged: (v) => setState(() => _isPriceHidden = v),
                  ),
                ),
              if (_isTest)
                ListTile(
                  title: const Text('Share High Res Collage'),
                  trailing: Switch(
                    value: _isHighResCollage,
                    onChanged: (v) => setState(() => _isHighResCollage = v),
                  ),
                ),
              if (_isTest)
                ListTile(
                  title: const Text('Share All Shoes'),
                  trailing: Switch(
                    value: _isAllShoesShare,
                    onChanged: (v) => setState(() => _isAllShoesShare = v),
                  ),
                ),
              // ---------------- SALE SETTINGS ----------------
              // ---------------- PRICING & DISCOUNTS ----------------
              if (_isTest) ...[
                const Divider(),
                const Text(
                  "Pricing Display Settings",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                // SECTION 1: Sale Price (Crossed Out)
                ListTile(
                  title: const Text('Show Crossed-out Price'),
                  subtitle: const Text(
                    'Displays a higher market price above actual',
                  ),
                  trailing: Switch(
                    value: _isSalePrice,
                    onChanged: (v) => setState(() => _isSalePrice = v),
                  ),
                ),
                if (_isSalePrice)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildNumField(
                            "Min Markup %",
                            _lowDiscountController,
                            (v) => _lowDiscount = v,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumField(
                            "Max Markup %",
                            _highDiscountController,
                            (v) => _highDiscount = v,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // SECTION 2: Flat Discount (Actual Price Reduction)
                ListTile(
                  title: const Text('Enable Flat Discount'),
                  subtitle: const Text(
                    'Applies a real discount to the final price',
                  ),
                  trailing: Switch(
                    value: _isFlatSale,
                    onChanged: (v) => setState(() => _isFlatSale = v),
                  ),
                ),
                if (_isFlatSale)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildNumField(
                      "Flat Discount %",
                      _flatDiscountController,
                      (v) => _flatDiscount = v,
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text('Current Tier: $tier'),

              const SizedBox(height: 24),

              // ---------------- SAVE BUTTON ----------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Save Settings"),
                  onPressed: _saveSettings,
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- CLEAR DATA + SIGN OUT ----------------
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: const Text("Clear Data"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _confirmClearData,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text("Sign Out"),
                      onPressed: _confirmSignOut,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const VersionFooter(),
              Align(
                alignment: Alignment.center,
                child: Text('signed in as: $email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
