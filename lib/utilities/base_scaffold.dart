import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/theme_provider.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class BaseScaffold extends StatefulWidget {
  final Widget body;
  final Text title;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  BaseScaffoldState createState() => BaseScaffoldState();
}

class BaseScaffoldState extends State<BaseScaffold> {
  Box<dynamic>? _descriptorBox;

  @override
  void initState() {
    super.initState();
    // Open the Hive box for wallet descriptors
    _descriptorBox = Hive.box<dynamic>('descriptorBox');
  }

  @override
  Widget build(BuildContext context) {
    isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: widget.title,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: isDarkMode ? Colors.deepPurple : Colors.orange,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              isDarkMode = !isDarkMode;
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black,
              ),
              child: Text(
                'Welcome',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 24,
                ),
              ),
            ),
            _buildPersonalWalletTile(context),
            _buildSharedWalletTiles(context),
            _buildCreateSharedWalletTile(context),
          ],
        ),
      ),
      body: widget.body,
    );
  }

  // Widget to build personal wallet tile
  Widget _buildPersonalWalletTile(BuildContext context) {
    return Card(
      color: Colors.grey[200],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.wallet,
          color: Colors.orange,
        ),
        title: const Text(
          'Personal Wallet',
          style: TextStyle(color: Colors.black),
        ),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/wallet_page', (Route<dynamic> route) => false);
        },
      ),
    );
  }

  // Widget to build shared wallet tiles dynamically
  Widget _buildSharedWalletTiles(BuildContext context) {
    List<Widget> sharedWalletCards = [];

    // Iterate over all stored descriptors in the box
    for (int i = 0; i < (_descriptorBox?.length ?? 0); i++) {
      final mnemonic = _descriptorBox?.keyAt(i);
      final descriptor = _descriptorBox?.getAt(i);

      // print('mnemonic: $mnemonic');

      // Create a new card for each shared wallet
      sharedWalletCards.add(
        Card(
          color: Colors.grey[200],
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.account_balance_wallet,
              color: Colors.black,
            ),
            title: Text(
              'Shared Wallet ($i)', // Use mnemonic or descriptor data
              style: const TextStyle(color: Colors.orange),
            ),
            // subtitle: Text('Descriptor: $descriptor'),
            onTap: () {
              // Navigate to shared wallet page or perform actions
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SharedWallet(
                    descriptor: descriptor,
                    mnemonic: mnemonic,
                  ),
                ),
              );
              // Navigator.of(context).pushNamedAndRemoveUntil(
              //     '/shared_wallet', (Route<dynamic> route) => false);
            },
          ),
        ),
      );
    }

    // Return the list of cards
    return Column(children: sharedWalletCards);
  }

  // Widget to build "Create Shared Wallet" tile
  Widget _buildCreateSharedWalletTile(BuildContext context) {
    return Card(
      color: Colors.grey[200], // Set the background color
      elevation: 4, // Optional: add shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Optional: rounded corners
      ),
      child: ListTile(
        leading: const Icon(
          Icons.account_balance_wallet,
          color: Colors.black, // Set the color of the icon
        ),
        title: const Text(
          'Create Shared Wallet',
          style: TextStyle(
            color: Colors.orange, // Set the color of the text
          ),
        ),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/shared_wallet', (Route<dynamic> route) => false);
        },
      ),
    );
  }
}
