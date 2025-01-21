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
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Add a header icon or illustration
                Center(
                  child: Icon(
                    Icons.account_balance_wallet,
                    size: 100,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                // Add a description
                Text(
                  'Manage your shared Bitcoin wallets with ease! Whether creating a new wallet or importing an existing one, we’ve got you covered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                // Buttons
                CustomButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create_shared');
                  },
                  backgroundColor: Colors.orange, // Vibrant button background
                  foregroundColor: Colors.white, // White text
                  icon: Icons.add_circle, // Add wallet icon
                  iconColor: Colors.white, // Icon matches text
                  label: 'Create New Wallet',
                  padding: 16.0,
                  iconSize: 28.0,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/import_shared');
                  },
                  backgroundColor: Colors.orange.shade100, // Subtle background
                  foregroundColor: Colors.orange.shade700, // Vibrant text
                  icon: Icons.download, // Import wallet icon
                  iconColor: Colors.orange.shade700, // Icon matches text
                  label: 'Import Wallet',
                  padding: 16.0,
                  iconSize: 28.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
