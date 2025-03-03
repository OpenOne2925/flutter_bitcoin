import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';

class UtilitiesService {
  /// Copies text to clipboard and shows a SnackBar notification.
  static void copyToClipboard({
    required BuildContext context,
    required String text,
    required String messageKey, // Localization key for the SnackBar message
  }) {
    Clipboard.setData(ClipboardData(text: text));

    SnackBarHelper.show(
      context,
      message: AppLocalizations.of(context)!.translate(messageKey),
    );
  }
}
