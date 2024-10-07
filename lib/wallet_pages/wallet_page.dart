import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
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

  String address = '';

  int balance = 0;
  int ledBalance = 0;
  int avBalance = 0;
  int currentBlockHeight = 0;

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

    try {
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      print('$connectivityResult');

      if (connectivityResult.contains(ConnectivityResult.none)) {
        print('Offline mode: Loading wallet data from local storage');

        try {
          final savedWallet = await walletService.loadSavedWallet(null);
          setState(() {
            wallet = savedWallet;
          });
        } catch (e) {
          print('No Data Found Locally');
        }

        var addressInfo = await wallet.getAddress(
            addressIndex: const AddressIndex.peek(index: 0));

        // print(addressInfo.address);

        // Attempt to load wallet data from local storage (offline mode)
        _walletData =
            await _walletStorageService.loadWalletData(addressInfo.address);

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

          print('Loaded offline wallet data');
          return; // Exit the function if offline data is loaded successfully
        } else {
          print('Generating address');
          // Fetch and set the address
          var walletAddressInfo = await wallet.getAddress(
            addressIndex: const AddressIndex.peek(index: 0),
          );

          setState(() {
            address = walletAddressInfo.address;
          });
        }
      } else {
        wallet = await walletService.loadSavedWallet(null);
        // print(wallet);
        await walletService.saveLocalData(wallet);
        // If no offline data is available, proceed to fetch online data
        print('No offline data available, fetching from network');

        // Fetch and set the address
        String walletAddress = await walletService.getAddress(wallet);
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
      print('Error loading wallet data: $e');
    } finally {
      setState(() {
        _isLoading = false; // Hide the loading indicator
      });
    }
  }

  Future<void> _fetchCurrentBlockHeight() async {
    int currBlockHeight = await walletService.fetchCurrentBlockHeight();
    setState(() {
      currentBlockHeight = currBlockHeight;
    });
  }

  // Method to handle scanned QR Codes
  void _showTransactionDialog(String recipientAddressStr) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Bitcoin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Recipient: $recipientAddressStr'),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (Sats)',
                  hintText: 'Enter amount in satoshis',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final int amount = int.parse(_amountController.text);
                final String changeAddressStr = address; // Your change address

                await walletService.sendTx(
                  recipientAddressStr,
                  amount,
                  wallet,
                  changeAddressStr,
                );

                // Close the dialog after submitting
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendTx() async {
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
                keyboardType: TextInputType.number, // Numeric input
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
              CustomButton(
                onPressed: () async {
                  final int availableBalance =
                      await walletService.getAvailableBalance(address);
                  final int feeRate = await walletService.getFeeRate();
                  final sendAllBalance = availableBalance - feeRate;

                  if (sendAllBalance > 0) {
                    _amountController.text = sendAllBalance.toString();
                  } else {
                    _amountController.text = 'No balance Available';
                  }
                },
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.orange, // Bitcoin orange color for text
                icon: Icons.send_rounded, // Icon you want to use
                iconColor: Colors.black, // Color for the icon
                label: 'Send All',
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white, // Button text color
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange, // Button text color
              ),
              onPressed: () async {
                final String recipientAddressStr = _recipientController.text;
                final int amount = int.parse(_amountController.text);
                final String changeAddressStr = address;

                await walletService.sendTx(
                    recipientAddressStr, amount, wallet, changeAddressStr);
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
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
          title: const Text('Receive Bitcoin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // Minimize the height of the Column
              children: [
                // Wrap the QR code in a SizedBox or Container with defined constraints
                SizedBox(
                  width: 200, // Explicitly set width and height for the QR code
                  height: 200,
                  child: QrImageView(
                    data: address,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Display the actual address below the QR code
                SelectableText(
                  address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Close'),
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
          title: const Text('Enter PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your 6-digit PIN:'),
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without action
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                String pin = pinController.text;
                if (pin.length == 6) {
                  verifyPin(pinController);
                } else {
                  // Show an error if the PIN is invalid
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid PIN')),
                  );
                }
              },
              child: const Text('Confirm'),
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
            title: const Text('Your Mnemonic'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(savedMnemonic),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop(); // Close the dialog without action
                },
                child: const Text('Cancel'),
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
                  _buildInfoBox('Address', address, () {}),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoBox(
                            'Ledger Balance', '$ledBalance sats', () {}),
                      ),
                      const SizedBox(width: 8), // Add space between the boxes
                      Expanded(
                        child: _buildInfoBox(
                            'Available Balance', '$avBalance sats', () {}),
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
                      foregroundColor: Colors.orange,
                      icon: Icons.remove_red_eye, // Icon for the new button
                      iconColor: Colors.orange,
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
                              Colors.orange, // Bitcoin orange color for text
                          icon: Icons.arrow_upward, // Icon you want to use
                          iconColor: Colors.orange, // Color for the icon
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
                              _showTransactionDialog(recipientAddressStr);
                            }
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.orange, // Bitcoin orange color for text
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
                              Colors.orange, // Bitcoin orange color for text
                          icon: Icons.arrow_downward, // Icon you want to use
                          iconColor: Colors.orange, // Color for the icon
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
  Widget _buildInfoBox(String title, String data, VoidCallback onTap) {
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
                  color: Colors.orange, // Match button text color
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                data,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black, // Black text to match theme
                ),
              ),
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
            const Text(
              'Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange, // Match button text color
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

    final amountReceived = firstVout != null
        ? firstVout['value']?.toString() ?? 'Unknown Amount'
        : 'Unknown Amount';
    final receiver =
        firstVout != null && firstVout['scriptpubkey_address'] != null
            ? firstVout['scriptpubkey_address'] ?? 'Unknown Receiver'
            : 'Unknown Receiver';

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
                  'Amount: $amountReceived',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Match text color
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.orange), // Arrow icon color
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

  void _showTransactionsDialog(BuildContext context, Map<String, dynamic> tx) {
    final theme = Theme.of(context); // Get the current theme
    final isDarkMode =
        theme.brightness == Brightness.dark; // Check if it's dark mode

    // Unwrap the transaction if it is wrapped inside an extra 'txid' key
    if (tx.containsKey('txid') && tx['txid'] is Map) {
      tx = tx['txid'];
    }

    final otherVout = tx['vout'] != null && tx['vout'].isNotEmpty
        ? tx['vout'].firstWhere(
            (vout) => (vout['scriptpubkey_address'] !=
                address), // Check if the address matches
            orElse: () => null,
          )
        : null;

    final fee = tx['fee'];

    final amountSubtract = otherVout != null
        ? otherVout['value']?.toString() ?? 'Unknown Amount'
        : null;

    List<Widget> vinWidgets = [];

    // Safely access vin[0] and prevout for the amount sent and sender address
    if (tx['vin'] != null && tx['vin'].isNotEmpty) {
      for (var vin in tx['vin']) {
        final amountSent = vin['prevout'] != null
            ? vin['prevout']['value']?.toString() ?? 'Unknown Amount'
            : 'Unknown Amount';
        final sender = vin['prevout'] != null
            ? vin['prevout']['scriptpubkey_address'] ?? 'Unknown Sender'
            : 'Unknown Sender';

        final amount = int.parse(amountSent) - int.parse(amountSubtract!) - fee;

        vinWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection:
                            Axis.horizontal, // Enable horizontal scrolling
                        child: Text(
                          'Sender: $sender',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.black87, // Adapt to theme
                          ),
                          maxLines:
                              1, // Optional: Prevent text from wrapping to multiple lines
                          softWrap:
                              false, // Ensure text doesn't wrap to the next line
                          overflow: TextOverflow
                              .visible, // Ensure overflow is handled by scrolling
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.grey),
                    const SizedBox(height: 4),
                    Text(
                      'Amount Sent: $amount',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black87, // Adapt to theme
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(), // Separate each vin with a line
              ],
            ),
          ),
        );
      }
    }

    final blockTime = tx['status'] != null &&
            tx['status']['confirmed'] != null &&
            tx['status']['confirmed']
        ? (tx['status']['block_time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                tx['status']['block_time'] * 1000)
            : 'Unknown Time')
        : 'Unconfirmed Transaction';

    final blockHeight = tx['status'] != null &&
            tx['status']['confirmed'] != null &&
            tx['status']['confirmed']
        ? tx['status']['block_height']
        : 0;

    final confirmations = currentBlockHeight - blockHeight;

    final firstVout = tx['vout'] != null && tx['vout'].isNotEmpty
        ? tx['vout'].firstWhere(
            (vout) => (vout['scriptpubkey_address'] ==
                address), // Check if the address matches
            orElse: () => null,
          )
        : null;

    final amountReceived = firstVout != null
        ? firstVout['value']?.toString() ?? 'Unknown Amount'
        : 'Unknown Amount';
    final receiver =
        firstVout != null && firstVout['scriptpubkey_address'] != null
            ? firstVout['scriptpubkey_address'] ?? 'Unknown Receiver'
            : 'Unknown Receiver';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? theme.colorScheme.surface
              : Colors.white, // Adapt background color
          title: Text(
            'Transaction Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? Colors.white
                  : Colors.black87, // Adapt text color
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                const Text(
                  'Sender Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Column(children: vinWidgets), // Display all vin entries

                const SizedBox(height: 16),
                const Text(
                  'Receiver Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection:
                            Axis.horizontal, // Enable horizontal scrolling
                        child: Text(
                          'Receiver: $receiver',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.black87, // Adapt to theme
                          ),
                          maxLines:
                              1, // Optional: Prevent text from wrapping to multiple lines
                          softWrap:
                              false, // Ensure text doesn't wrap to the next line
                          overflow: TextOverflow
                              .visible, // Ensure overflow is handled by scrolling
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.attach_money, color: Colors.grey),
                    const SizedBox(height: 4),
                    Text(
                      'Amount Received: $amountReceived',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black87, // Adapt text color
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Fee: $fee',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black87, // Adapt text color
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Block Time: $blockTime',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black87, // Adapt text color
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.airplanemode_active, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Block Height: $blockHeight',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black87, // Adapt text color
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      confirmations < 6 && confirmations >= 0
                          ? 'Confirmations: $confirmations'
                          : 'Confirmed',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white70
                            : Colors.black87, // Adapt text color
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Close',
                style: TextStyle(
                  color: theme
                      .colorScheme.secondary, // Use theme's secondary color
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
