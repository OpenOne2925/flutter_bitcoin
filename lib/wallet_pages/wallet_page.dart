import 'dart:async';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_buttons_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_ui_helpers.dart';
import 'package:hive/hive.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  WalletPageState createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> {
  // Services and Providers
  late WalletService walletService;
  late Wallet wallet;
  late WalletData? _walletData;
  final WalletStorageService _walletStorageService = WalletStorageService();
  late SettingsProvider settingsProvider;

  // Controllers
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _pubKeyController = TextEditingController();

  // UI Elements and State Management
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool showInSatoshis = true; // Toggle display state
  bool _isLoading = true;
  bool isInitialized = false;
  bool isWalletInitialized = false;

  // Wallet and Transaction Data
  String address = '';
  String myPubKey = '';
  String myMnemonic = '';
  int balance = 0;
  int ledBalance = 0;
  int avBalance = 0;
  List<Map<String, dynamic>> _transactions = [];

  // Currency and Ledger Balances
  double ledCurrencyBalance = 0.0;
  double avCurrencyBalance = 0.0;

  // Blockchain Data
  int _currentHeight = 0;
  String _timeStamp = "";

  // Timer and Refresh Logic
  late DateTime _lastRefreshed;

  // Storage
  var walletBox = Hive.box('walletBox');

  @override
  void initState() {
    super.initState();

    setState(() {
      _isLoading = true;
    });

    // Initialize WalletService
    walletService = WalletService();
    settingsProvider = SettingsProvider();

    setState(() {
      _lastRefreshed = DateTime.now();
    });

    // Load wallet data and fetch the block height only once when the widget is initialized
    _loadWalletFromHive().then((_) {
      _initializePage();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Helper method to extract wallet policies and spending paths
  Future<void> _initializePage() async {
    try {
      String savedMnemonic = walletBox.get('walletMnemonic');

      // Convert mnemonic to object
      Mnemonic trueMnemonic = await Mnemonic.fromString(savedMnemonic);

      // Define derivation paths
      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      // Derive descriptor keys
      final (receivingSecretKey, receivingPublicKey) =
          await walletService.deriveDescriptorKeys(
        hardenedDerivationPath,
        receivingDerivationPath,
        trueMnemonic,
      );

      // print('pubkey: $receivingPublicKey');

      // Extract spending paths
      setState(() {
        myMnemonic = savedMnemonic;
        myPubKey = receivingPublicKey.toString();
        _pubKeyController.text = myPubKey;

        isInitialized = true; // Mark as loaded
      });
    } catch (e) {
      // print("Error initializing spending paths: $e");
      throw ("Error initializing spending paths: $e");
    }
  }

  Future<void> _loadWalletFromHive() async {
    // Restore wallet from the saved mnemonic
    wallet = await walletService.loadSavedWallet();

    setState(() {
      isWalletInitialized = true;
    });

    await _loadWalletData();

    setState(() {
      _isLoading = false; // Mark loading as complete
    });
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _lastRefreshed = DateTime.now();
    });

    address = walletService.getAddress(wallet);

    _walletData = await _walletStorageService.loadWalletData(address);

    if (_walletData != null) {
      // If offline data is available, use it to update the UI
      setState(() {
        address = _walletData!.address;
        ledBalance = _walletData!.ledgerBalance;
        avBalance = _walletData!.availableBalance;
        _transactions = _walletData!.transactions;
        _currentHeight = _walletData!.currentHeight;
        _timeStamp = _walletData!.timeStamp;
        _isLoading = false;
      });
    } else {
      await _checkInternetAndSync();
    }
  }

  Future<void> _checkInternetAndSync() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showNetworkDialog();
    } else {
      _syncWallet();
    }
  }

  // Show a dialog box
  void _showNetworkDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("🌐 No Internet Connection"),
          content: Text(
            "Your wallet needs to sync with the blockchain.\n\nPlease connect to the internet to proceed.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                _checkInternetAndSync();
              },
              child: Text("Retry 🔄"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncWallet() async {
    setState(() {
      _lastRefreshed = DateTime.now();
    });

    await walletService.syncWallet(wallet);

    await _fetchCurrentBlockHeight();

    await walletService.saveLocalData(wallet);

    String walletAddress = walletService.getAddress(wallet);
    setState(() {
      address = walletAddress;
    });

    Map<String, int> balance = await walletService.getBitcoinBalance(address);

    setState(() {
      avBalance = balance['confirmedBalance']!;
      ledBalance = balance['pendingBalance']!;
    });

    // Fetch and set the transactions
    List<Map<String, dynamic>> transactions =
        await walletService.getTransactions(walletAddress);

    transactions = walletService.sortTransactionsByConfirmations(
      transactions,
      _currentHeight,
    );

    setState(() {
      _transactions = transactions;
    });

    await walletService.saveLocalData(wallet);
  }

  Future<void> _fetchCurrentBlockHeight() async {
    int currentHeight = await walletService.fetchCurrentBlockHeight();

    String blockTimestamp =
        await walletService.fetchBlockTimestamp(currentHeight);

    // print('blockTimestamp: $blockTimestamp');

    setState(() {
      _currentHeight = currentHeight;
      _timeStamp = blockTimestamp;
    });
  }

  void _convertCurrency() async {
    final currencyLedUsd = await walletService.convertSatoshisToCurrency(
        ledBalance, settingsProvider.currency);
    final currencyAvUsd = await walletService.convertSatoshisToCurrency(
        avBalance, settingsProvider.currency);

    setState(() {
      ledCurrencyBalance = currencyLedUsd;
      avCurrencyBalance = currencyAvUsd;
      showInSatoshis = !showInSatoshis;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isWalletInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(
                color: Colors.blue,
                size: 50.0,
              ),
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.translate('setting_wallet'),
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    final walletUiHelpers = WalletUiHelpers(
      address: address,
      avBalance: avBalance,
      ledBalance: ledBalance,
      showInSatoshis: showInSatoshis,
      avCurrencyBalance: avCurrencyBalance,
      ledCurrencyBalance: ledCurrencyBalance,
      currentHeight: _currentHeight,
      timeStamp: _timeStamp,
      isInitialized: isInitialized,
      pubKeyController: _pubKeyController,
      settingsProvider: settingsProvider,
      lastRefreshed: _lastRefreshed,
      context: context,
      isLoading: _isLoading,
      transactions: _transactions,
      wallet: wallet,
    );

    final walletButtonsHelper = WalletButtonsHelper(
      context: context,
      address: address,
      mnemonic: myMnemonic,
      isSingleWallet: true,
      recipientController: _recipientController,
      amountController: _amountController,
      walletService: walletService,
      currentHeight: _currentHeight,
      mounted: mounted,
      wallet: wallet,
    );

    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.translate('personal_wallet'),
        style: TextStyle(fontSize: 18),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey, // Assign the GlobalKey to RefreshIndicator
        onRefresh: () async {
          final List<ConnectivityResult> connectivityResult =
              await (Connectivity().checkConnectivity());

          walletUiHelpers.handleRefresh(
            _syncWallet,
            connectivityResult,
            context,
          );
        },
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  walletUiHelpers.buildWalletInfoBox(
                    AppLocalizations.of(context)!.translate('address'),
                    onTap: () {
                      _convertCurrency();
                    },
                    showCopyButton: true,
                  ),
                  walletUiHelpers.buildTransactionsBox(),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    walletButtonsHelper.buildButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
