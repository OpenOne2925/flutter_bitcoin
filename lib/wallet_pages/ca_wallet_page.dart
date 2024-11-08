import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:hive/hive.dart';

class CAWalletPage extends StatefulWidget {
  const CAWalletPage({super.key});

  @override
  CAWalletPageState createState() => CAWalletPageState();
}

class CAWalletPageState extends State<CAWalletPage> {
  String? _mnemonic;
  String _status = 'Idle';

  // ignore: unused_field
  Wallet? _wallet;

  final TextEditingController _mnemonicController = TextEditingController();

  final WalletService _walletService = WalletService();

  // Call createOrRestoreWallet from WalletService
  Future<void> _createWallet() async {
    setState(() {
      _status = 'Creating wallet...';
    });

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    // print('$connectivityResult');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      // Call the method from WalletService
      final wallet = await _walletService.loadSavedWallet(_mnemonic!);

      // print(wallet);

      setState(() {
        _wallet = wallet;
        _status = 'Wallet created successfully!';
      });

      // Save wallet information locally using Hive
      var walletBox = Hive.box('walletBox');
      walletBox.put('walletMnemonic', _mnemonic);
      walletBox.put('walletNetwork',
          Network.testnet.toString()); // or serialize this properly

      if (!mounted) return;

      // Navigate to the wallet page or update the UI
      Navigator.pushNamed(
        context,
        '/wallet_page',
        arguments: wallet,
      );
    } else {
      // print('No es possibile');
      final wallet = await _walletService.createOrRestoreWallet(
          _mnemonic!, Network.testnet, null);

      // print(wallet);

      setState(() {
        _wallet = wallet;
        _status = 'Wallet created successfully!';
      });

      // Save wallet information locally using Hive
      var walletBox = Hive.box('walletBox');
      walletBox.put('walletMnemonic', _mnemonic);
      walletBox.put('walletNetwork',
          Network.testnet.toString()); // or serialize this properly

      if (!mounted) return;

      // Navigate to the wallet page or update the UI
      Navigator.pushNamed(context, '/wallet_page', arguments: wallet);

      // setState(() {
      //   _status = 'Error: ${e.toString()}';
      // });
    }
  }

  Future<void> _generateMnemonic() async {
    var res = await Mnemonic.create(WordCount.words12);

    // print(res);

    setState(() {
      _mnemonicController.text = res.asString();
      _mnemonic = res.asString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: const Text('Create or Restore Wallet'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display the status of wallet creation
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mnemonicController, // Use the controller here
              onChanged: (value) {
                _mnemonic = value;
              },
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText: 'Enter Mnemonic',
                hintText: 'Enter your 12 words here',
              ),
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface, // Dynamic text color
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: _createWallet,
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.orange, // Bitcoin orange color for text
              icon: Icons.currency_bitcoin, // Icon you want to use
              iconColor: Colors.black, // Color for the icon
              label: 'Create Wallet',
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: _generateMnemonic,
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.black, // Bitcoin orange color for text
              icon: Icons.currency_bitcoin, // Icon you want to use
              iconColor: Colors.orange, // Color for the icon
              label: 'Generate Mnemonic',
            ),
          ],
        ),
      ),
    );
  }
}
