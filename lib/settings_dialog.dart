import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Helpers/version_footer.dart';
import 'package:shoe_view/firebase_service.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'error_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final FirebaseService firebaseService;

  const SettingsDialog({super.key, required this.firebaseService});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  File? _logoFile;
  ThemeMode _selectedTheme = ThemeMode.light;
  String _currencyCode = 'USD';
  bool _isMultiSize = false;

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _loadDefaultSettings();
  }

  Future<void> _loadLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) {
      final tempPath = File(
        '${dir.path}/logo_temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await logoPath.copy(tempPath.path);
      setState(() => _logoFile = tempPath);
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

    final tempPath = File(
      '${dir.path}/logo_temp_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await savedFile.copy(tempPath.path);

    setState(() => _logoFile = tempPath);
  }

  Future<void> _signOutAndReturnToMain() async {
    try {
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (e) {
      print('Error signing out: $e');
    }
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

      final response = await widget.firebaseService.deleteUserData();
      AppLogger.log('reposen - $response');
      Navigator.of(context).pop(); // Dismiss loader

      if (response['success']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['message'])));
      }
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loader
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to clear app data: $e')));
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (_) => ErrorDialog(
        title: 'Clear All Data?',
        message:
            'This will delete all your saved data and reset the app. Are you sure?',
        onDismissed: () => Navigator.of(context).pop(),
        onYesPressed: () async {
          await _clearAppData();
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/main', (route) => false);
        },
      ),
    );
  }

  Future<void> _loadDefaultSettings() async {
    setState(() {
      final appStatus = context.read<AppStatusNotifier>();
      _selectedTheme = appStatus.themeMode;
      _currencyCode = appStatus.currencyCode;
      _isMultiSize = appStatus.isMultiSizeModeEnabled;
    });
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    setState(() => _selectedTheme = mode);

    final appStatus = context.read<AppStatusNotifier>();
    appStatus.updateThemeMode(mode);
  }

  Future<void> _updateCurrencyPreference(String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currencyCode);
    setState(() {
      _currencyCode = currencyCode;
    });
    final appStatus = context.read<AppStatusNotifier>();
    appStatus.updateCurrencyCode(_currencyCode);
  }

  Future<void> _updateMultiSizePreference(bool isMultiSizeModeEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('multiSize', _isMultiSize);
    setState(() {
      _isMultiSize = isMultiSizeModeEnabled;
    });
    final appStatus = context.read<AppStatusNotifier>();
    appStatus.updateMultiSizeMode(_isMultiSize);
  }

  @override
  Widget build(BuildContext context) {
    final appStatus = context.watch<AppStatusNotifier>();
    final tier = appStatus.tier;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: SizedBox(
        width: double.infinity,
        height: 640,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // ✅ Title row
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
              const Text(
                'Your Logo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _logoFile != null
                      ? Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.file(_logoFile!, fit: BoxFit.cover),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 40,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _pickLogoImage,
                          child: const Text('Upload'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Theme Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ThemeMode.values.map((mode) {
                  final label =
                      mode.name[0].toUpperCase() + mode.name.substring(1);
                  return Row(
                    children: [
                      Radio<ThemeMode>(
                        value: mode,
                        groupValue: _selectedTheme,
                        onChanged: (ThemeMode? value) {
                          if (value != null) _updateTheme(value);
                        },
                      ),
                      Text(label),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              const Text(
                'Currency',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ShoeQueryUtils.currencies.map((currency) {
                    final code = currency['code']!;
                    final symbol = currency['symbol']!;
                    final isSelected = _currencyCode == code;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$code ($symbol)'),
                        selected: isSelected,
                        onSelected: (_) {
                          _updateCurrencyPreference(code);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Multi-Size Inventory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: const Text('Enable Multi-Size Inventory Mode', style: TextStyle(fontSize: 16),),
                trailing: Switch(
                  value: _isMultiSize,
                  onChanged: (bool value) {
                    // Use the new toggle method to update the global state
                    _updateMultiSizePreference(value);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Tier: ${(tier)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showClearDataDialog,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _signOutAndReturnToMain,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const VersionFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
