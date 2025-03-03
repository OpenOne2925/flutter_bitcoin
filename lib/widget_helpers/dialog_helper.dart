import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class DialogHelper {
  /// Generic dialog helper that can return any type (`bool`, `String`, `int`, etc.).
  static Future<T?> buildCustomDialog<T>({
    required BuildContext context,
    required String titleKey, // Localization key for the title
    Map<String, String>? titleParams, // Dynamic
    required Widget content, // Dialog's main content
    List<Widget>? actions, // Optional actions
    bool showCloseButton = true, // Default: Show the close button
    Axis actionsLayout =
        Axis.horizontal, // Default: actions in row or vertical for column
  }) async {
    final rootContext = context;

    // Get the translated string and replace placeholders dynamically
    String localizedTitle =
        AppLocalizations.of(rootContext)!.translate(titleKey);
    if (titleParams != null) {
      titleParams.forEach((key, value) {
        localizedTitle = localizedTitle.replaceAll('{$key}', value);
      });
    }

    return showDialog<T>(
      context: rootContext,
      barrierDismissible: false, // Prevent accidental closing
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.dialog(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              titlePadding: EdgeInsets.zero, // Remove default title padding
              title: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 24.0,
                    ),
                    child: Text(
                      localizedTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                  ),

                  // Conditionally show the close button in the top-right corner
                  if (showCloseButton)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: Icon(Icons.close, color: AppColors.text(context)),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                      ),
                    ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(), // Makes scrolling smooth
                  child: content,
                ),
              ),
              actionsPadding:
                  EdgeInsets.only(bottom: 10), // Adjust bottom padding
              actionsAlignment: MainAxisAlignment.center, // Center actions
              actions: actions != null && actions.isNotEmpty
                  ? [
                      if (actionsLayout == Axis.horizontal)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: actions,
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: actions,
                        ),
                    ]
                  : null, // Hide actions row if not provided
            );
          },
        );
      },
    );
  }

  static Future<T?> buildCustomStatefulDialog<T>({
    required BuildContext context,
    required String titleKey, // Localization key for the title
    required Widget Function(StateSetter setDialogState)
        contentBuilder, // Pass a builder
    List<Widget> Function(StateSetter setDialogState)?
        actionsBuilder, // Actions builder
    bool showCloseButton = true, // Default: Show the close button
  }) async {
    final rootContext = context;

    return showDialog<T>(
      context: rootContext,
      barrierDismissible: false, // Prevent accidental closing
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.dialog(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              titlePadding: EdgeInsets.zero, // Remove default title padding
              title: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                      horizontal: 24.0,
                    ),
                    child: Text(
                      AppLocalizations.of(rootContext)!.translate(titleKey),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                  ),

                  // Conditionally show the close button in the top-right corner
                  if (showCloseButton)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: Icon(Icons.close, color: AppColors.text(context)),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                      ),
                    ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: contentBuilder(setDialogState), // Pass StateSetter
                ),
              ),
              actionsPadding:
                  EdgeInsets.only(bottom: 10), // Adjust bottom padding
              actionsAlignment: MainAxisAlignment.center, // Center actions
              actions: actionsBuilder != null
                  ? [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: actionsBuilder(
                            setDialogState), // Pass StateSetter to actions
                      ),
                    ]
                  : null, // Hide actions row if not provided
            );
          },
        );
      },
    );
  }

  /// ✅ **Updated method to show and control a loading dialog**
  static Future<void> showLoadingDialog(BuildContext context,
      {String? messageKey}) async {
    final rootContext = context;

    showDialog(
      context: rootContext,
      barrierDismissible: false, // Prevent closing
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(rootContext)!
                    .translate(messageKey ?? 'processing'),
                style: TextStyle(
                  color: AppColors.text(context),
                ),
              ),
            ],
          ),
        );
      },
    );

    return; // Can be awaited to ensure the function completes
  }

  /// Shows an error dialog with a custom message.
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String messageKey, // Localization key for the message
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error,
                color: AppColors.error(context),
              ),
              SizedBox(width: 8),
              Text(
                'Error',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.translate(messageKey),
            style: TextStyle(color: AppColors.text(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// ✅ **Method to close any open dialog (including loading dialog)**
  static void closeDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
