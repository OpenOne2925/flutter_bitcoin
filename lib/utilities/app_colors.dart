import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/wallet_service.dart';

class AppColors {
  // ✅ Define Primary Colors Based on Testnet/Mainnet
  static Color get primaryColor => isTestnet ? Colors.green : Colors.orange;
  static Color get lightPrimaryColor =>
      isTestnet ? Colors.green : Colors.orangeAccent[400]!;
  static Color get darkPrimaryColor =>
      isTestnet ? Colors.green[600]! : Colors.deepOrange[700]!;

  static Color get lightSecondaryColor =>
      isTestnet ? Colors.green[300]! : Colors.orange[400]!;
  static Color get darkSecondaryColor =>
      isTestnet ? Colors.green[800]! : Colors.deepOrange[900]!;

  static Color get unavailableColor => Colors.grey;
  static Color get unconfirmedColor => Colors.yellow;

  static Color primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryColor
        : primaryColor;
  }

  static Color accent(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryColor
        : lightPrimaryColor;
  }

  static Color error(BuildContext context) {
    return Colors.red;
  }

  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryColor
        : lightPrimaryColor;
  }

  static Color cardTitle(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? lightPrimaryColor
        : darkPrimaryColor;
  }

  static Color icon(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? lightSecondaryColor
        : darkSecondaryColor;
  }

  static Color dialog(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black87
        : Colors.white;
  }

  static Color container(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[850]!
        : Colors.grey[300]!;
  }

  static Color text(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  static Color gradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black87
        : Colors.white;
  }
}
