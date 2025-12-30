import 'package:flutter/material.dart';

class AppStatusNotifier extends ChangeNotifier {
  bool _isTest = false; // Default state
  bool _isTestModeEnabled = false; // Default state
  bool _isTrial = true; // Default state
  int _dailyShares = 0; // Default state
  int _dailySharesLimit = 0; // Default state
  int _dailyWrites = 0; // Default state
  int _dailyWritesLimit = 0; // Default state
  int _tier = 0; // Default state
  ThemeMode _themeMode = ThemeMode.light;
  String _currencyCode = 'USD'; // Default currency
  bool _isMultiSizeModeEnabled = false;
  bool _isRepairedInfoAvailable = true;
  bool _isHighResCollage = false;
  bool _isAllShoesShare = false;
  String _purchasedOffer = 'none'; // Default currency
  String _email = 'none'; // Default currency
  int _sampleShareCount = 0; // Default state
  bool _isSalePrice = false;
  bool _isFlatSale = false;
  bool _isPriceHidden = false;

  double _lowDiscount = 7;
  double _highDiscount = 10;
  double _flatDiscount = 0;

  bool get isTrial => _isTrial;
  bool get isTest => _isTest;
  bool get isTestModeEnabled => _isTestModeEnabled;
  int get dailyShares => _dailyShares;
  int get dailySharesLimit => _dailySharesLimit;
  int get dailyWrites => _dailyWrites;
  int get dailyWritesLimit => _dailyWritesLimit;
  int get tier => _tier;
  ThemeMode get themeMode => _themeMode;
  String get currencyCode => _currencyCode;
  bool get isMultiSizeModeEnabled => _isMultiSizeModeEnabled;
  bool get isRepairedInfoAvailable => _isRepairedInfoAvailable;
  bool get isHighResCollage => _isHighResCollage;
  bool get isAllShoesShare => _isAllShoesShare;
  String get purchasedOffer => _purchasedOffer;
  String get email => _email;
  int get sampleShareCount => _sampleShareCount;
  bool get isSalePrice => _isSalePrice;
  bool get isFlatSale => _isFlatSale;
  bool get isPriceHidden => _isPriceHidden;
  double get flatDiscount => _flatDiscount;
  double get lowDiscount => _lowDiscount;
  double get highDiscount => _highDiscount;

  void reset() {
    _isTrial = false;
    _isTest = false;
    _isTestModeEnabled = false;
    _dailyShares = 0;
    _dailySharesLimit = 0;
    _dailyWrites = 0;
    _dailyWritesLimit = 0;
    _tier = 0;
    _themeMode = ThemeMode.light;
    _currencyCode = 'USD';
    _isMultiSizeModeEnabled = false;
    _purchasedOffer = 'none';
    _email = 'none';
  }

  void updateTrial(bool trial) {
    _isTrial = trial;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateTest(bool test) {
    _isTest = test;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateTestModeEnabled(bool testModeEnabled) {
    _isTestModeEnabled = testModeEnabled;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateDailyShares(int dailyShares) {
    _dailyShares = dailyShares;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateDailySharesLimit(int dailySharesLimit) {
    _dailySharesLimit = dailySharesLimit;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateDailyWrites(int dailyWrites) {
    _dailyWrites = dailyWrites;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateDailyWritesLimit(int dailyWritesLimit) {
    _dailyWritesLimit = dailyWritesLimit;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateTier(int tier) {
    _tier = tier;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void updateCurrencyCode(String code) {
    _currencyCode = code;
    notifyListeners();
  }

  void updateMultiSizeMode(bool value) {
    if (_isMultiSizeModeEnabled != value) {
      _isMultiSizeModeEnabled = value;
      notifyListeners();
    }
  }

  void updateRepairedInfoAvailable(bool value) {
    if (_isRepairedInfoAvailable != value) {
      _isRepairedInfoAvailable = value;
      notifyListeners();
    }
  }

  void updateHighResCollage(bool value) {
    if (_isHighResCollage != value) {
      _isHighResCollage = value;
      notifyListeners();
    }
  }

  void updateAllShoesShare(bool value) {
    if (_isAllShoesShare != value) {
      _isAllShoesShare = value;
      notifyListeners();
    }
  }

  void updatePurchasedOffer(String offer) {
    _purchasedOffer = offer;
    notifyListeners();
  }

  void updateEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void updateSampleShareCount(int sampleShareCount) {
    _sampleShareCount = sampleShareCount;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateSalePrice(bool salePrice) {
    _isSalePrice = salePrice;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateFlatSale(bool flatSale) {
    _isFlatSale = flatSale;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updatePriceHidden(bool priceHidden) {
    _isPriceHidden = priceHidden;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateFlatDiscountPercent(double flatDiscount) {
    _flatDiscount = flatDiscount;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateLowDiscountPercent(double lowDiscount) {
    _lowDiscount = lowDiscount;
    notifyListeners(); // Notify all listeners to rebuild
  }

  void updateHighDiscountPercent(double highDiscount) {
    _highDiscount = highDiscount;
    notifyListeners(); // Notify all listeners to rebuild
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
    required double lowDiscount,
    required double highDiscount,
    required double flatDiscount,
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

    // This is the magic line: one call, one rebuild for everything.
    notifyListeners();
  }
}
