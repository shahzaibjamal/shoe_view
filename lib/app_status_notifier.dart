import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStatusNotifier extends ChangeNotifier {
  bool _isTest = false;
  bool _isMultiSizeModeEnabled = false;
  String _currencyCode = 'PKR';
  ThemeMode _themeMode = ThemeMode.light;
  bool _isSalePrice = false;
  bool _isRepairedInfoAvailable = false;
  bool _isHighResCollage = false;
  bool _isAllShoesShare = false;
  int _sampleShareCount = 4;
  bool _isTestModeEnabled = false; // "Super user" permission

  bool _isFlatSale = false;
  double _flatDiscount = 0.0;
  bool _isPriceHidden = false;
  bool _isInfoCopied = false;
  bool _isInstagramOnly = false;
  bool _isConciseMode = false;
  bool _allowMobileDataSync = false; // Default: don't sync on mobile data without asking
  bool _sessionMobileSyncAllowed = false; // Persistent for this session only
  bool _hasPromptedForMobileSync = false;
  bool _showConditionGradients = true;
  bool _applySaleToAllStatuses = false;
  String _email = '';
  int _tier = 0;
  String _purchasedOffer = 'none';
  
  // --- Pending Sync Tracking ---
  final Set<String> _pendingSyncItemIds = {};
  Set<String> get pendingSyncItemIds => _pendingSyncItemIds;

  double _lowDiscount = 7;
  double _highDiscount = 10;

  int _dailyShares = 0;
  int _dailySharesLimit = 10;
  int _dailyWrites = 0;
  int _dailyWritesLimit = 10;

  AppStatusNotifier() {
    _loadSettings();
  }

  // Getters
  bool get isTest => _isTest;
  bool get isMultiSizeModeEnabled => _isMultiSizeModeEnabled;
  String get currencyCode => _currencyCode;
  ThemeMode get themeMode => _themeMode;
  bool get isSalePrice => _isSalePrice;
  bool get isRepairedInfoAvailable => _isRepairedInfoAvailable;
  bool get isHighResCollage => _isHighResCollage;
  bool get isAllShoesShare => _isAllShoesShare;
  int get sampleShareCount => _sampleShareCount;
  bool get isTestModeEnabled => _isTestModeEnabled;
  bool get isFlatSale => _isFlatSale;
  bool get isPriceHidden => _isPriceHidden;
  bool get isInfoCopied => _isInfoCopied;
  bool get isInstagramOnly => _isInstagramOnly;
  bool get isConciseMode => _isConciseMode;
  bool get allowMobileDataSync => _allowMobileDataSync;
  bool get sessionMobileSyncAllowed => _sessionMobileSyncAllowed;
  bool get hasPromptedForMobileSync => _hasPromptedForMobileSync;
  bool get showConditionGradients => _showConditionGradients;
  bool get applySaleToAllStatuses => _applySaleToAllStatuses;
  String get email => _email;
  int get tier => _tier;
  String get purchasedOffer => _purchasedOffer;
  double get flatDiscount => _flatDiscount;
  double get lowDiscount => _lowDiscount;
  double get highDiscount => _highDiscount;
  int get dailyShares => _dailyShares;
  int get dailySharesLimit => _dailySharesLimit;
  int get dailyWrites => _dailyWrites;
  int get dailyWritesLimit => _dailyWritesLimit;

  // Setters
  void setIsTest(bool value) {
    _isTest = value;
    notifyListeners();
  }

  void setIsMultiSizeModeEnabled(bool value) {
    _isMultiSizeModeEnabled = value;
    notifyListeners();
  }

  void setCurrencyCode(String value) {
    _currencyCode = value;
    notifyListeners();
  }

  void setDailyShares(int shares, int limit) {
    _dailyShares = shares;
    _dailySharesLimit = limit;
    notifyListeners();
  }

  void setDailyWrites(int writes, int limit) {
    _dailyWrites = writes;
    _dailyWritesLimit = limit;
    notifyListeners();
  }

  void updateDailyShares(int shares) {
    _dailyShares = shares;
    notifyListeners();
  }

  void updateDailySharesLimit(int limit) {
    _dailySharesLimit = limit;
    notifyListeners();
  }

  void updateDailyWrites(int writes) {
    _dailyWrites = writes;
    notifyListeners();
  }

  void updateDailyWritesLimit(int limit) {
    _dailyWritesLimit = limit;
    notifyListeners();
  }

  void updateTier(int tier) {
    _tier = tier;
    notifyListeners();
  }

  void updatePurchasedOffer(String offer) {
    _purchasedOffer = offer;
    notifyListeners();
  }

  void updateEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void updateTestModeEnabled(bool enabled) {
    _isTestModeEnabled = enabled;
    notifyListeners();
  }

  void updateFromResponse(dynamic response, String email) {
    _email = email;
    _isTestModeEnabled = response.isTestModeEnabled;
    _tier = response.tier;
    _dailyShares = response.dailySharesUsed;
    _dailySharesLimit = response.dailySharesLimit;
    _dailyWrites = response.dailyWritesUsed;
    _dailyWritesLimit = response.dailyWritesLimit;
    _isMultiSizeModeEnabled = response.isMultiSize;
    _currencyCode = response.currencyCode;
    _purchasedOffer = response.purchasedOffer;
    notifyListeners();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isTestModeEnabled = prefs.getBool('isTestModeEnabled_Permission') ?? false;
    _isTest = prefs.getBool('isTest') ?? false;
    _isMultiSizeModeEnabled = prefs.getBool('multiSize') ?? false;
    _currencyCode = prefs.getString('currency') ?? 'PKR';
    _isSalePrice = prefs.getBool('isSalePrice') ?? false;
    _isFlatSale = prefs.getBool('isFlatSale') ?? false;
    _flatDiscount = prefs.getDouble('flatDiscountPercent') ?? 7;
    _isPriceHidden = prefs.getBool('isPriceHidden') ?? false;
    _isInfoCopied = prefs.getBool('isInfoCopied') ?? false;
    _isInstagramOnly = prefs.getBool('isInstagramOnly') ?? false;
    _isConciseMode = prefs.getBool('isConciseMode') ?? false;
    _allowMobileDataSync = prefs.getBool('allowMobileDataSync') ?? false;
    _hasPromptedForMobileSync = prefs.getBool('hasPromptedForMobileSync') ?? false;
    _showConditionGradients = prefs.getBool('showConditionGradients') ?? true;
    _applySaleToAllStatuses = prefs.getBool('applySaleToAllStatuses') ?? false;
    _email = prefs.getString('cached_user_email') ?? '';
    _tier = prefs.getInt('tier') ?? 0;
    _purchasedOffer = prefs.getString('purchasedOffer') ?? 'none';
    _flatDiscount = prefs.getDouble('flatDiscountPercent') ?? 7;

    final themeStr = prefs.getString('themeMode') ?? 'light';
    _themeMode = ThemeMode.values.firstWhere((e) => e.name == themeStr);
    
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setSessionMobileSyncAllowed(bool value) {
    _sessionMobileSyncAllowed = value;
    notifyListeners();
  }

  void setHasPromptedForMobileSync(bool value) {
    _hasPromptedForMobileSync = value;
    final prefs = SharedPreferences.getInstance();
    prefs.then((p) => p.setBool('hasPromptedForMobileSync', value));
    notifyListeners();
  }

  void setShowConditionGradients(bool value) {
    _showConditionGradients = value;
    final prefs = SharedPreferences.getInstance();
    prefs.then((p) => p.setBool('showConditionGradients', value));
    notifyListeners();
  }

  void setApplySaleToAllStatuses(bool value) {
    _applySaleToAllStatuses = value;
    final prefs = SharedPreferences.getInstance();
    prefs.then((p) => p.setBool('applySaleToAllStatuses', value));
    notifyListeners();
  }

  void setItemPendingSync(String itemId, bool isPending) {
    if (isPending) {
      _pendingSyncItemIds.add(itemId);
    } else {
      _pendingSyncItemIds.remove(itemId);
    }
    notifyListeners();
  }

  void updateEmailPrefs(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_email', email);
    _email = email;
    notifyListeners();
  }

  void updateFlatDiscountPercent(double flatDiscount) {
    _flatDiscount = flatDiscount;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void reset() {
    _isTest = false;
    _isMultiSizeModeEnabled = false;
    _currencyCode = 'PKR';
    _themeMode = ThemeMode.light;
    _isSalePrice = false;
    _isRepairedInfoAvailable = false;
    _isHighResCollage = false;
    _isAllShoesShare = false;
    _sampleShareCount = 4;
    _isFlatSale = false;
    _flatDiscount = 0.0;
    _isPriceHidden = false;
    _isInfoCopied = false;
    _isInstagramOnly = false;
    _isConciseMode = false;
    _allowMobileDataSync = false;
    _sessionMobileSyncAllowed = false;
    _hasPromptedForMobileSync = false;
    _showConditionGradients = true;
    _applySaleToAllStatuses = false;
    _email = '';
    _tier = 0;
    _purchasedOffer = 'none';
    notifyListeners();
  }

  void updateAllSettings({
    required ThemeMode themeMode,
    required String currencyCode,
    required bool isMultiSize,
    required bool isTest,
    required bool isSalePrice,
    required bool isRepairedInfoAvailable,
    required bool isHighResCollage,
    required bool isAllShoesShare,
    required bool isPriceHidden,
    required int sampleShareCount,
    required bool isFlatSale,
    required bool isInfoCopied,
    required double lowDiscount,
    required double highDiscount,
    required double flatDiscount,
    bool? isInstagramOnly,
    bool? isConciseMode,
    bool? allowMobileDataSync,
    bool? showConditionGradients,
    bool? applySaleToAllStatuses,
  }) {
    _themeMode = themeMode;
    _currencyCode = currencyCode;
    _isMultiSizeModeEnabled = isMultiSize;
    _isTest = isTest;
    _isSalePrice = isSalePrice;
    _isRepairedInfoAvailable = isRepairedInfoAvailable;
    _isHighResCollage = isHighResCollage;
    _isAllShoesShare = isAllShoesShare;
    _sampleShareCount = sampleShareCount;
    _isFlatSale = isFlatSale;
    _lowDiscount = lowDiscount;
    _highDiscount = highDiscount;
    _flatDiscount = flatDiscount;
    _isPriceHidden = isPriceHidden;
    _isInfoCopied = isInfoCopied;
    
    if (isInstagramOnly != null) _isInstagramOnly = isInstagramOnly;
    if (isConciseMode != null) _isConciseMode = isConciseMode;
    if (allowMobileDataSync != null) _allowMobileDataSync = allowMobileDataSync;
    if (showConditionGradients != null) _showConditionGradients = showConditionGradients;
    if (applySaleToAllStatuses != null) _applySaleToAllStatuses = applySaleToAllStatuses;

    notifyListeners();
  }
}
