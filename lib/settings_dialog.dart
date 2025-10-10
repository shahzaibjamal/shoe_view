import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'error_dialog.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  File? _logoFile;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) {
      final tempPath = File('${dir.path}/logo_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await logoPath.copy(tempPath.path);
      setState(() => _logoFile = tempPath);
    }
  }

  Future<void> _pickLogoImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 150);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final dir = await getApplicationDocumentsDirectory();
    final savedFile = File('${dir.path}/logo.jpg');
    await savedFile.writeAsBytes(bytes);

    final tempPath = File('${dir.path}/logo_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
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
    final dir = await getApplicationDocumentsDirectory();
    final logoFile = File('${dir.path}/logo.jpg');
    if (await logoFile.exists()) {
      await logoFile.delete();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (_) => ErrorDialog(
        title: 'Clear All Data?',
        message: 'This will delete all your saved data and reset the app. Are you sure?',
        onDismissed: () {
          Navigator.of(context).pop();
        },
        onYesPressed: () async {
          await _clearAppData();
          Navigator.of(context).pop();
          Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: SizedBox(
        width: double.infinity,
        height: 500,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Logo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _logoFile != null
                      ? Image.file(_logoFile!, width: 60, height: 60)
                      : const Icon(Icons.image_not_supported, size: 60),
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
            ],
          ),
        ),
      ),
    );
  }
}
