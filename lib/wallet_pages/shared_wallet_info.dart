import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
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
  String? receiving1Key;
  String? change1Key;
  String? pubKey2;
  String? privKey;

  int amount1 = 0;
  int amount2 = 0;

  String? descriptorString;

  Descriptor? descriptorWallet;
  Descriptor? internalDescriptorWallet;

  Descriptor? descriptorWallet1;
  Descriptor? descriptorWallet2;

  bool isLoading = false; // For loading state during wallet creation
  bool walletCreated = false; // To avoid multiple wallet creations
  bool boxOpened = false; // to ensure the box is opened only once

  final WalletService _walletService = WalletService();
  late Box<dynamic> descriptorBox;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!walletCreated) {
      final Map<String, dynamic> args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;

      receiving1Key = args['receiving1Key'];
      change1Key = args['change1Key'];
      privKey = args['privKey'];
      pubKey2 = args['pubKey2'];
      amount1 = args['amount1'];
      amount2 = args['amount2'];
      mnemonic = args['mnemonic'];

      createSharedWallet();
    }
  }

  Future<void> createSharedWallet() async {
    try {
      final user1Timelock = amount1;
      final user2Timelock = amount2;

      final user2ReceivingPublicKey = pubKey2;

      // Regular expression to match the final '/0' before '/*'
      final regex = RegExp(r'\/0(?=\/\*)');

      // Replace the final '/0' with '/1'
      final change2Key = pubKey2.toString().replaceFirst(regex, '/1');

      final publicDescriptor = _walletService.createWalletDescriptor(
        receiving1Key.toString(),
        user2ReceivingPublicKey.toString(),
        user1Timelock,
        user2Timelock,
        change1Key.toString(),
        change2Key.toString(),
      );

      setState(() {
        descriptorString = publicDescriptor;
      });
    } catch (e) {
      // print("Error creating or fetching balance for wallet: $e");
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
                receiving1Key!,
                secondaryContent: amount1.toString(),
              ),
              _buildInfoCard(
                'Public Key 2',
                pubKey2!,
                secondaryContent: amount2.toString(),
              ),
              _buildInfoCard(
                'Descriptor',
                descriptorString != null
                    ? descriptorString!
                    : 'Not created yet',
              ),
              _buildInfoCard('Amount 1', amount1.toString()),
              _buildInfoCard('Amount 2', amount2.toString()),
              const SizedBox(height: 16),
              CustomButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SharedWallet(
                        descriptor: descriptorString!,
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
