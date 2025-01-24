import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lottie/lottie.dart';

class ImportSharedWallet extends StatefulWidget {
  const ImportSharedWallet({super.key});

  @override
  ImportSharedWalletState createState() => ImportSharedWalletState();
}

class ImportSharedWalletState extends State<ImportSharedWallet> {
  String? publicKey;
  String? _descriptor;
  String? _mnemonic;
  String receivingKey = "";
  String changeKey = "";
  String privKey = "";
  String _status = 'Idle';

  late Box<dynamic> descriptorBox;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptorController = TextEditingController();

  final WalletService _walletService = WalletService();

  List<Map<String, String>> _pubKeysAlias = [];
  String _descriptorName = "";

  bool _isDescriptorValid = true;

  Future<void> _generatePublicKey() async {
    var walletBox = Hive.box('walletBox');

    String savedMnemonic = walletBox.get('walletMnemonic');

    final mnemonic = await Mnemonic.fromString(savedMnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");
    final changeDerivationPath = await DerivationPath.create(path: "m/1");

    final (receivingSecretKey, receivingPublicKey) =
        await _walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      mnemonic,
    );
    final (changeSecretKey, changePublicKey) =
        await _walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      changeDerivationPath,
      mnemonic,
    );

    _mnemonic = savedMnemonic;

    setState(() {
      receivingKey = receivingPublicKey.toString();
      changeKey = changePublicKey.toString();
    });
  }

  void _uploadFile() async {
    // Resetting the initial values
    _descriptorController.clear();
    _pubKeysAlias.clear();

    setState(() {
      _status = 'Idle';
      _isDescriptorValid = true;
    });
    try {
      // Open the file picker for JSON files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'], // Allow only JSON files
      );

      if (result != null && result.files.single.path != null) {
        // Get the file path
        final filePath = result.files.single.path!;

        // Read the file
        final file = File(filePath);
        final fileContents = await file.readAsString();

        // Decode the JSON data
        final Map<String, dynamic> jsonData = jsonDecode(fileContents);

        // Extract the information you need
        final String descriptor =
            jsonData['descriptor'] ?? 'No descriptor found';

        // Ensure the type is List<Map<String, String>>
        final List<Map<String, String>> publicKeysWithAlias =
            (jsonData['publicKeysWithAlias'] as List)
                .map((item) => Map<String, String>.from(item))
                .toList();

        final String descriptorName =
            jsonData['descriptorName'] ?? 'No Descriptor found';

        setState(() {
          _descriptorController.text = descriptor;
          _descriptor = descriptor;
          _pubKeysAlias = publicKeysWithAlias;
          _descriptorName = descriptorName;
        });

        // Use the extracted data
        // print('Descriptor: $descriptor');
        // print('Public Keys With Alias: $publicKeysWithAlias');

        // Optionally, show a success message or update the UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } else {
        // User canceled the file picker
        print('File picking canceled');
      }
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    }
  }

  void _navigateToSharedWallet() async {
    if (_descriptor == null || _descriptor!.isEmpty) {
      setState(() {
        _status = 'Descriptor cannot be empty';
      });
      return;
    }

    bool isValid = await _validateDescriptor(_descriptor!);
    setState(() {
      _status = 'Loading';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (isValid) {
      setState(() {
        _status = 'Success';
      });

      await Future.delayed(const Duration(seconds: 1));

      // _walletService.printInChunks(_descriptor.toString());

      if (_pubKeysAlias.isEmpty) {
        setState(() {
          _pubKeysAlias = _walletService
              .extractPublicKeysWithAliases(_descriptor.toString());
        });
      }

      // print('_pubKeysAlias: $_pubKeysAlias');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedWallet(
            descriptor: _descriptor!,
            mnemonic: _mnemonic!,
            pubKeysAlias: _pubKeysAlias,
            descriptorName: _descriptorName,
          ),
        ),
      );
    } else {
      setState(() {
        _status = 'Cannot navigate: Invalid Descriptor';
      });
    }
  }

  // Asynchronous method to validate the descriptor
  Future<bool> _validateDescriptor(String descriptor) async {
    try {
      bool isValid = await _walletService.isValidDescriptor(descriptor);

      setState(() {
        _isDescriptorValid = isValid;
        _status = isValid ? 'Descriptor is valid' : 'Invalid Descriptor';
      });
      return isValid;
    } catch (e) {
      setState(() {
        _isDescriptorValid = false;
        _status = 'Error validating Descriptor: $e';
      });
      return false;
    }
  }

  Widget _buildStatusBar() {
    String lottieAnimation;
    String statusText;

    if (_status.startsWith('Idle')) {
      lottieAnimation = 'assets/animations/idle.json';
      statusText = 'Idle - Ready to Import';
    } else if (_status.startsWith('Descriptor is valid')) {
      lottieAnimation = 'assets/animations/creating_wallet.json';
      statusText = 'Descriptor is valid - You can proceed';
    } else if (_status.contains('Invalid Descriptor') ||
        _status.contains('Error')) {
      lottieAnimation = 'assets/animations/error_cross.json';
      statusText = 'Invalid Descriptor - Please check your input';
    } else if (_status.contains('Success')) {
      lottieAnimation = 'assets/animations/success.json';
      statusText = 'Navigating to your wallet';
    } else {
      lottieAnimation = 'assets/animations/loading.json';
      statusText = 'Loading...';
    }

    // print(_status);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey<String>(_status), // Use a unique key for each status
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 50,
              width: 50,
              child: Lottie.asset(
                lottieAnimation,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Import Shared Wallet'),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          colors: [Colors.greenAccent, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusBar(),
                  const SizedBox(height: 16),
                  // Form and descriptor field
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _descriptorController,
                      onChanged: (value) {
                        _descriptor = value;
                        _validateDescriptor(value);
                      },
                      decoration: CustomTextFieldStyles.textFieldDecoration(
                        context: context,
                        labelText: 'Descriptor',
                        hintText: 'Wallet descriptor',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a descriptor';
                        }
                        if (!_isDescriptorValid) {
                          return 'Please enter a valid descriptor';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Public Key display with copy functionality
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(150),
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: SelectableText(
                            'Public Key: $receivingKey',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.green),
                          tooltip: 'Copy to Clipboard',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: publicKey ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Public Key copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Generate Public Key Button
                  CustomButton(
                    onPressed: _generatePublicKey,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    icon: Icons.generating_tokens,
                    iconColor: Colors.black,
                    label: 'Generate Public Key',
                  ),

                  const SizedBox(height: 16),

                  // Select File Button
                  CustomButton(
                    onPressed: _uploadFile,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    icon: Icons.file_upload,
                    iconColor: Colors.black,
                    label: 'Select File',
                  ),

                  const SizedBox(height: 16),

                  // Import Shared Wallet Button
                  CustomButton(
                    onPressed: () async {
                      _generatePublicKey();

                      if (_formKey.currentState!.validate()) {
                        await Future.delayed(const Duration(milliseconds: 500));

                        _navigateToSharedWallet();
                      } else {
                        setState(() {
                          _status = 'Please enter a valid wallet!';
                        });
                      }
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.green,
                    label: 'Import Shared Wallet',
                  ),

                  const SizedBox(height: 16),

                  // Display Aliases and Public Keys
                  if (_pubKeysAlias.isNotEmpty) ...[
                    Text(
                      'Aliases and Public Keys:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._pubKeysAlias.map(
                      (keyAlias) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alias: ${keyAlias['alias']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Public Key: ${keyAlias['publicKey']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
