import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

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

    print('ciao');

    final rootContext = context;

    return await showDialog<bool>(
          context: rootContext,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor:
                  Colors.grey[900], // Dark background for the dialog
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0), // Rounded corners
              ),
              title: const Text(
                'Enter PIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please enter your 6-digit PIN:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
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
                      labelText: 'Enter PIN',
                      hintText: 'Enter PIN',
                    ),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface, // Dynamic text color
                    ),
                  ),
                ],
              ),
              actions: [
                InkwellButton(
                  onTap: () => Navigator.of(context).pop(false),
                  label: 'Cancel',
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                  icon: Icons.cancel_rounded,
                  iconColor: Colors.black,
                ),
                InkwellButton(
                  onTap: () async {
                    try {
                      // TODO: FIX
                      Navigator.of(context).pop(true);

                      await verifyPin(pinController, dialog,
                          isSingleWallet: isSingleWallet);
                    } catch (e) {
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invalid PIN',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  label: 'Confirm',
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  icon: Icons.check_rounded,
                  iconColor: Colors.white,
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<bool?> verifyPin(TextEditingController pinController, String dialog,
      {bool isSingleWallet = false}) async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    String savedMnemonic = walletBox.get('walletMnemonic');

    if (savedPin == pinController.text) {
      if (dialog == 'Reset App') {
        return await resetAppDialog();
      } else if (dialog == 'Your Private Data') {
        privateDataDialog(context, savedMnemonic, isSingleWallet);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
    return null;
  }

  Future<bool> resetAppDialog() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text("Reset App"),
          content: const Text(
              "Are you sure you want to delete all local data and reset the app?"),
          actions: [
            InkwellButton(
              onTap: () => Navigator.pop(context, false),
              label: 'Cancel',
              backgroundColor: Colors.white,
              textColor: Colors.black,
            ),
            InkwellButton(
              onTap: () => Navigator.pop(context, true),
              label: 'Reset',
              backgroundColor: Colors.red,
              textColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  void privateDataDialog(
      BuildContext context, String savedMnemonic, bool isSingleWallet) {
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Your Private Data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Here is your saved mnemonic:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70, // Softer text color
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8.0), // Rounded edges
                  border: Border.all(
                    color: Colors.green, // Border color for emphasis
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SelectableText(
                        savedMnemonic,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70, // Softer text color
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Space between text and icon
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.green, // Highlighted icon color
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: savedMnemonic));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Mnemonic copied to clipboard!'),
                            backgroundColor: Colors.white,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!isSingleWallet) ...[
                const SizedBox(height: 16),
                const Text(
                  'Here is your saved descriptor:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70, // Softer text color
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8.0), // Rounded edges
                    border: Border.all(
                      color: Colors.green, // Border color for emphasis
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          descriptor.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70, // Softer text color
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8), // Space between text and icon
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.green, // Highlighted icon color
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: descriptor.toString()));
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Descriptor copied to clipboard!'),
                              backgroundColor: Colors.white,
                              duration: const Duration(seconds: 2),
                            ),
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
            TextButton(
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
                                iconColor: Colors.greenAccent,
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

                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content:
                          Text('File saved to ${directory.path}/$fileName'),
                    ),
                  );
                } else {
                  // Permission denied
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Storage permission is required to save the file'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Download Descriptor'),
            ),
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop();
              },
              label: 'Close',
              backgroundColor: Colors.green,
              textColor: Colors.white,
              icon: Icons.close,
            ),
          ],
        );
      },
    );
  }
}
