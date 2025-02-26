import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/snackbar_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletReceiveHelpers {
  final BuildContext context;

  WalletReceiveHelpers({required this.context});

  // Method to display the QR code in a dialog
  void showQRCodeDialog(String address) {
    final rootContext = context;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.gradient(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Text(
            AppLocalizations.of(rootContext)!.translate('receive_bitcoin'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.cardTitle(context),
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // QR Code Container
                Container(
                  width: 200, // Explicit width
                  height: 200, // Explicit height
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.background(context),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: address,
                    version: QrVersions.auto,
                    size: 180.0, // Ensure QR code is smaller than the container
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Display the actual address below the QR code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SelectableText(
                        address,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: AppColors.cardTitle(context),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: address));
                        SnackBarHelper.show(
                          rootContext,
                          message: AppLocalizations.of(rootContext)!
                              .translate('address_clipboard'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop();
              },
              label: AppLocalizations.of(rootContext)!.translate('cancel'),
              backgroundColor: Colors.white,
              textColor: Colors.black,
            ),
          ],
        );
      },
    );
  }
}
