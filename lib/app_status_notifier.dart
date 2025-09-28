import 'package:flutter/foundation.dart';

class AppStatusNotifier extends ChangeNotifier {
  bool _isTrial = true; // Default state

  bool get isTrial => _isTrial;

  void updateTrial(bool trial) {
    _isTrial = trial;
    notifyListeners(); // Notify all listeners to rebuild
  }
}