import 'dart:async';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/services/settings_provider.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/qr_scanner_page.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:hive/hive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  WalletPageState createState() => WalletPageState();
}

class WalletPageState extends State<WalletPage> {
  late WalletService walletService;
  late Wallet wallet;
  late WalletData? _walletData;

  final WalletStorageService _walletStorageService = WalletStorageService();

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool showInSatoshis = true; // Toggle display state
  double ledCurrencyBalance = 0.0;
  double avCurrencyBalance = 0.0;

  int _currentHeight = 0;
  DateTime? _timeStamp;

  late DateTime _lastRefreshed;
  late Timer _timer;
  String _elapsedTime = '';

  String address = '';

  int balance = 0;
  int ledBalance = 0;
  int avBalance = 0;

  bool _isLoading = true;
  bool _isInitialized = false; // Add a flag to track initialization

  List<Map<String, dynamic>> _transactions = [];

  late SettingsProvider settingsProvider;

  bool _enableTutorial = false;

  final GlobalKey _addressBoxKey = GlobalKey();
  final GlobalKey _addressKey = GlobalKey();
  final GlobalKey _timestampKey = GlobalKey();
  final GlobalKey _balanceBoxKey = GlobalKey();
  final GlobalKey _avBalanceKey = GlobalKey();
  final GlobalKey _ledBalanceKey = GlobalKey();
  final GlobalKey _transactionBoxKey = GlobalKey();
  final GlobalKey _mnemonicBoxKey = GlobalKey();
  final GlobalKey _sendTxKey = GlobalKey();
  final GlobalKey _scanQrKey = GlobalKey();
  final GlobalKey _receiveBitcoinKey = GlobalKey();
  final GlobalKey _recipientFieldKey = GlobalKey();
  final GlobalKey _amountFieldKey = GlobalKey();
  final GlobalKey _sendAllKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Initialize WalletService
    walletService = WalletService();
    settingsProvider = SettingsProvider();

