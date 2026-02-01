import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoe_view/Helpers/quota_circle.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Helpers/version_footer.dart';
import 'package:shoe_view/Services/firebase_service.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';
import 'package:shoe_view/Subscription/subscription_upgrade_page.dart';
import 'package:shoe_view/app_status_notifier.dart';

class SettingsDialog extends StatefulWidget {
  final FirebaseService firebaseService;
  final SubscriptionManager subscriptionManager;

  const SettingsDialog({
    super.key,
    required this.firebaseService,
    required this.subscriptionManager,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SingleTickerProviderStateMixin {
  File? _logoFile;
  String _version = '';

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
  bool _isInstagramOnly = false;
  bool _isConciseMode = false;

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
    _loadVersion();
    _loadSettingsFromNotifier();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }
  
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    }
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
      _isInstagramOnly = prefs.getBool('isInstagramOnly') ?? app.isInstagramOnly;
      _isConciseMode = prefs.getBool('isConciseMode') ?? app.isConciseMode;

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              content,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: confirmColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(confirmLabel),
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
      prefs.setBool('isInstagramOnly', _isInstagramOnly),
      prefs.setBool('isConciseMode', _isConciseMode),
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
        isInstagramOnly: _isInstagramOnly,
        isConciseMode: _isConciseMode,
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
      confirmColor: Colors.redAccent,
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
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200, // Slightly improved quality
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final savedFile = File('${dir.path}/logo.jpg');
      await savedFile.writeAsBytes(bytes);
      setState(() => _logoFile = savedFile);
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _removeLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) await logoPath.delete();
    setState(() => _logoFile = null);
  }

  // --- UI Builders ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]))
              : null,
          value: value,
          onChanged: onChanged,
          activeColor: Colors.indigo.shade600,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          dense: true,
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.5, indent: 16, endIndent: 16, color: Colors.grey[200]),
      ],
    );
  }

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
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.indigo.shade300, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
          decoration: BoxDecoration(
            color: Colors.grey[100], // Premium off-white background
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings_rounded, size: 24, color: Colors.black87),
                    const SizedBox(width: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Profile
                      _buildSectionHeader('Business Profile'),
                      _buildCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _pickLogoImage,
                                  onLongPress: _logoFile != null 
                                    ? () async {
                                        await HapticFeedback.mediumImpact();
                                        _handleClearData(); // Used to check permissions, but here just clear logic?
                                        // Wait, long press on logo to delete it? 
                                        // Let's stick to the previous behavior: remove logo.
                                        _removeLogo();
                                      } 
                                    : null,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey.shade300),
                                      image: _logoFile != null
                                          ? DecorationImage(
                                              image: FileImage(_logoFile!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _logoFile == null
                                        ?  Icon(Icons.add_a_photo_rounded,
                                            size: 28, color: Colors.grey[400])
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'TIER ${app.tier}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Ver: $_version',
                                            style: TextStyle(
                                                fontSize: 12, color: Colors.grey[500]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // General Settings
                      _buildSectionHeader('General'),
                      _buildCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Text('Currency', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                const Spacer(),
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _currencyCode,
                                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                                      style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                      onChanged: (v) => setState(() => _currencyCode = v!),
                                      items: ShoeQueryUtils.currencies.map((c) {
                                        return DropdownMenuItem(
                                          value: c['code'],
                                          child: Text(c['code']!),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _buildToggleTile(
                            title: 'Multi-Size Inventory',
                            subtitle: 'Enable support for multiple sizes per item',
                            value: _isMultiSize,
                            onChanged: (v) => setState(() => _isMultiSize = v),
                            showDivider: true,
                          ),
                           ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Sample Share Count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            trailing: SizedBox(
                              width: 60,
                              height: 36,
                              child: TextField(
                                controller: _sampleController,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.all(8),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Test Mode & Advanced
                      if (app.isTestModeEnabled) ...[
                        _buildSectionHeader('Advanced Controls'),
                        _buildCard(
                          children: [
                            _buildToggleTile(
                              title: 'Test Mode',
                              value: _isTest,
                              onChanged: (v) => setState(() => _isTest = v),
                              showDivider: _isTest,
                            ),
                            if (_isTest) ...[
                              _buildToggleTile(
                                title: 'Show Repaired Info',
                                subtitle: 'Also include repaired notes',
                                value: _isRepairedInfoAvailable,
                                onChanged: (v) => setState(() => _isRepairedInfoAvailable = v),
                              ),
                              _buildToggleTile(
                                title: 'Auto-Copy Info',
                                subtitle: 'Copies data to clipboard when sharing',
                                value: _isInfoCopied,
                                onChanged: (v) => setState(() => _isInfoCopied = v),
                              ),
                              _buildToggleTile(
                                title: 'Instagram Only',
                                subtitle: 'Only Instagram message, no TikTok link',
                                value: _isInstagramOnly,
                                onChanged: (v) => setState(() => _isInstagramOnly = v),
                              ),
                              _buildToggleTile(
                                title: 'Concise Copy',
                                subtitle: 'Minimal copy text: name, price, condition, link',
                                value: _isConciseMode,
                                onChanged: (v) => setState(() => _isConciseMode = v),
                              ),
                              _buildToggleTile(
                                title: 'Hide Prices',
                                subtitle: 'Hides price information in list',
                                value: _isPriceHidden,
                                onChanged: (v) => setState(() => _isPriceHidden = v),
                              ),
                              _buildToggleTile(
                                title: 'High Res Collage',
                                subtitle: 'Use higher resolution images (slower)',
                                value: _isHighResCollage,
                                onChanged: (v) => setState(() => _isHighResCollage = v),
                              ),
                              _buildToggleTile(
                                title: 'Share All (Incl. Upcoming)',
                                subtitle: 'Active, Unreleased and repaired',
                                value: _isAllShoesShare,
                                onChanged: (v) => setState(() => _isAllShoesShare = v),
                                showDivider: false, // last one
                              ),
                            ],
                          ],
                        ),
                      ],

                      // Pricing Simulation
                      if (_isTest) ...[
                        _buildSectionHeader('Price Simulation'),
                        _buildCard(
                          children: [
                            // Flat Discount toggle - disabled when Sale Price Range is ON
                            _buildToggleTile(
                              title: 'Flat Discount',
                              subtitle: _isFlatSale ? null : 'Apply single % off to all items',
                              value: _isFlatSale,
                              onChanged: _isSalePrice 
                                  ? null  // Disabled when Sale Price Range is active
                                  : (v) => setState(() {
                                      _isFlatSale = v;
                                    }),
                              showDivider: true,
                            ),
                            if (_isFlatSale)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: _buildNumField('Discount %', _flatDiscountController),
                              ),

                            // Sale Price Range toggle - disabled when Flat Discount is ON
                            _buildToggleTile(
                              title: 'Sale Price Range',
                              subtitle: _isSalePrice ? null : 'Simulate min-max random discounts',
                              value: _isSalePrice,
                              onChanged: _isFlatSale 
                                  ? null  // Disabled when Flat Discount is active
                                  : (v) => setState(() {
                                      _isSalePrice = v;
                                    }),
                              showDivider: _isSalePrice,
                            ),
                            if (_isSalePrice)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(child: _buildNumField("Min %", _lowDiscountController)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildNumField("Max %", _highDiscountController)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                      // Actions
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Save & Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Secondary Actions
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _handleClearData,
                              icon: Icon(Icons.delete_forever_rounded, size: 20, color: Colors.red[400]),
                              label: Text('Clear Data', style: TextStyle(color: Colors.red[400])),
                            ),
                          ),
                          Container(width: 1, height: 24, color: Colors.grey[300]),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _handleSignOut,
                              icon: Icon(Icons.logout_rounded, size: 20, color: Colors.grey[700]),
                              label: Text('Sign Out', style: TextStyle(color: Colors.grey[700])),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Upgrade / Subscription Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                             final subManager = widget.subscriptionManager;
                             // Close dialog first or stack on top? Stacking on top is standard for navigating to a new page.
                             // But let's close the dialog to keep stack clean if that's preferred, 
                             // OR just push. User asked for "In apps button it is not in our newer UI".
                             // Existing logic in shoe_list_view uses push.
                             Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: subManager,
                                child: const SubscriptionUpgradePage(),
                              ),
                            ));
                          },
                          icon: const Icon(Icons.diamond_outlined, color: Colors.amber),
                          label: const Text('Upgrade / Manage Subscription', style: TextStyle(color: Colors.black87)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.amber.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      
                      const SizedBox(height: 24),
                      // Quota Stats
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.share_rounded, size: 18, color: Colors.green[700]),
                                        const SizedBox(width: 8),
                                        Text(
                                          "SHARES",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[800],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${app.dailyShares}",
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                            height: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                                          child: Text(
                                            "/ ${app.dailySharesLimit}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (app.dailySharesLimit > 0) 
                                            ? (app.dailyShares / app.dailySharesLimit).clamp(0.0, 1.0) 
                                            : 0.0,
                                        backgroundColor: Colors.green.withOpacity(0.15),
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, size: 18, color: Colors.blue[700]),
                                        const SizedBox(width: 8),
                                        Text(
                                          "WRITES",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "${app.dailyWrites}",
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                            height: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                                          child: Text(
                                            "/ ${app.dailyWritesLimit}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (app.dailyWritesLimit > 0) 
                                            ? (app.dailyWrites / app.dailyWritesLimit).clamp(0.0, 1.0) 
                                            : 0.0,
                                        backgroundColor: Colors.blue.withOpacity(0.15),
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
