import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  String _currency = 'USD';

  String get currency => _currency;

  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    notifyListeners(); // Notify listeners to update the UI
  }
}