    // Load wallet data and fetch the block height only once when the widget is initialized
    _loadWalletFromHive();
    _loadWalletData();
    _checkAndStartTutorial();
    // _fetchCurrentBlockHeight();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      // Run this block only if the widget is not initialized
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Wallet) {
        wallet = args;
      } else if (args is bool && args == true) {
        // If the argument indicates a refresh is needed, reload data
        _loadWalletFromHive();
        _loadWalletData();
      } else {
        _loadWalletFromHive();
      }

      _triggerPullToRefresh(); // Trigger the refresh only once

      _loadWalletData(); // Reload data every time the page is revisited

      _isInitialized = true; // Set the flag to true to prevent re-running
    }
  }

  Future<void> _checkAndStartTutorial() async {
    var settingsBox = Hive.box('settingsBox');

    _enableTutorial = settingsBox.get('enableTutorial') ?? false;

    if (_enableTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startInitialShowcase();
      });
    }
  }

  // Function to start showcase tutorial with optional callback
  void _startInitialShowcase() {
    ShowCaseWidget.of(context).startShowCase([
      _addressBoxKey,
      _addressKey,
      _timestampKey,
      _balanceBoxKey,
      _avBalanceKey,
      _ledBalanceKey,
      _transactionBoxKey,
      _mnemonicBoxKey,
      _sendTxKey,
      _scanQrKey,
      _receiveBitcoinKey,
    ]);
  }

  Future<void> _fetchCurrentBlockHeight() async {
    int currentHeight = await walletService.fetchCurrentBlockHeight();

    DateTime? blockTimestamp = await walletService.fetchBlockTimestamp();

    setState(() {
      _currentHeight = currentHeight;
      _timeStamp = blockTimestamp;
    });
  }

  Future<void> _triggerPullToRefresh() async {
    Future.delayed(Duration.zero, () {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  Future<void> _loadWalletFromHive() async {
    // Restore wallet from the saved mnemonic
    wallet = await walletService.loadSavedWallet(null);
    setState(() {
      _isLoading = false; // Mark loading as complete
    });
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true; // Show a loading indicator
    });

    setState(() {
      _lastRefreshed = DateTime.now();
      _elapsedTime = 'Just now'; // Reset elapsed time on refresh
    });

    // Start a timer to update elapsed time every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel(); // Cancella il timer se il widget è stato smontato
        return;
      }

      setState(() {
        final duration = DateTime.now().difference(_lastRefreshed);
        _elapsedTime = _formatDuration(duration);
      });
    });

    try {
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      // print('$connectivityResult');

      if (connectivityResult.contains(ConnectivityResult.none)) {
        // print('Offline mode: Loading wallet data from local storage');

        final savedWallet = await walletService.loadSavedWallet(null);
        setState(() {
          wallet = savedWallet;
        });

        var addressInfo =
            wallet.getAddress(addressIndex: const AddressIndex.peek(index: 0));

        // print(addressInfo.address);

        // Attempt to load wallet data from local storage (offline mode)
        _walletData = await _walletStorageService
            .loadWalletData(addressInfo.address.asString());

        // print(_walletData);

        if (_walletData != null) {
          // If offline data is available, use it to update the UI
          setState(() {
            address = _walletData!.address;
            ledBalance = _walletData!.ledgerBalance;
            avBalance = _walletData!.availableBalance;
            _transactions = _walletData!.transactions.map((tx) {
              return {'txid': tx}; // Convert to transaction format you expect
            }).toList();
            _currentHeight = _walletData!.currentHeight;
            _timeStamp = _walletData!.timeStamp;
            _isLoading = false;
          });

          // print(_transactions);

          // print('Loaded offline wallet data');
          return; // Exit the function if offline data is loaded successfully
        } else {
          // print('Generating address');
          // Fetch and set the address
          var walletAddressInfo = wallet.getAddress(
            addressIndex: const AddressIndex.peek(index: 0),
          );

          setState(() {
            address = walletAddressInfo.address.asString();
          });
        }
      } else {
        _fetchCurrentBlockHeight();
        wallet = await walletService.loadSavedWallet(null);
        // Fetch and set the balance of the specific address

        await walletService.syncWallet(wallet);

        // print(wallet);
        await walletService.saveLocalData(wallet);
        // If no offline data is available, proceed to fetch online data
        // print('No offline data available, fetching from network');

        // Fetch and set the address
        String walletAddress = walletService.getAddress(wallet);
        setState(() {
          address = walletAddress;
        });

        Map<String, int> balance =
            await walletService.getBitcoinBalance(address);

        // print("Confirmed Balance: ${balance['confirmedBalance']} sats");
        // print("Pending Balance: ${balance['pendingBalance']} sats");

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

        // print(_transactions);
      }
    } catch (e) {
      // print('Error loading wallet data: $e');
      throw ('Error loading wallet data: $e');
    } finally {
      setState(() {
        _isLoading = false; // Hide the loading indicator
      });
    }
  }

  void _sendTx({String? recipientAddressQr}) async {
    if (recipientAddressQr != null) {
      setState(() {
        _recipientController.text = recipientAddressQr;
      });
    }

    if (!mounted) return;

    if (_enableTutorial) {
      ShowCaseWidget.of(context).startShowCase([
        _recipientFieldKey,
        _amountFieldKey,
        _sendAllKey,
      ]);
    }

    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                String? errorMessage;

                return AlertDialog(
                  backgroundColor: Colors.grey[900], // Dark background
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  title: const Text(
                    'Sending Menu',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: Container(
                    width: constraints.maxWidth * 0.9, // Set width dynamically
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.6, // Limit height
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min, // Prevents infinite height
                        children: [
                          // TextField for Recipient Address
                          Showcase(
                            key: _recipientFieldKey,
                            description:
                                'Tap here to create and broadcast a transaction.',
                            child: TextFormField(
                              controller: _recipientController,
                              decoration:
                                  CustomTextFieldStyles.textFieldDecoration(
                                context: context,
                                labelText: 'Recipient Address',
                                hintText: 'Enter Recipient\'s Address',
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                errorMessage,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 14),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // TextField for Amount
                          Showcase(
                            key: _amountFieldKey,
                            description:
                                'Tap here to create and broadcast a transaction.',
                            child: TextFormField(
                              controller: _amountController,
                              decoration:
                                  CustomTextFieldStyles.textFieldDecoration(
                                context: context,
                                labelText: 'Amount',
                                hintText: 'Enter Amount (Sats)',
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // "Use Available Balance" Button
                          Showcase(
                            key: _sendAllKey,
                            description:
                                'This will use your available spendable balance, remember to first enter an address so the size of the transaction can be calculated correctly.',
                            child: InkwellButton(
                              onTap: () async {
                                try {
                                  final int availableBalance =
                                      wallet.getBalance().spendable.toInt();

                                  final String recipientAddress =
                                      _recipientController.text.toString();

                                  final int sendAllBalance = await walletService
                                      .calculateSendAllBalance(
                                    recipientAddress: recipientAddress,
                                    wallet: wallet,
                                    availableBalance: availableBalance,
                                    walletService: walletService,
                                  );

                                  _amountController.text =
                                      sendAllBalance.toString();
                                  print(
                                      'Final Send All Balance: $sendAllBalance');
                                } catch (e) {
                                  print('Error: $e');
                                  _amountController.text =
                                      'No balance Available';
                                }
                              },
                              label: 'Use Available Balance',
                              icon: Icons.account_balance_wallet_rounded,
                              backgroundColor: Colors.blue,
                              textColor: Colors.white,
                              iconColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    InkwellButton(
                      onTap: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      label: 'Cancel',
                      backgroundColor: Colors.white,
                      textColor: Colors.black,
                    ),
                    InkwellButton(
                      onTap: () async {
                        try {
                          final String recipientAddressStr =
                              _recipientController.text;

                          if (recipientAddressStr.isEmpty) {
                            setState(() {
                              errorMessage = 'Recipient address is required!';
                            });
                            return;
                          }

                          final int amount = int.parse(_amountController.text);
                          final String changeAddressStr = address;

                          await walletService.sendTx(
                            recipientAddressStr,
                            BigInt.from(amount),
                            wallet,
                            changeAddressStr,
                          );

                          // Show a success message
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Transaction created successfully.'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        } catch (e) {
                          // Show error message in a snackbar
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString(),
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }

                        Navigator.of(context).pop();
                      },
                      label: 'Send',
                      backgroundColor: Colors.blue,
                      textColor: Colors.white,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    ).then((_) {
      _recipientController.clear();
      _amountController.clear();
    });
  }

  // Method to display the QR code in a dialog
  void _showQRCodeDialog(BuildContext rootContext, String address) {
    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background for the dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: Text(
            'Receive Bitcoin',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue, // Highlighted title color
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 300.0, // Ensure content does not exceed this width
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // Minimize the height of the Column
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // QR Code Container
                Container(
                  width: 200, // Explicit width
                  height: 200, // Explicit height
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                        16.0), // Rounded QR code container
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                        offset: const Offset(0, 4), // Subtle shadow for QR code
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: address,
                    version: QrVersions.auto,
                    size: 180.0, // Ensure QR code is smaller than the container
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Display the actual address below the QR code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SelectableText(
                        address,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70, // Softer text color
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Space between text and icon
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.blue, // Highlighted icon color
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: address));
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content: const Text('Address copied to clipboard!'),
                            backgroundColor: Colors.white,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop(); // Close dialog
              },
              label: 'Cancel',
              backgroundColor: Colors.white,
              textColor: Colors.black,
            ),
          ],
        );
      },
    );
  }

  // Function to show a PIN input dialog
  void _showPinDialog(BuildContext rootContext) {
    TextEditingController pinController =
        TextEditingController(); // Controller for the PIN input

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background for the dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: const Text(
            'Enter PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your 6-digit PIN:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinController, // Controller to capture PIN input
                keyboardType: TextInputType.number, // Numeric input
                obscureText: true, // Obscure input for security
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: rootContext,
                  labelText: 'Enter PIN',
                  hintText: 'Enter PIN',
                ),
                style: TextStyle(
                  color: Theme.of(rootContext)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
            ],
          ),
          actions: [
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop(); // Close the dialog without action
              },
              label: 'Cancel',
              backgroundColor: Colors.white,
              textColor: Colors.black,
              icon: Icons.cancel_rounded,
              iconColor: Colors.black,
            ),
            InkwellButton(
              onTap: () {
                String pin = pinController.text;
                if (pin.length == 6) {
                  verifyPin(rootContext,
                      pinController); // Call the verification function
                } else {
                  // Show an error if the PIN is invalid
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Invalid PIN',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              label: 'Confirm',
              backgroundColor: Colors.blue,
              textColor: Colors.white,
              icon: Icons.check_rounded,
              iconColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  void verifyPin(
      BuildContext rootContext, TextEditingController pinController) async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    String savedMnemonic = walletBox.get('walletMnemonic');

    if (savedPin == pinController.text) {
      // Navigator.of(context).pop(); // Close the PIN dialog

      Future.delayed(
        Duration(milliseconds: 200),
        () {
          showDialog(
            context: rootContext,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor:
                    Colors.grey[900], // Dark background for the dialog
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners
                ),
                title: const Text(
                  'Your Mnemonic',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue, // Highlighted title color
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Here is your saved mnemonic:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70, // Softer text color
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius:
                            BorderRadius.circular(8.0), // Rounded edges
                        border: Border.all(
                          color: Colors.blue, // Border color for emphasis
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SelectableText(
                              savedMnemonic,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70, // Softer text color
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              color: Colors.blue, // Highlighted icon color
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: savedMnemonic));
                              // Close the dialog first
                              Navigator.of(context).pop();

                              // Show the SnackBar AFTER the dialog is fully closed
                              ScaffoldMessenger.of(rootContext).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Mnemonic copied to clipboard!'),
                                  backgroundColor: Colors.white,
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  InkwellButton(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    label: 'Close',
                    backgroundColor: Colors.blue,
                    textColor: Colors.white,
                    icon: Icons.close,
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds} seconds';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minutes';
    } else {
      return '${duration.inHours} hours';
    }
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
    // Determine color and sign
    Color balanceColor = ledBalance > 0
        ? Colors.blue
        : (ledBalance < 0 ? Colors.red : Colors.grey);

    return BaseScaffold(
      title: const Text('Wallet Page'),
      body: RefreshIndicator(
        key: _refreshIndicatorKey, // Assign the GlobalKey to RefreshIndicator
        onRefresh:
            _loadWalletData, // Call this method when the user pulls to refresh
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  Showcase(
                    key: _addressBoxKey,
                    description: 'This is your address box.',
                    child: _buildInfoBox(
                      'Address',
                      Showcase(
                        key: _addressKey,
                        description: 'This is your address.',
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Showcase(
                            key: _timestampKey,
                            description:
                                'This is the current date and block height.',
                            child: Text(
                              'We are currently at Block Height: $_currentHeight\n'
                              'Timestamp: $_timeStamp',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      () {
                        // Handle tap action here
                      },
                      showCopyButton: true,
                      subtitle: (DateTime.now()
                                  .difference(_lastRefreshed)
                                  .inHours >=
                              2)
                          ? '$_elapsedTime have passed! \nIt\'s time to refresh!'
                          : null,
                    ),
                  ),
                  Showcase(
                    key: _balanceBoxKey,
                    description: 'This is your balance box.',
                    child: _buildWidgetInfoBox(
                      'Balance',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show the primary available balance
                          showInSatoshis
                              ? Showcase(
                                  key: _avBalanceKey,
                                  description:
                                      'This is your available balance. Tap to show currency value',
                                  child: Text('$avBalance sats'),
                                )
                              : Text.rich(
                                  TextSpan(
                                    text:
                                        '${avCurrencyBalance.toStringAsFixed(2)} ',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: settingsProvider.currency,
                                      ),
                                    ],
                                  ),
                                ),

                          const SizedBox(height: 8), // Add spacing

                          // Calculate and show the difference
                          showInSatoshis
                              ? Showcase(
                                  key: _ledBalanceKey,
                                  description:
                                      'This is your ledger balance. Here will be displayed how much non confirmed balance you have.',
                                  child: Text(
                                    '$ledBalance sats',
                                    style: TextStyle(
                                      color: balanceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Text.rich(
                                  TextSpan(
                                    text:
                                        '${ledCurrencyBalance.toStringAsFixed(2)} ',
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: balanceColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(text: settingsProvider.currency),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                      () {
                        _convertCurrency();
                      },
                    ),
                  ),
                  Showcase(
                    key: _transactionBoxKey,
                    description:
                        'This is your transactions box. Here will be displayed all your Bitcoin transactions, tap on each one for more info.',
                    child:
                        _buildTransactionsBox(), // Transactions box should scroll along with the rest
                  ),
                ],
              ),
            ),
            // Buttons section pinned at the bottom
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Showcase(
                      key: _mnemonicBoxKey,
                      description:
                          'This is where your mnemonic is stored, remember your PIN? Use it to access it.',
                      child: CustomButton(
                        onPressed: () {
                          _showPinDialog(context);
                        },
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        icon: Icons.remove_red_eye, // Icon for the new button
                        iconColor: Colors.black,
                        label: 'Mnemonic',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Send Button
                        Showcase(
                          key: _sendTxKey,
                          description:
                              'Tap here to create and broadcast a transaction.',
                          child: CustomButton(
                            onPressed: () {
                              _sendTx(); // Call your send transaction function
                            },
                            backgroundColor: Colors.white, // White background
                            foregroundColor:
                                Colors.blue, // Bitcoin green color for text
                            icon: Icons.arrow_upward, // Icon you want to use
                            iconColor: Colors.blue, // Color for the icon
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Scan to Send Button
                        Showcase(
                          key: _scanQrKey,
                          description:
                              'Tap here to scan a Bitcoin QrCode and send a transaction.',
                          child: CustomButton(
                            onPressed: () async {
                              final recipientAddressStr = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const QRScannerPage()),
                              );
                              if (recipientAddressStr != null) {
                                _sendTx(
                                    recipientAddressQr: recipientAddressStr);
                              }
                            },
                            backgroundColor: Colors.white, // White background
                            foregroundColor:
                                Colors.blue, // Bitcoin green color for text
                            icon: Icons.qr_code, // Icon you want to use
                            iconColor: Colors.black, // Color for the icon
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Receive Bitcoin Button
                        Showcase(
                          key: _receiveBitcoinKey,
                          description:
                              'Tap here to visualize your address and generated QrCode.',
                          child: CustomButton(
                            onPressed: () {
                              // Show the QR code for receiving
                              _showQRCodeDialog(context, address);
                            },
                            backgroundColor: Colors.white, // White background
                            foregroundColor:
                                Colors.blue, // Bitcoin green color for text
                            icon: Icons.arrow_downward, // Icon you want to use
                            iconColor: Colors.blue, // Color for the icon
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Box for displaying general wallet info with onTap functionality
  Widget _buildInfoBox(
      String title, Widget section1, Widget section2, VoidCallback onTap,
      {bool showCopyButton = false, String? subtitle}) {
    return GestureDetector(
      onTap: onTap, // Detects tap and calls the passed function
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0), // Rounded corners
        ),
        elevation: 4, // Subtle shadow for depth
        color: Colors.white, // Match button background
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),

              // First Section with Copy Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: section1,
                  ),
                  if (showCopyButton) // Display copy button if true
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      tooltip: 'Copy to clipboard',
                      onPressed: () {
                        // Extract text from section1 if it's a Showcase containing a Text widget
                        if (section1 is Showcase && (section1.child is Text)) {
                          Clipboard.setData(ClipboardData(
                              text: (section1.child as Text).data ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Copied to clipboard"),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),

              // Divider Between Sections
              const Divider(
                height: 20,
                thickness: 1,
                color: Colors.grey,
              ),

              // Second Section Without Copy Button
              section2,

              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetInfoBox(String title, Widget data, VoidCallback onTap,
      {bool showCopyButton = false,
      String? subtitle,
      TextStyle? dataTextStyle}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 4,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: dataTextStyle ??
                          const TextStyle(
                            fontSize: 16,
                            color: Colors.black, // Default to black
                          ),
                      child: data, // Display the passed widget here
                    ),
                  ),
                  if (showCopyButton)
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.blue),
                      tooltip: 'Copy to clipboard',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: data.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Copied to clipboard"),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsBox() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
      ),
      elevation: 4, // Subtle shadow for depth
      color: Colors.white, // Match button background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_transactions.length} Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue, // Match button text color
              ),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Text('No transactions available')
                    : SizedBox(
                        height: 310, // Define the height of the scrollable area
                        child: ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final tx = _transactions[index];

                            return KeyedSubtree(
                              key: ValueKey(tx['txid']),
                              child: GestureDetector(
                                onTap: () {
                                  _showTransactionsDialog(
                                    context,
                                    _transactions[index],
                                  );
                                },
                                child:
                                    _buildTransactionItem(_transactions[index]),
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    // Extract confirmation status
    final blockHeight = tx['status']?['block_height'];
    final confirmations =
        blockHeight != null ? _currentHeight - blockHeight : -1;
    final isConfirmed = confirmations >= 0;

    // Transaction fee
    final fee = tx['fee'] ?? 0;

    // Extract all input addresses (senders) and their total input value
    final inputAddresses = tx['vin']
            ?.map((vin) => vin['prevout']?['scriptpubkey_address'] as String?)
            ?.where((addr) => addr != null)
            ?.toSet() ??
        {};

    final totalInput = tx['vin']?.fold<int>(
          0,
          (int sum, dynamic vin) =>
              sum + ((vin['prevout']?['value'] as int?) ?? 0),
        ) ??
        0;

    // Extract all output addresses (receivers) and their total output value
    final outputAddresses = tx['vout']
            ?.map((vout) => vout['scriptpubkey_address'] as String?)
            ?.where((addr) => addr != null)
            ?.toSet() ??
        {};

    final totalOutput = tx['vout']?.fold<int>(
          0,
          (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
        ) ??
        0;

    // Check if transaction is sent, received, or internal
    final isSent = inputAddresses.contains(address); // Sent transaction
    final isReceived =
        outputAddresses.contains(address); // Received transaction
    final isInternal = inputAddresses.length == 1 &&
        inputAddresses.contains(address) &&
        outputAddresses.length == 1 &&
        outputAddresses.contains(address); // Internal transaction

    // Determine the amount sent/received
    int amount = 0;

    if (isInternal) {
      amount = totalOutput; // Full amount in an internal transaction
    } else if (isSent) {
      amount = tx['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] !=
                  address) // Exclude own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    } else if (isReceived) {
      amount = tx['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] ==
                  address) // Include only own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    }

    // Extract specific sender/recipient address
    String? counterpartyAddress;

    if (isSent) {
      counterpartyAddress = outputAddresses
          .where((addr) => addr != address) // Exclude own address
          .join(', ');
    } else if (isReceived) {
      // If multiple input addresses exist, the sender is likely the one contributing the most BTC.
      if (inputAddresses.isNotEmpty) {
        counterpartyAddress =
            inputAddresses.first; // Default to the first sender

        // Find the input with the highest value (likely the fee payer)
        int highestInputValue = 0;
        String? feePayerAddress;

        for (var vin in tx['vin']) {
          String? inputAddr = vin['prevout']?['scriptpubkey_address'];
          int inputValue = vin['prevout']?['value'] ?? 0;

          if (inputAddr != null && inputValue > highestInputValue) {
            highestInputValue = inputValue;
            feePayerAddress = inputAddr;
          }
        }

        // Use the highest input as the sender if found
        if (feePayerAddress != null) {
          counterpartyAddress = feePayerAddress;
        }
      }
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 2,
      color: isInternal
          ? Colors.orange
          : Colors.white, // Change color for internal tx
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  isConfirmed ? Icons.check_circle : Icons.timelapse,
                  color: isConfirmed ? Colors.blue : Colors.orange,
                ),
                Text(
                  isInternal
                      ? "Internal \n$amount satoshis transferred"
                      : '${isSent ? "Sent" : "Received"}: $amount satoshis',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 4),
            if (!isInternal)
              Text(
                isSent
                    ? "To: $counterpartyAddress"
                    : "From: $counterpartyAddress",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            if (isSent || isInternal)
              Text(
                isInternal
                    ? '$fee satoshis spent in fees'
                    : 'Fee: $fee satoshis',
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
          ],
        ),
      ),
    );
  }

  void _showTransactionsDialog(
    BuildContext rootContext,
    Map<String, dynamic> transaction,
  ) {
    final txid = transaction['txid'];

    // Extract confirmation details
    final blockHeight = transaction['status']?['block_height'];
    final isConfirmed = blockHeight != null;
    final confirmations = isConfirmed ? _currentHeight - blockHeight : -1;
    final blockTime = isConfirmed
        ? DateTime.fromMillisecondsSinceEpoch(
            (transaction['status']['block_time'] ?? 0) * 1000,
          ).toLocal()
        : 'Unconfirmed';

    // Extract transaction fee
    final fee = transaction['fee'] ?? 0;

    // Extract all input addresses (senders)
    final Set<String> inputAddresses = (transaction['vin'] as List<dynamic>)
        .map((vin) => vin['prevout']['scriptpubkey_address'] as String)
        .toSet();

    final int totalInput = transaction['vin']?.fold<int>(
          0,
          (int sum, dynamic vin) =>
              sum + ((vin['prevout']?['value'] as int?) ?? 0),
        ) ??
        0;

    // Extract all ouput addresses (receivers
    final Set<String> outputAddresses = (transaction['vout'] as List<dynamic>)
        .map((vout) => vout['scriptpubkey_address'] as String)
        .toSet();

    final int totalOutput = transaction['vout']?.fold<int>(
          0,
          (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
        ) ??
        0;

    // Determine if transaction is sent, received, or internal
    final bool isSent = inputAddresses.contains(address);
    final bool isReceived = outputAddresses.contains(address);
    final bool isInternal = inputAddresses.length == 1 &&
        inputAddresses.contains(address) &&
        outputAddresses.length == 1 &&
        outputAddresses.contains(address);

    // Determine the actual amount sent/received
    int amount = 0;

    if (isInternal) {
      amount = totalOutput;
    } else if (isSent) {
      amount = transaction['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] !=
                  address) // Exclude own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    } else if (isReceived) {
      amount = transaction['vout']
              ?.where((vout) =>
                  vout['scriptpubkey_address'] ==
                  address) // Include own address
              ?.fold<int>(
                0,
                (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
              ) ??
          0;
    }

    // Build the dialog
    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Transaction Details',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transaction Type
                      Text(
                        isInternal
                            ? "Internal Transaction"
                            : isSent
                                ? 'Sent Transaction'
                                : 'Received Transaction',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sender Addresses
                      const Text(
                        "Senders",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: inputAddresses.map((sender) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    sender,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      overflow: TextOverflow
                                          .ellipsis, // Handle long addresses
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: Colors.blue, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: sender));
                                    ScaffoldMessenger.of(rootContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Copied to clipboard: $sender'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Receiver Addresses
                      const Text(
                        "Receivers",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: outputAddresses.map((receiver) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    receiver,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      overflow: TextOverflow
                                          .ellipsis, // Handle long addresses
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: Colors.blue, size: 20),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: receiver));
                                    ScaffoldMessenger.of(rootContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Copied to clipboard: $receiver'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 8),

                      // Amount Sent/Received
                      const Text(
                        "Amount",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        "$amount satoshis",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Transaction Fee
                      if (isSent || isInternal) ...[
                        const Text(
                          "Transaction Fee",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Text(
                          "$fee satoshis",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Confirmation Details
                      const Text(
                        "Confirmation Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        isConfirmed
                            ? "Confirmed at block: $blockHeight"
                            : "Status: Unconfirmed",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      if (isConfirmed)
                        Text(
                          "Block Time: \n$blockTime",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),

                      GestureDetector(
                        onTap: () async {
                          final Uri url = Uri.parse(
                              "https://mempool.space/testnet4/tx/$txid/");

                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          } else {
                            throw "Could not launch $url";
                          }
                        },
                        child: Text(
                          "Visit the Mempool",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }
}
