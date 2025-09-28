import 'package:flutter/foundation.dart';

class AppStatusNotifier extends ChangeNotifier {
  bool _isTrial = true; // Default state

  bool get isTrial => _isTrial;

  void updateStatus(bool newStatus) {
    _isTrial = newStatus;
    notifyListeners(); // Notify all listeners to rebuild
  }
}