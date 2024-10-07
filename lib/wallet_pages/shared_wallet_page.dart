import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';

class SharedWalletPage extends StatefulWidget {
  const SharedWalletPage({super.key});

  @override
  SharedWalletPageState createState() => SharedWalletPageState();
}

class SharedWalletPageState extends State<SharedWalletPage> {
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Shared Wallet'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create_shared');
              },
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.orange, // Bitcoin orange color for text
              icon: Icons.currency_bitcoin, // Icon you want to use
              iconColor: Colors.black, // Color for the icon
              label: 'Create Wallet',
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: () {
                Navigator.pushNamed(context, '/import_shared');
              },
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.black, // Bitcoin orange color for text
              icon: Icons.currency_bitcoin, // Icon you want to use
              iconColor: Colors.orange, // Color for the icon
              label: 'Import Wallet',
            ),
          ],
        ),
      ),
    );
  }
}
