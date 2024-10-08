import 'dart:convert';

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

  String? _pubKey;
  String? _pubKey2;
  String? _privKey;

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

  bool boxOpened = false; // to ensure the box is opened only once

  late Box<dynamic> descriptorBox;

  final secureStorage = FlutterSecureStorage();
  final WalletService walletService = WalletService();

  Future<void> openBoxAndCheckWallet() async {
    // Open the encrypted box using Hive

    final encryptionKey = await walletService.getEncryptionKey();

    descriptorBox = await Hive.openBox(
      'wallet_descriptors',
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    boxOpened = true; // Ensure this is only opened once

    // print('Retrieving descriptor with key: wallet_${_mnemonic}');

    // After the box is opened, proceed with checking for the existing wallet
    var existingDescriptor = descriptorBox.get('wallet_$_mnemonic');

    // print('Retrieved descriptor: $existingDescriptor');

    if (existingDescriptor != null) {
      // print('Wallet with this mnemonic already exists.');
      // descriptorString1 = existingDescriptor;

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
      // print('Public Key 1: $_pubKey');
      // print('Public Key 2: $_pubKey2');
      // print('Private Key: $_privKey');
      // print('Amount 1: $amount1');
      // print('Amount 2: $amount2');
      // print('Mnemonic: $_mnemonic');

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/shared_wallet_info',
        arguments: {
          'pubKey1': _pubKey,
          'pubKey2': _pubKey2,
          'privKey': _privKey,
          'amount1': amount1,
          'amount2': amount2,
          'mnemonic': _mnemonic,
        },
      );
    }
  }

  // String createDescriptor(
  //   List<dynamic> publicKeys,
  //   int threshold,
  //   List<dynamic> amounts,
  // ) {
  //   // Start building the descriptor
  //   String descriptor = "wsh(or_d(multi($threshold";

  //   for (int i = 0; i < threshold; i++) {
  //     String pubKey = publicKeys[i];
  //     descriptor += ",$pubKey";
  //   }

  //   descriptor += "),or_i(";

  //   for (int i = threshold; i < publicKeys.length; i++) {
  //     String pubKey = publicKeys[i];
  //     int olderValue = amounts[i];

  //     descriptor += "and_v(v:pkh($pubKey),older($olderValue))";
  //     if (i != publicKeys.length - 1) {}
  //   }

  //   // Close the descriptor format
  //   descriptor += "))";

  //   return descriptor;
  // }

  // Future<void> createMultisigWallet(List<Map<String, dynamic>> dataList) async {
  //   setState(() {
  //     isLoading = true;
  //   });
  //   // String pubKey3, String pubKey4, to add in the second step

  //   try {
  //     // If needed this descriptor would just use the basic multisig setup for the change outputs, without any recovery clauses.
  //     final descriptor = "wsh(multi(2,$pubKey1,$pubKey2))";

  //     // List<dynamic> publicKeys =
  //     //     dataList.map((data) => data['user'] ?? '').toList();

  //     // int threshold = publicKeys.length;

  //     // List<dynamic> amounts =
  //     dataList.map((data) => data['amount'] ?? '').toList();

  //     final descriptor1 = "wsh(multi(2,$pubKey2,$privKey1))";
  //     // final descriptor = createDescriptor(publicKeys, threshold, amounts);

  //     // print(descriptor);

  //     // Create the wallet using the descriptor
  //     descriptorWallet = await Descriptor.create(
  //       descriptor: descriptor,
  //       network: Network.Testnet, // Use Network.Mainnet for mainnet
  //     );
  //     descriptorWallet1 = await Descriptor.create(
  //       descriptor: descriptor1,
  //       network: Network.Testnet, // Use Network.Mainnet for mainnet
  //     );

  //     descriptorString = await descriptorWallet!.asString();
  //     descriptorString1 = await descriptorWallet1!.asString();

  //     // descriptorString = await descriptorWallet!.asStringPrivate();

  //     // print(descriptorString);

  //     // Create wallets from the descriptors
  //     _wallet = await Wallet.create(
  //       descriptor: descriptorWallet1!,
  //       changeDescriptor: descriptorWallet1,
  //       network: Network.Testnet,
  //       databaseConfig: const DatabaseConfig.memory(),
  //     );

  //     print("Shared Wallet Created!");
  //   } catch (e) {
  //     print("Error creating wallet: $e");
  //   } finally {
  //     setState(() {
  //       isLoading = false;
  //       walletCreated = true; // Ensure wallet is only created once
  //     });
  //   }
  // }

  Future<void> _generatePublicKey() async {
    var walletBox = Hive.box('walletBox');
    String savedMnemonic = walletBox.get('walletMnemonic');

    var secretKey =
        await _walletService.getSecretKeyfromMnemonic(savedMnemonic);

    var futurePubKey = await secretKey.asPublic();
    var pubKey = futurePubKey.toString();

    var privKey = secretKey.asString();

    // print(pubKey);
    // print(privKey);

    setState(() {
      publicKey = pubKey;
      _pubKeyController.text = pubKey;
      _pubKey = pubKey;
      _privKey = privKey;
      _mnemonic = savedMnemonic;
    });
  }

  // // Function to show the dialog and get input from the user
  // Future<void> _showInputDialog() async {
  //   await showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Enter Data'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(
  //               controller: _field1Controller,
  //               decoration: const InputDecoration(labelText: 'User'),
  //             ),
  //             TextField(
  //               controller: _field2Controller,
  //               decoration: const InputDecoration(labelText: 'Amount'),
  //               keyboardType: TextInputType.number,
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop(); // Close dialog without action
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               // Save the data to the list and close the dialog
  //               setState(() {
  //                 _dataList.add({
  //                   'user': _field1Controller.text,
  //                   'amount': int.parse(_field2Controller.text),
  //                 });
  //               });

  //               // Clear the controllers for the next input
  //               _field1Controller.clear();
  //               _field2Controller.clear();

  //               Navigator.of(context).pop(); // Close dialog
  //             },
  //             child: const Text('Submit'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Create Shared Wallet'),
      // body: Padding(
      //   padding: const EdgeInsets.all(16.0),
      //   child: Column(
      //     children: [
      //       ElevatedButton(
      //         onPressed: () {
      //           _showInputDialog(); // Show the dialog when the button is pressed
      //         },
      //         child: const Text('Add Data'),
      //       ),
      //       const SizedBox(height: 20),
      //       Expanded(
      //         child: ListView.builder(
      //           itemCount: _dataList.length,
      //           itemBuilder: (context, index) {
      //             return Card(
      //               elevation: 3,
      //               margin: const EdgeInsets.symmetric(vertical: 8),
      //               child: Padding(
      //                 padding: const EdgeInsets.all(16.0),
      //                 child: Column(
      //                   crossAxisAlignment: CrossAxisAlignment.start,
      //                   children: [
      //                     Text('User: ${_dataList[index]['user']}'),
      //                     Text('Amount: ${_dataList[index]['amount']}'),
      //                   ],
      //                 ),
      //               ),
      //             );
      //           },
      //         ),
      //       ),
      //       ElevatedButton(
      //         onPressed: () {
      //           createMultisigWallet(
      //               _dataList); // Show the dialog when the button is pressed
      //         },
      //         child: const Text('Print Data'),
      //       ),
      //     ],
      //   ),
      // ),
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
                  _pubKey = value;
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
                controller: _amount2Controller,
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
                controller: _amount1Controller,
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
