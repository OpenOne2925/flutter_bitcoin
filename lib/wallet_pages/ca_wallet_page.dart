import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';

class CAWalletPage extends StatefulWidget {
  const CAWalletPage({super.key});

  @override
  CAWalletPageState createState() => CAWalletPageState();
}

class CAWalletPageState extends State<CAWalletPage> {
  String? _mnemonic;
  String _status = 'Idle';

  Wallet? _wallet;

  final TextEditingController _mnemonicController = TextEditingController();

  final WalletService _walletService = WalletService();

  final Network network = Network.testnet;

  bool _isMnemonicEntered = false;

  @override
  void initState() {
    super.initState();

    _mnemonicController.addListener(() {
      if (_mnemonicController.text.isNotEmpty) {
        _mnemonic = _mnemonicController.text;
        _validateMnemonic(_mnemonic.toString());
      }
    });
  }

  Future<void> _createWallet() async {
    setState(() {
      _status = 'Creating wallet...';
    });

    final connectivityResult = await Connectivity().checkConnectivity();
    Wallet wallet;

    if (!connectivityResult.contains(ConnectivityResult.none)) {
      wallet = await _walletService.loadSavedWallet(_mnemonic!);

      setState(() {
        _wallet = wallet;
        _status = 'Wallet loaded successfully!';
      });
    } else {
      wallet = await _walletService.createOrRestoreWallet(_mnemonic!);
      setState(() {
        _wallet = wallet;
        _status = 'Wallet created successfully';
      });
    }

    var walletBox = Hive.box('walletBox');
    walletBox.put('walletMnemonic', _mnemonic);
    walletBox.put('walletNetwork', network.toString());

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/wallet_page',
      arguments: _wallet,
    );
  }

  Future<void> _generateMnemonic() async {
    final res = await Mnemonic.create(WordCount.words12);

    setState(() {
      _mnemonicController.text = res.asString();
      _mnemonic = res.asString();
      _status = 'New mnemonic generated!';
    });
  }

  String _getAnimationPath() {
    if (_status.contains('successfully')) {
      return 'assets/animations/success.json';
    } else if (_status.contains('Creating')) {
      return 'assets/animations/creating_wallet.json';
    } else {
      return 'assets/animations/idle.json';
    }
  }

  void _validateMnemonic(String value) async {
    final isValid =
        value.trim().isNotEmpty && await _walletService.checkMnemonic(value);

    setState(() {
      _isMnemonicEntered = isValid;
    });

    // print(_isMnemonicEntered);
  }

  Widget _buildStatusIndicator() {
    return Column(
      children: [
        // Lottie Animation
        Lottie.asset(
          _getAnimationPath(),
          height: 100,
          width: 100,
          repeat:
              !_status.contains('successfully'), // Loop only for non-success
        ),
        const SizedBox(height: 10),
        // Status Text
        Text(
          _status,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _status.contains('successfully')
                ? Colors.green
                : _status.contains('Creating')
                    ? Colors.blueAccent
                    : Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create or Restore Wallet'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cool Status Indicator with Animation
              _buildStatusIndicator(),
              const SizedBox(height: 20),
              // Mnemonic Input Field
              TextFormField(
                controller: _mnemonicController,
                onChanged: (value) async {
                  setState(() {
                    _mnemonic = value;
                  });
                },
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter Mnemonic',
                  hintText: 'Enter your 12 words here',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              // Create Wallet Button
              CustomButton(
                onPressed: _isMnemonicEntered ? _createWallet : null,
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: Icons.wallet,
                iconColor: Colors.white,
                label: 'Create Wallet',
                padding: 16.0,
                iconSize: 28.0,
              ),
              const SizedBox(height: 16),
              // Generate Mnemonic Button
              CustomButton(
                onPressed: _generateMnemonic,
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                icon: Icons.create,
                iconColor: Colors.green,
                label: 'Generate Mnemonic',
                padding: 16.0,
                iconSize: 28.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
