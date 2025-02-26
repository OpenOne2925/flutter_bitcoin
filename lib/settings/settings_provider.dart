import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Light & Dark Theme Definitions
final ThemeData lightTheme = ThemeData(
  primarySwatch: Colors.amber,
  brightness: Brightness.light,
  scaffoldBackgroundColor: Colors.white,
);

final ThemeData darkTheme = ThemeData(
  primarySwatch: Colors.cyan,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
);

class SettingsProvider with ChangeNotifier {
  String _currency = 'USD'; // Default currency
  String _languageCode = 'en';
  bool _isDarkMode = false;

  late SharedPreferences _prefs;
  late ThemeData _themeData;

  String get currency => _currency;
  String get languageCode => _languageCode;
  ThemeData get themeData => _themeData;
  bool get isDarkMode => _isDarkMode;

  SettingsProvider() {
    loadSettings(); // Initialize SharedPreferences before use
  }

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _currency = _prefs.getString('selected_currency') ?? 'USD';
    _languageCode = _prefs.getString('languageCode') ?? 'en';

    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _themeData = _isDarkMode ? darkTheme : lightTheme;

    notifyListeners(); // Ensure UI updates after loading
  }

  Future<void> setCurrency(String newCurrency) async {
    _currency = newCurrency;
    notifyListeners(); // Update UI immediately

    await _prefs.setString('selected_currency', newCurrency);
  }

  Future<void> setLanguage(String languageCode) async {
    _languageCode = languageCode;

    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('languageCode', languageCode);
    notifyListeners();
  }

  // Toggle Theme & Save Choice
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    _themeData = _isDarkMode ? darkTheme : lightTheme;
    notifyListeners();

    // Save preference
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  void resetSettings() {
    _currency = 'USD';
    _languageCode = 'en';
    _isDarkMode = false;
    _themeData = lightTheme;

    _prefs.setBool('isDarkMode', false);
    _prefs.setString('selected_currency', 'USD');
    _prefs.setString('languageCode', 'en');

    notifyListeners();
  }
}
