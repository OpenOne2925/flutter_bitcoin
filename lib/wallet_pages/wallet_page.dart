import 'dart:async';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  int _currentHeight = 0;

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

  @override
  void initState() {
    super.initState();

    // Initialize WalletService
    walletService = WalletService();

    // Load wallet data and fetch the block height only once when the widget is initialized
    _loadWalletFromHive();
    _loadWalletData();
    _fetchCurrentBlockHeight();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
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

  Future<void> _fetchCurrentBlockHeight() async {
    int currentHeight = await walletService.fetchCurrentBlockHeight();

    setState(() {
      _currentHeight = currentHeight;
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

        try {
          final savedWallet = await walletService.loadSavedWallet(null);
          setState(() {
            wallet = savedWallet;
          });
        } catch (e) {
          // print('No Data Found Locally');
          throw ('No Data Found Locally');
        }

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
        // print(wallet);
        await walletService.saveLocalData(wallet);
        // If no offline data is available, proceed to fetch online data
        // print('No offline data available, fetching from network');

        // Fetch and set the address
        String walletAddress = walletService.getAddress(wallet);
        setState(() {
          address = walletAddress;
        });

        // Fetch and set the balance of the specific address
        int ledgerBalance = await walletService.getLedgerBalance(walletAddress);
        int availableBalance =
            await walletService.getAvailableBalance(walletAddress);
        setState(() {
          ledBalance = ledgerBalance;
          avBalance = availableBalance;
        });

        // Fetch and set the transactions
        List<Map<String, dynamic>> transactions =
            await walletService.getTransactions(walletAddress);
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background color for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: const Text(
            'Sending Menu',
            style: TextStyle(color: Colors.white), // Custom title text color
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TextField for Recipient Address
              TextFormField(
                controller: _recipientController, // Use the controller here
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Recipient Address',
                  hintText: 'Enter Recipient\'s Address',
                ),
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
              const SizedBox(height: 16), // Add spacing between fields

              // TextField for Amount
              TextFormField(
                controller: _amountController, // Use the controller here
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Amount',
                  hintText: 'Enter Amount (Sats)',
                ),
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
                keyboardType: TextInputType.number, // Numeric input
              ),

              const SizedBox(height: 16),

              // "Send All" Button
              InkwellButton(
                onTap: () async {
                  try {
                    final int availableBalance =
                        wallet.getBalance().confirmed.toInt();

                    final String recipientAddress =
                        _recipientController.text.toString();

                    final int sendAllBalance =
                        await walletService.calculateSendAllBalance(
                      recipientAddress: recipientAddress,
                      wallet: wallet,
                      availableBalance: availableBalance,
                      walletService: walletService,
                    );

                    _amountController.text = sendAllBalance.toString();
                    print('Final Send All Balance: $sendAllBalance');
                  } catch (e) {
                    print('Error: $e');
                    _amountController.text = 'No balance Available';
                  }
                },
                label: 'Send All',
                icon: Icons.account_balance_wallet_rounded,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                iconColor: Colors.white,
              ),
            ],
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
                  final String recipientAddressStr = _recipientController.text;
                  final int amount = int.parse(_amountController.text);
                  final String changeAddressStr = address;

                  await walletService.sendTx(
                    recipientAddressStr,
                    BigInt.from(amount),
                    wallet,
                    changeAddressStr,
                  );

                  // Show a success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transaction created successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Show error message in a snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
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
              label: 'Submit',
              backgroundColor: Colors.green,
              textColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  // Method to display the QR code in a dialog
  void _showQRCodeDialog(String address) {
    showDialog(
      context: context,
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
              color: Colors.green, // Highlighted title color
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
                        color: Colors.green, // Highlighted icon color
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: address));
                        ScaffoldMessenger.of(context).showSnackBar(
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
  void _showPinDialog(BuildContext context) {
    TextEditingController pinController =
        TextEditingController(); // Controller for the PIN input

    showDialog(
      context: context,
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
              color: Colors.green,
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
                  context: context,
                  labelText: 'Enter PIN',
                  hintText: 'Enter PIN',
                ),
                style: TextStyle(
                  color: Theme.of(context)
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
                  verifyPin(pinController); // Call the verification function
                } else {
                  // Show an error if the PIN is invalid
                  ScaffoldMessenger.of(context).showSnackBar(
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
              backgroundColor: Colors.green,
              textColor: Colors.white,
              icon: Icons.check_rounded,
              iconColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  void verifyPin(TextEditingController pinController) async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    String savedMnemonic = walletBox.get('walletMnemonic');

    if (savedPin == pinController.text) {
      Navigator.of(context).pop(); // Close the PIN dialog

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900], // Dark background for the dialog
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0), // Rounded corners
            ),
            title: const Text(
              'Your Mnemonic',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green, // Highlighted title color
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
                    borderRadius: BorderRadius.circular(8.0), // Rounded edges
                    border: Border.all(
                      color: Colors.green, // Border color for emphasis
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
                      const SizedBox(width: 8), // Space between text and icon
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.green, // Highlighted icon color
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: savedMnemonic));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Mnemonic copied to clipboard!'),
                              backgroundColor: Colors.white,
                              duration: const Duration(seconds: 2),
                            ),
                          );
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
                  Navigator.of(context)
                      .pop(); // Close the dialog without action
                },
                label: 'Close',
                backgroundColor: Colors.green,
                textColor: Colors.white,
                icon: Icons.close,
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  void _sortTransactionsByConfirmedTime() {
    _transactions.sort((a, b) {
      // Extract block times for comparison
      final blockTimeA =
          a['status']?['block_time'] ?? 0; // Default to 0 if not confirmed
      final blockTimeB = b['status']?['block_time'] ?? 0;

      // Sort by block time in descending order (newest first)
      return blockTimeB.compareTo(blockTimeA);
    });
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

  @override
  Widget build(BuildContext context) {
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
                  _buildInfoBox(
                    'Current Block Height',
                    'We are currently at Block Height: $_currentHeight',
                    () {},
                    subtitle: (DateTime.now()
                                .difference(_lastRefreshed)
                                .inHours >=
                            2)
                        ? '$_elapsedTime have passed! \nIt\'s time to refresh!'
                        : null,
                  ),
                  _buildInfoBox(
                    'Address',
                    address,
                    () {},
                    showCopyButton: true,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoBox(
                            'Ledger \nBalance', '$ledBalance sats', () {}),
                      ),
                      const SizedBox(width: 8), // Add space between the boxes
                      Expanded(
                        child: _buildInfoBox(
                            'Available \nBalance', '$avBalance sats', () {}),
                      ),
                    ],
                  ),
                  _buildTransactionsBox(), // Transactions box should scroll along with the rest
                ],
              ),
            ),
            // Buttons section pinned at the bottom
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    CustomButton(
                      onPressed: () {
                        _showPinDialog(context);
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green,
                      icon: Icons.remove_red_eye, // Icon for the new button
                      iconColor: Colors.black,
                      label: 'Mnemonic',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Send Button
                        CustomButton(
                          onPressed: () {
                            _sendTx(); // Call your send transaction function
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.green, // Bitcoin green color for text
                          icon: Icons.arrow_upward, // Icon you want to use
                          iconColor: Colors.green, // Color for the icon
                        ),
                        const SizedBox(width: 8),
                        // Scan to Send Button
                        CustomButton(
                          onPressed: () async {
                            final recipientAddressStr = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const QRScannerPage()),
                            );
                            if (recipientAddressStr != null) {
                              _sendTx(recipientAddressQr: recipientAddressStr);
                            }
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.green, // Bitcoin green color for text
                          icon: Icons.qr_code, // Icon you want to use
                          iconColor: Colors.black, // Color for the icon
                        ),
                        const SizedBox(width: 8),
                        // Receive Bitcoin Button
                        CustomButton(
                          onPressed: () {
                            // Show the QR code for receiving
                            _showQRCodeDialog(address);
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.green, // Bitcoin green color for text
                          icon: Icons.arrow_downward, // Icon you want to use
                          iconColor: Colors.green, // Color for the icon
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
  Widget _buildInfoBox(String title, String data, VoidCallback onTap,
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green, // Match button text color
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black, // Black text to match theme
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showCopyButton) // Display copy button if true
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.green),
                      tooltip: 'Copy to clipboard',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: data));
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
                    color: Colors.red, // Lighter color for secondary text
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
    _sortTransactionsByConfirmedTime();

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
            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green, // Match button text color
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
                            return GestureDetector(
                              onTap: () {
                                _showTransactionsDialog(
                                    context, _transactions[index]);
                              },
                              child:
                                  _buildTransactionItem(_transactions[index]),
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
    // Unwrap the transaction if it is wrapped inside an extra 'txid' key
    if (tx.containsKey('txid') && tx['txid'] is Map) {
      tx = tx['txid'];
    }

    // Safely access vout[0] for the amount received and receiver address

    final firstVout = tx['vout'] != null && tx['vout'].isNotEmpty
        ? tx['vout'].firstWhere(
            (vout) => (vout['scriptpubkey_address'] ==
                address), // Check if the address matches
            orElse: () => null,
          )
        : null;

    final receiver =
        firstVout != null && firstVout['scriptpubkey_address'] != null
            ? firstVout['scriptpubkey_address'] ?? 'Unknown Receiver'
            : 'Unknown Receiver';

    final fee = tx['fee'] ?? 0;

    final isReceived = tx['vout'] != null &&
        tx['vout'].any((vout) => vout['scriptpubkey_address'] == address);

    final amount = isReceived
        ? tx['vout']
            .where((vout) => vout['scriptpubkey_address'] == address)
            .fold<int>(
              0,
              (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
            )
        : tx['vin'].fold<int>(
              0,
              (int sum, dynamic vin) =>
                  sum + ((vin['prevout']?['value'] as int?) ?? 0),
            ) -
            fee;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
      ),
      elevation: 2, // Light shadow for transaction items
      color: Colors.white, // Match button background
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount: $amount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Match text color
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.green), // Arrow icon color
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Receiver: $receiver',
              style: const TextStyle(
                  fontSize: 14, color: Colors.grey), // Grey for secondary text
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionsDialog(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    // Extract transaction details
    final fee = transaction['fee'] ?? 0;

    final sender = (transaction['vin'] != null && transaction['vin'].isNotEmpty)
        ? (transaction['vin'][0]['prevout']?['scriptpubkey_address'] ??
            'Unknown Sender')
        : 'Unknown Sender';

    final receiver =
        transaction['vout'] != null && transaction['vout'].isNotEmpty
            ? (transaction['vout'].firstWhere(
                  (vout) => vout['scriptpubkey_address'] == address,
                  orElse: () => null,
                )?['scriptpubkey_address'] ??
                'Unknown Receiver')
            : 'Unknown Receiver';

    final isReceived = transaction['vout'] != null &&
        transaction['vout']
            .any((vout) => vout['scriptpubkey_address'] == address);

    final amount = isReceived
        ? transaction['vout']
            .where((vout) => vout['scriptpubkey_address'] == address)
            .fold<int>(
              0,
              (int sum, dynamic vout) => sum + ((vout['value'] as int?) ?? 0),
            )
        : transaction['vin'].fold<int>(
              0,
              (int sum, dynamic vin) =>
                  sum + ((vin['prevout']?['value'] as int?) ?? 0),
            ) -
            fee;

    final isConfirmed = transaction['status']?['confirmed'] ?? false;
    final blockHeight =
        isConfirmed ? transaction['status']['block_height'] : 'Unconfirmed';
    final blockTime = isConfirmed
        ? DateTime.fromMillisecondsSinceEpoch(
            (transaction['status']['block_time'] ?? 0) * 1000,
          ).toLocal()
        : 'Unconfirmed';

    // Build the dialog
    showDialog(
      context: context,
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
              color: Colors.green,
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
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReceived
                            ? 'Received Transaction'
                            : 'Sent Transaction',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Sender Information",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: sender)); // Copy text to clipboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied to clipboard: $sender'),
                              duration: const Duration(seconds: 2),
                            ),
                          ); // Optional feedback
                        },
                        child: Text(
                          sender,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Receiver Information",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: receiver)); // Copy text to clipboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied to clipboard: $receiver'),
                              duration: const Duration(seconds: 2),
                            ),
                          ); // Optional feedback
                        },
                        child: Text(
                          receiver,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Transaction Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Amount: ${amount.abs()} sats",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        "Fee: $fee sats",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Confirmation Details",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop();
              },
              label: 'Close',
              backgroundColor: Colors.white,
              textColor: Colors.black,
              icon: Icons.cancel_rounded,
              iconColor: Colors.black,
            ),
          ],
        );
      },
    );
  }
}
