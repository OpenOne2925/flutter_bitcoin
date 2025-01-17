import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:hive/hive.dart';

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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptorController = TextEditingController();

  final WalletService _walletService = WalletService();

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

  void _navigateToSharedWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SharedWallet(
          descriptor: _descriptor!,
          mnemonic: _mnemonic!,
        ),
      ),
    );
  }

  // Asynchronous method to validate the descriptor
  Future<void> _validateDescriptor(String descriptor) async {
    bool isValid = await _walletService.isValidDescriptor(descriptor);
    setState(() {
      _isDescriptorValid = isValid;
    });
    // Trigger form validation to update the UI
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Import Shared Wallet'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display the status of wallet creation
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),

            // Form and descriptor field
            Form(
              key: _formKey, // Assign the form key
              child: TextFormField(
                controller: _descriptorController,
                onChanged: (value) {
                  _descriptor = value;
                  _validateDescriptor(value);
                },
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter Descriptor',
                  hintText: 'Enter your wallet descriptor here',
                ),
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a descriptor'; // Error message for empty input
                  }
                  if (!_isDescriptorValid) {
                    return 'Please enter a valid descriptor'; // Error message for invalid descriptor
                  }
                  return null; // Return null if input is valid
                },
              ),
            ),

            const SizedBox(height: 16),

            // Public Key display with copy functionality
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface, // Background color adapts to theme
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(), // Border color
                ),
                borderRadius: BorderRadius.circular(8.0), // Rounded corners
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SelectableText(
                      'Public Key: $receivingKey',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface, // Dynamic text color
                        fontWeight: FontWeight
                            .w500, // Medium font weight for better readability
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.orange),
                    tooltip: 'Copy to Clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: publicKey ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Public Key copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Button to generate the public key
            CustomButton(
              onPressed: _generatePublicKey,
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.orange, // Bitcoin orange color for text
              icon: Icons.generating_tokens, // Icon you want to use
              iconColor: Colors.black, // Color for the icon
              label: 'Generate Public Key',
            ),

            const SizedBox(height: 16),

            // Import Shared Wallet button with form validation
            CustomButton(
              onPressed: () async {
                _generatePublicKey();
                // Validate the form before proceeding
                if (_formKey.currentState!.validate()) {
                  await Future.delayed(const Duration(milliseconds: 500));

                  _navigateToSharedWallet();
                } else {
                  // Show error if the form is invalid
                  setState(() {
                    _status = 'Please enter a valid wallet!';
                  });
                }
              },
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.black, // Black text
              icon: Icons.account_balance_wallet, // Icon you want to use
              iconColor: Colors.orange, // Color for the icon
              label: 'Import Shared Wallet',
            ),
          ],
        ),
      ),
    );
  }
}
