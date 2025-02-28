import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/snackbar_helper.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletSecurityHelpers {
  final BuildContext context;
  final String? descriptor;
  final String? descriptorName;
  final List<Map<String, String>>? pubKeysAlias;

  WalletSecurityHelpers({
    required this.context,
    this.descriptor,
    this.descriptorName,
    this.pubKeysAlias,
  });

  // Function to show a PIN input dialog
  Future<bool> showPinDialog(String dialog,
      {bool isSingleWallet = false}) async {
    TextEditingController pinController =
        TextEditingController(); // Controller for the PIN input

    final rootContext = context;

    return await showDialog<bool>(
          context: rootContext,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: AppColors.dialog(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0), // Rounded corners
              ),
              title: Text(
                AppLocalizations.of(rootContext)!.translate('enter_pin'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cardTitle(context),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(rootContext)!
                        .translate('enter_6_digits_pin'),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text(rootContext),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller:
                        pinController, // Controller to capture PIN input
                    keyboardType: TextInputType.number, // Numeric input
                    obscureText: true, // Obscure input for security
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('enter_pin'),
                      hintText: AppLocalizations.of(rootContext)!
                          .translate('enter_pin'),
                    ),
                    style: TextStyle(color: AppColors.text(context)),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkwellButton(
                      onTap: () => Navigator.of(context).pop(false),
                      // label:
                      //     AppLocalizations.of(rootContext)!.translate('cancel'),
                      backgroundColor: AppColors.text(context),
                      textColor: AppColors.gradient(context),
                      icon: Icons.cancel_rounded,
                      iconColor: AppColors.gradient(context),
                    ),
                    InkwellButton(
                      onTap: () async {
                        try {
                          Navigator.of(context).pop(true);

                          await verifyPin(
                            pinController,
                            isSingleWallet: isSingleWallet,
                          );
                        } catch (e) {
                          SnackBarHelper.show(
                            rootContext,
                            message: AppLocalizations.of(rootContext)!
                                .translate('pin_incorrect'),
                            color: AppColors.error(rootContext),
                          );
                        }
                      },
                      // label: AppLocalizations.of(rootContext)!
                      //     .translate('confirm'),
                      backgroundColor: AppColors.background(context),
                      textColor: AppColors.text(context),
                      icon: Icons.check_rounded,
                      iconColor: AppColors.gradient(context),
                    ),
                  ],
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool?> verifyPin(
    TextEditingController pinController, {
    bool isSingleWallet = false,
  }) async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    String savedMnemonic = walletBox.get('walletMnemonic');

    if (savedPin == pinController.text) {
      privateDataDialog(context, savedMnemonic, isSingleWallet);
    } else {
      SnackBarHelper.show(
        context,
        message: AppLocalizations.of(context)!.translate('pin_incorrect'),
        color: AppColors.error(context),
      );
    }
    return null;
  }

  void privateDataDialog(
    BuildContext context,
    String savedMnemonic,
    bool isSingleWallet,
  ) {
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Text(
            AppLocalizations.of(rootContext)!.translate('private_data'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.cardTitle(context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(rootContext)!.translate('saved_mnemonic'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.cardTitle(context),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.container(context),
                  borderRadius: BorderRadius.circular(8.0), // Rounded edges
                  border: Border.all(
                    color: AppColors.background(context),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SelectableText(
                        savedMnemonic,
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
                        color: AppColors.icon(context),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: savedMnemonic));
                        SnackBarHelper.show(
                          rootContext,
                          message: AppLocalizations.of(rootContext)!
                              .translate('mnemonic_clipboard'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!isSingleWallet) ...[
                const SizedBox(height: 16),
                Text(
                  "${AppLocalizations.of(rootContext)!.translate('saved_descriptor')}: ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.cardTitle(context),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.container(context),
                    borderRadius: BorderRadius.circular(8.0), // Rounded edges
                    border: Border.all(
                      color: AppColors.background(context),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          descriptor.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.text(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          color: AppColors.icon(context),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: descriptor.toString()));
                          SnackBarHelper.show(
                            rootContext,
                            message: AppLocalizations.of(rootContext)!
                                .translate('descriptor_clipboard'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
          actions: [
            Visibility(
              visible: !isSingleWallet,
              child: TextButton(
                onPressed: () async {
                  // Serialize data to JSON
                  final data = jsonEncode({
                    'descriptor': descriptor,
                    'publicKeysWithAlias': pubKeysAlias,
                    'descriptorName': descriptorName,
                  });

                  // Request storage permission (required for Android 11 and below)
                  if (await Permission.storage.request().isGranted) {
                    // Get default Downloads directory
                    final directory = Directory('/storage/emulated/0/Download');
                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }

                    String fileName = '$descriptorName.json';
                    String filePath = '${directory.path}/$fileName';
                    File file = File(filePath);

                    // Check if the file already exists
                    if (await file.exists()) {
                      final shouldProceed = await showDialog<bool>(
                          context: rootContext,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors
                                  .grey[900], // Dark background for the dialog
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    20.0), // Rounded corners
                              ),
                              title: const Text('File Already Exists'),
                              content: const Text(
                                  ' A file with the same name already exists. Do you want to save it anyway?'),
                              actions: [
                                InkwellButton(
                                  onTap: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  label: 'Cancel',
                                  backgroundColor: Colors.white,
                                  textColor: Colors.black,
                                  icon: Icons.cancel_rounded,
                                  iconColor: Colors.redAccent,
                                ),
                                InkwellButton(
                                  onTap: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  label: 'Yes',
                                  backgroundColor: Colors.white,
                                  textColor: Colors.black,
                                  icon: Icons.check_circle,
                                  iconColor: AppColors.accent(context),
                                ),
                              ],
                            );
                          });

                      // If the user chooses not to proceed, exit
                      if (!shouldProceed!) {
                        return;
                      }

                      // Increment the file name index until a unique file name is found
                      int index = 1;
                      while (await file.exists()) {
                        fileName = '$descriptorName($index).json';
                        filePath = '${directory.path}/$fileName';
                        file = File(filePath);
                        index++;
                      }
                    }
                    // Write JSON data to the file
                    await file.writeAsString(data);

                    SnackBarHelper.show(
                      rootContext,
                      message:
                          '${AppLocalizations.of(rootContext)!.translate('file_saved')} ${directory.path}/$fileName',
                    );
                  } else {
                    SnackBarHelper.show(rootContext,
                        message: AppLocalizations.of(rootContext)!
                            .translate('storage_permission_needed'),
                        color: AppColors.error(context));
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.cardTitle(context),
                ),
                child: Text(AppLocalizations.of(rootContext)!
                    .translate('download_descriptor')),
              ),
            ),
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop();
              },
              label: 'Close',
              backgroundColor: AppColors.background(context),
              textColor: AppColors.text(context),
              icon: Icons.cancel_rounded,
              iconColor: AppColors.gradient(context),
            ),
          ],
        );
      },
    );
  }
}
