import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int _sampleShareCount = 4;

  late TextEditingController _sampleController;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _sampleController = TextEditingController();
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
      _sampleController.text = _sampleShareCount.toString();
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
    await prefs.setInt('sampleShareCount', _sampleShareCount);

    final app = context.read<AppStatusNotifier>();
    app.updateThemeMode(_selectedTheme);
    app.updateCurrencyCode(_currencyCode);
    app.updateMultiSizeMode(_isMultiSize);
    app.updateTest(_isTest);
    app.updateSalePrice(_isSalePrice);
    app.updateRepairedInfoAvailable(_isRepairedInfoAvailable);
    app.updateHighResCollage(_isHighResCollage);
    app.updateSampleShareCount(_sampleShareCount);

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
                  title: const Text('Show repaired info'),
                  trailing: Switch(
                    value: _isRepairedInfoAvailable,
                    onChanged: (v) =>
                        setState(() => _isRepairedInfoAvailable = v),
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
                  title: const Text('Enable Sale Price'),
                  trailing: Switch(
                    value: _isSalePrice,
                    onChanged: (v) => setState(() => _isSalePrice = v),
                  ),
                ),

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
