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
  String pubKey = "";
  String privKey = "";
  String _status = 'Idle';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptorController = TextEditingController();

  final WalletService _walletService = WalletService();

  bool _isDescriptorValid = true;

  Future<void> _generatePublicKey() async {
    var walletBox = Hive.box('walletBox');

    String savedMnemonic = walletBox.get('walletMnemonic');

    _mnemonic = savedMnemonic;

    var secretKey =
        await _walletService.getSecretKeyfromMnemonic(savedMnemonic);

    var futurePubKey = await secretKey.asPublic();
    pubKey = futurePubKey.toString();

    setState(() {
      publicKey = pubKey;
    });
  }

  // Future<void> _generateWallet() async {
  //   var walletBox = Hive.box('walletBox');

  //   String savedMnemonic = walletBox.get('walletMnemonic');

  //   _mnemonic = savedMnemonic;

  //   var secretKey =
  //       await _walletService.getSecretKeyfromMnemonic(savedMnemonic);

  //   var futurePubKey = await secretKey.asPublic();
  //   pubKey = futurePubKey.toString();

  //   privKey = secretKey.asString();

  //   final regExp = RegExp(r'\[[^\]]+\]tpub[0-9A-Za-z]+/\*');
  //   // Find all matches of the content inside the square brackets and the tpub keys
  //   final matches = regExp.allMatches(_descriptor!);

  //   // print(_descriptor);

  //   int i = 0;

  //   for (var match in matches) {
  //     i++;
  //     // print('Matched Content: ${match.group(0)}');
  //     if (pubKey != match.group(0)) {
  //       pubKey = match.group(0)!;
  //       // print(pubKey);

  //       if (i == 1) {
  //         _descriptor = "wsh(multi(2,$privKey,$pubKey))";
  //       } else {
  //         _descriptor = "wsh(multi(2,$pubKey,$privKey))";
  //       }

  //       break;
  //     }
  //   }

  //   // print(_descriptor);

  //   await _walletService.createSharedWallet(
  //     _descriptor!,
  //     Network.Testnet,
  //     null,
  //   );

  //   setState(() {
  //     _status = 'Wallet is being generated...';
  //   });
  // }

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

  Future<void> _generateWallet() async {
    var walletBox = Hive.box('walletBox');

    String savedMnemonic = walletBox.get('walletMnemonic');

    _mnemonic = savedMnemonic;

    var secretKey =
        await _walletService.getSecretKeyfromMnemonic(savedMnemonic);

    var futurePubKey = await secretKey.asPublic();
    pubKey = futurePubKey.toString();

    String pubKey1 = pubKey.replaceAll("*", "0/*");
    String pubKey2 = pubKey.replaceAll("*", "1/*");

    pubKey = pubKey.replaceAll("/*", "");

    privKey = secretKey.asString();

    String privKey1 = privKey.replaceAll("*", "0/*");
    String privKey2 = privKey.replaceAll("*", "1/*");

    final regExp = RegExp(r'\[[^\]]+\]tpub[0-9A-Za-z]+');
    // Find all matches of the content inside the square brackets and the tpub keys
    final matches = regExp.allMatches(_descriptor!);

    // Define a regular expression to capture the numbers inside "after(...)"
    final regExpAmount = RegExp(r'older\((\d+)\)');

    // Find all matches in the descriptor string
    final matchesAmount = regExpAmount.allMatches(_descriptor!);

    // Extract the amounts
    String amount1 = matchesAmount.elementAt(0).group(1) ?? '';
    String amount2 = matchesAmount.elementAt(1).group(1) ?? '';

    // print('Descriptor Matched: $_descriptor');

    int i = 0;

    for (var match in matches) {
      i++;
      // // print('Public Key: $pubKey');
      // print('Matched Content: ${match.group(0)}');
      if (pubKey != match.group(0)) {
        pubKey = match.group(0)!;
        // print('Ora' + pubKey);
        pubKey1 = "$pubKey/0/*";
        pubKey2 = "$pubKey/1/*";

        // print(pubKey1);
        // print(pubKey2);

        if (i == 1) {
          _descriptor =
              "wsh(or_d(multi(2,$privKey1,$pubKey1),or_i(and_v(v:older($amount1),pk($pubKey2)),and_v(v:older($amount2),pk($privKey2)))))";

          // _descriptor = "wsh(multi(2,$privKey,$pubKey))";
        } else {
          _descriptor =
              "wsh(or_d(multi(2,$pubKey1,$privKey1),or_i(and_v(v:older($amount1),pk($privKey2)),and_v(v:older($amount2),pk($pubKey2)))))";

          // _descriptor = "wsh(multi(2,$pubKey,$privKey))";
        }

        break;
      }
    }

    // print('Final Descriptor: $_descriptor');

    setState(() {
      _status = 'Wallet is being generated...';
    });
  }

  Future<bool> _isValidDescriptor(String descriptorStr) async {
    // Add your descriptor validation logic here
    // For example, check if it meets some specific pattern or length

    bool isValid = true;

    Network network = Network.Testnet;

    try {
      // Try creating the descriptor
      final descriptor = await Descriptor.create(
        descriptor: descriptorStr,
        network: network,
      );

      // Try creating the wallet with the descriptor
      await Wallet.create(
        descriptor: descriptor,
        network: network,
        databaseConfig: const DatabaseConfig.memory(),
      );
    } catch (e) {
      // If any error occurs during creation, set isValid to false
      isValid = false;
      // print('Error creating wallet with descriptor: $e');
      throw ('Error creating wallet with descriptor: $e');
    }

    return isValid;
  }

  // Asynchronous method to validate the descriptor
  Future<void> _validateDescriptor(String descriptor) async {
    bool isValid = await _isValidDescriptor(descriptor);
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
                      .withOpacity(0.3), // Border color
                ),
                borderRadius: BorderRadius.circular(8.0), // Rounded corners
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Public Key: $publicKey',
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
                // Validate the form before proceeding
                if (_formKey.currentState!.validate()) {
                  _generateWallet();
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (!mounted) return;

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
