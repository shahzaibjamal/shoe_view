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
  String _purchasedOffer = 'none'; // Default currency
  String _email = 'none'; // Default currency
  int _sampleShareCount = 0; // Default state
  bool _isSalePrice = false;

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
  String get purchasedOffer => _purchasedOffer;
  String get email => _email;
  int get sampleShareCount => _sampleShareCount;
  bool get isSalePrice => _isSalePrice;

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
}
