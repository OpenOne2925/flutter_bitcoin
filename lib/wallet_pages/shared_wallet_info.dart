import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:hive/hive.dart';

class SharedWalletInfo extends StatefulWidget {
  const SharedWalletInfo({super.key});

  @override
  SharedWalletInfoState createState() => SharedWalletInfoState();
}

class SharedWalletInfoState extends State<SharedWalletInfo> {
  String? mnemonic;
  String? pubKey1;
  String? pubKey2;
  String? privKey;

  int amount1 = 0;
  int amount2 = 0;

  String? descriptorString;
  String? descriptorString1;

  Descriptor? descriptorWallet;
  // Descriptor? internalDescriptorWallet;

  Descriptor? descriptorWallet1;
  Descriptor? descriptorWallet2;

  bool isLoading = false; // For loading state during wallet creation
  bool walletCreated = false; // To avoid multiple wallet creations
  bool boxOpened = false; // to ensure the box is opened only once

  late Box<dynamic> descriptorBox;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!walletCreated) {
      final Map<String, dynamic> args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;

      pubKey1 = args['pubKey1'];
      pubKey2 = args['pubKey2'];
      privKey = args['privKey'];
      amount1 = args['amount1'];
      amount2 = args['amount2'];
      mnemonic = args['mnemonic'];

      // print('Public Key 1: $pubKey1');
      // print('Public Key 2: $pubKey2');
      // print('Private Key: $privKey');
      // print('Amount 1: $amount1');
      // print('Amount 2: $amount2');
      // print('Mnemonic: $mnemonic');

      createMultisigWallet(
        pubKey1!,
        pubKey2!,
        privKey!,
        amount1,
        amount2,
      );
    }
  }

  // String createDescriptor(List<String> publicKeys, int threshold) {
  //   // Start building the descriptor
  //   String descriptor = "wsh(multi(";

  //   // Add the threshold (M) to the descriptor
  //   descriptor += "$threshold";

  //   // Dynamically add each public key to the descriptor
  //   for (String pubKey in publicKeys) {
  //     descriptor += ",$pubKey";
  //   }

  //   // Close the descriptor format
  //   descriptor += "))";

  //   return descriptor;
  // }

  Future<void> createMultisigWallet(
    String pubKey1,
    String pubKey2,
    String privKey,
    int amount1,
    int amount2,
  ) async {
    setState(() {
      isLoading = true;
    });
    // String pubKey3, String pubKey4, to add in the second step

    try {
      // If needed this descriptor would just use the basic multisig setup for the change outputs, without any recovery clauses.

      // final descriptor = "wsh(multi(2,$pubKey1,$pubKey2))";
      // final descriptor1 = "wsh(multi(2,$pubKey2,$privKey1))";

      // createDescriptor(publicKeys, threshold);

      String pubKeyDerived1 = pubKey1.replaceAll("*", "0/*");
      String pubKeyDerived2 = pubKey2.replaceAll("*", "0/*");

      String pubKey3 = pubKey1.replaceAll("*", "1/*");
      String pubKey4 = pubKey2.replaceAll("*", "1/*");

      String privKey1 = privKey.replaceAll("*", "0/*");
      String privKey2 = privKey.replaceAll("*", "1/*");

      // Descriptor with 2-of-2 multisig and recovery paths after a specified number of blocks
      final descriptor =
          "wsh(or_d(multi(2,$pubKeyDerived1,$pubKeyDerived2),or_i(and_v(v:older($amount1),pk($pubKey3)),and_v(v:older($amount2),pk($pubKey4)))))";

      final descriptor1 =
          "wsh(or_d(multi(2,$pubKeyDerived2,$privKey1),or_i(and_v(v:older($amount1),pk($privKey2)),and_v(v:older($amount2),pk($pubKey4)))))";

      // print(descriptor);

      // print(descriptor1);

      // final internalDescriptor = replaceAllDerivationPaths(descriptor);

      // print('Ciaoooooooo' + internalDescriptor);

      // Create the wallet using the descriptor
      descriptorWallet = await Descriptor.create(
        descriptor: descriptor,
        network: Network.Testnet, // Use Network.Mainnet for mainnet
      );

      // internalDescriptorWallet = await Descriptor.create(
      //   descriptor: internalDescriptor,
      //   network: Network.Testnet, // Use Network.Mainnet for mainnet
      // );

      descriptorWallet1 = await Descriptor.create(
        descriptor: descriptor1,
        network: Network.Testnet, // Use Network.Mainnet for mainnet
      );

      descriptorString = await descriptorWallet!.asString();
      // descriptorString1 = await descriptorWallet1!.asString();

      descriptorString1 = await descriptorWallet1!.asStringPrivate();

      // print(descriptorString1);

      // final internalDescriptorString =
      //     await internalDescriptorWallet!.asStringPrivate();

      // print(internalDescriptorString);

      await Wallet.create(
        descriptor: descriptorWallet!,
        changeDescriptor: descriptorWallet,
        network: Network.Testnet,
        databaseConfig: const DatabaseConfig.memory(),
      );

      // print('DescriptorString: $descriptorString');
      // print('DescriptorString1: $descriptorString1');

      print("Shared Wallet Created!");
    } catch (e) {
      print("Error creating wallet: $e");
    } finally {
      setState(() {
        isLoading = false;
        walletCreated = true; // Ensure wallet is only created once
      });
    }
  }

  String replaceAllDerivationPaths(String descriptor) {
    // Define the regular expression to match the derivation path [fingerprint/84'/1'/0'/0/0]
    final pattern = RegExp(r"\[\w{8}/84\'/1\'/0\'/0/\d\]");

    // Replace all occurrences of the matched pattern with [fingerprint/84'/1'/0'/1/0]
    String modifiedDescriptor = descriptor.replaceAllMapped(pattern, (match) {
      // Extract the original matched string
      String matchedPath = match.group(0)!;

      // Modify the part that needs to be changed from /0/ to /1/
      String newPath = matchedPath.replaceFirst("/0/", "/1/");

      return newPath; // Return the new modified path
    });

    return modifiedDescriptor; // Return the fully modified descriptor
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Shared Wallet Info'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard('Your Mnemonic', mnemonic!),
              _buildInfoCard(
                'Public Key 1',
                pubKey1!,
                secondaryContent: amount1.toString(),
              ),
              _buildInfoCard(
                'Public Key 2',
                pubKey2!,
                secondaryContent: amount2.toString(),
              ),
              _buildInfoCard(
                'Descriptor',
                descriptorWallet != null
                    ? descriptorString!
                    : 'Not created yet',
              ),
              // _buildInfoCard('Amount 1', amount1.toString()),
              // _buildInfoCard('Amount 2', amount2.toString()),
              const SizedBox(height: 16),
              CustomButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SharedWallet(
                        descriptor: descriptorString1!,
                        mnemonic: mnemonic!,
                      ),
                    ),
                  );
                },
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.orange, // Bitcoin orange color for text
                icon: Icons.arrow_downward, // Icon you want to use
                iconColor: Colors.orange, // Color for the icon
                label: 'Next',
              ),
              // ElevatedButton(
              //   onPressed: isLoading
              //       ? null
              //       : () async {
              //           // Ensure the wallet is created before navigating
              //           // print(descriptorString1!);
              //           Navigator.push(
              //             context,
              //             MaterialPageRoute(
              //               builder: (context) => SharedWallet(
              //                 descriptor: descriptorString1!,
              //                 mnemonic: mnemonic!,
              //               ),
              //             ),
              //           );
              //         },
              //   style: customButtonStyle(),
              //   child: const Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       Icon(Icons.currency_bitcoin),
              //       SizedBox(width: 8),
              //       Text('Next'),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom method to build info cards with Copy button
  Widget _buildInfoCard(String title, String content,
      {String? secondaryContent}) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          content,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (secondaryContent != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              secondaryContent,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title copied to clipboard'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
