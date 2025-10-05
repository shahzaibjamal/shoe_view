import 'package:flutter/foundation.dart';

class AppStatusNotifier extends ChangeNotifier {
  bool _isTrial = true; // Default state
  int _dailyShares = 0; // Default state
  int _dailyWrites = 0; // Default state
  int _tier = 0; // Default state

  bool get isTrial => _isTrial;
  int get dailyShares => _dailyShares;
  int get dailyWrites => _dailyWrites;
  int get tier => _tier;

  void updateTrial(bool trial) {
    _isTrial = trial;
    notifyListeners(); // Notify all listeners to rebuild
  }
  void updateDailyShares(int dailyShares) {
    _dailyShares = dailyShares;
    notifyListeners(); // Notify all listeners to rebuild
  }
  void updateDailyWrites(int dailyWrites) {
    _dailyWrites = dailyWrites;
    notifyListeners(); // Notify all listeners to rebuild
  }
  void updateTier(int tier) {
    _tier = tier;
    notifyListeners(); // Notify all listeners to rebuild
  }
}