import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:hive/hive.dart';

class CreateSharedWallet extends StatefulWidget {
  const CreateSharedWallet({super.key});

  @override
  CreateSharedWalletState createState() => CreateSharedWalletState();
}

class CreateSharedWalletState extends State<CreateSharedWallet> {
  String? publicKey;

  String? _pubKey2;

  String? receiving1Key;
  String? change1Key;
  String? privateKey;

  bool isLoading = false; // For loading state during wallet creation
  bool walletCreated = false; // To avoid multiple wallet creations

  String? _mnemonic;

  int amount1 = 0;
  int amount2 = 0;

  final _status = 'Idle';

  final TextEditingController _pubKeyController = TextEditingController();
  final TextEditingController _pubKeyController2 = TextEditingController();

  // Controllers for the text fields
  // final TextEditingController _field1Controller = TextEditingController();
  // final TextEditingController _field2Controller = TextEditingController();

  final TextEditingController _amount1Controller = TextEditingController();
  final TextEditingController _amount2Controller = TextEditingController();

  // List<Map<String, dynamic>> _dataList = []; // Stores the inputted data

  final WalletService _walletService = WalletService();

  late Box<dynamic> descriptorBox;

  final secureStorage = FlutterSecureStorage();
  // final WalletService walletService = WalletService();

  Future<void> openBoxAndCheckWallet() async {
    // Open the encrypted box using Hive
    descriptorBox = Hive.box('descriptorBox');

    // print('Retrieving descriptor with key: wallet_${_mnemonic}');

    // After the box is opened, proceed with checking for the existing wallet
    var existingDescriptor = descriptorBox.get('wallet_$_mnemonic');

    print('Retrieved descriptor: $existingDescriptor');

    if (existingDescriptor != null) {
      // print('Wallet with this mnemonic already exists.');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Warning: Shared wallet already exists. Navigating to your wallet'),
          backgroundColor: Colors.orange, // Warning color
          duration:
              Duration(seconds: 3), // How long the SnackBar stays on the screen
        ),
      );

      walletCreated = true; // Set wallet created to true
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedWallet(
            descriptor: existingDescriptor,
            mnemonic: _mnemonic!,
          ),
        ),
      );
    } else {
      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/shared_wallet_info',
        arguments: {
          'receiving1Key': receiving1Key,
          'change1Key': change1Key,
          'privKey': privateKey,
          'pubKey2': _pubKey2,
          'amount1': amount1,
          'amount2': amount2,
          'mnemonic': _mnemonic,
        },
      );
    }
  }

  Future<void> _generatePublicKey() async {
    var walletBox = Hive.box('walletBox');

    String savedMnemonic = walletBox.get('walletMnemonic');

    final mnemonic = await Mnemonic.fromString(savedMnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) =
        await _walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      mnemonic,
    );

    // print('Receiving: $receivingPublicKey');

    // Regular expression to match the final '/0' before '/*'
    final regex = RegExp(r'\/0(?=\/\*)');

    // Replace the final '/0' with '/1'
    final changePublicKey =
        receivingPublicKey.toString().replaceFirst(regex, '/1');

    // print('Change: $changePublicKey');

    setState(() {
      receiving1Key = receivingPublicKey.toString();
      _pubKeyController.text = receivingPublicKey.toString();
      change1Key = changePublicKey.toString();
      privateKey = receivingSecretKey.toString();
      _mnemonic = savedMnemonic;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Create Shared Wallet'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Display the status of wallet creation
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors
                      .orange[100], // Light orange background for emphasis
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800], // Darker orange text
                  ),
                  textAlign: TextAlign.center, // Center the text
                ),
              ),
              const SizedBox(height: 16),
              // Display the public key in a styled box
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
                        Clipboard.setData(ClipboardData(text: publicKey!));
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
              TextFormField(
                controller: _pubKeyController,
                onChanged: (value) {
                  receiving1Key = value;
                },
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter First Public Key',
                  hintText: 'Enter First Public Key',
                ),
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),

              const SizedBox(height: 16),
              // TextField for amount1
              TextFormField(
                controller: _amount1Controller,
                onChanged: (value) {
                  amount1 = int.parse(value);
                },
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter First Amount',
                  hintText: 'Enter First Amount',
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                onPressed: _generatePublicKey,
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.orange, // Bitcoin orange color for text
                icon: Icons.generating_tokens,
                iconColor: Colors.black,
                label: 'Generate Public Key',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pubKeyController2,
                onChanged: (value) {
                  _pubKey2 = value;
                },
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter Second Public Key',
                  hintText: 'Enter Second Public Key',
                ),
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
              const SizedBox(height: 16),
              // TextField for amount1
              TextFormField(
                controller: _amount2Controller,
                onChanged: (value) {
                  amount2 = int.parse(value);
                },
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter Second Amount',
                  hintText: 'Enter Second Amount',
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                onPressed: () {
                  openBoxAndCheckWallet();
                },
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.black, // Black text
                icon: Icons.account_balance_wallet,
                iconColor: Colors.orange,
                label: 'Create Shared Wallet',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
