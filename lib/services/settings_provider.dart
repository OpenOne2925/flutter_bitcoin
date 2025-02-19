import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  String _currency = 'USD'; // Default currency
  late SharedPreferences _prefs;

  String get currency => _currency;

  SettingsProvider() {
    _initPrefs(); // Initialize SharedPreferences before use
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _currency = _prefs.getString('selected_currency') ?? 'USD';
    notifyListeners(); // Ensure UI updates after loading
  }

  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    notifyListeners(); // Update UI immediately

    await _prefs.setString('selected_currency', newCurrency);
  }

  void resetSettings() {
    _currency = 'USD'; // Reset to default
    notifyListeners();
  }
}
