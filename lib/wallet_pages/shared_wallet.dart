import 'package:flutter/material.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/qr_scanner_page.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:hive/hive.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SharedWallet extends StatefulWidget {
  final String descriptor;
  final String mnemonic;

  const SharedWallet({
    super.key,
    required this.descriptor,
    required this.mnemonic,
  });

  @override
  SharedWalletState createState() => SharedWalletState();
}

class SharedWalletState extends State<SharedWallet> {
  late WalletService walletService;

  String address = '';
  String? _txToSend;

  int balance = 0;
  int ledBalance = 0;
  int avBalance = 0;
  int currentBlockHeight = 0;
  int older = 0;

  List<Map<String, dynamic>> _transactions = [];
  List<int> _olderValues = []; // Declare a list to store all older values

  bool _isLoading = true;

  late Box<dynamic> descriptorBox;

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _psbtController = TextEditingController();

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  late Wallet wallet;

  @override
  void initState() {
    super.initState();

    walletService = WalletService();

    openBoxAndCheckWallet();
  }

  Future<void> openBoxAndCheckWallet() async {
    // Open the box (for example using Hive)
    descriptorBox = await Hive.openBox('wallet_descriptors');

    // print('Retrieving descriptor with key: ${widget.mnemonic}');

    // After the box is opened, proceed with checking for the existing wallet
    var existingDescriptor = descriptorBox.get(widget.mnemonic);

    // print('Retrieved descriptor: $existingDescriptor');

    if (existingDescriptor != null) {
      // print('Wallet with this mnemonic already exists.');
      loadWallet();
    } else {
      createWalletFromDescriptor();
    }

    // await _syncWallet();
  }

  Future<void> loadWallet() async {
    try {
      final internalDescriptor = replaceAllDerivationPaths(widget.descriptor);

      wallet = await walletService.createSharedWallet(
        widget.descriptor,
        internalDescriptor,
        widget.mnemonic,
        Network.Testnet,
        null,
      );

      // descriptorBox.put('wallet_${widget.mnemonic}', widget.descriptor);

      // Fetch the wallet's receive address
      final wallAddress = await walletService.getAddress(wallet);
      setState(() {
        address = wallAddress;
      });

      // Fetch the balance of the wallet
      final availableBalance = await walletService.getAvailableBalance(address);
      setState(() {
        avBalance = availableBalance; // Set the balance
      });

      final ledgerBalance = await walletService.getLedgerBalance(address);
      setState(() {
        ledBalance = ledgerBalance; // Set the balance
      });

      // Fetch and set the transactions
      List<Map<String, dynamic>> transactions =
          await walletService.getTransactions(address);
      setState(() {
        _transactions = transactions;
      });

      await _syncWallet();
    } catch (e) {
      // print("Error creating or fetching balance for wallet: $e");
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String replaceAllDerivationPaths(String descriptor) {
    // Define the regular expression to match the derivation path [fingerprint/84'/1'/0'/0/0]
    final pattern = RegExp(r"\[\w{8}/84\'/1\'/0\'/0/\d\]");

    // Replace all occurrences of the matched pattern with [fingerprint/84'/1'/0'/1/0]
    String modifiedDescriptor = descriptor.replaceAllMapped(pattern, (match) {
      // Extract the original matched string
      String matchedPath = match.group(0)!;

      // Modify the part that needs to be changed from /0/ to /1/
      String newPath = matchedPath.replaceFirst("/0/", "/1/");

      return newPath; // Return the new modified path
    });

    return modifiedDescriptor; // Return the fully modified descriptor
  }

  Future<void> createWalletFromDescriptor() async {
    try {
      // print('Descriptor: ' + widget.descriptor);

      final internalDescriptor = replaceAllDerivationPaths(widget.descriptor);

      // print(internalDescriptor);

      // final pubKey =
      //     await walletService.getSecretKeyfromMnemonic(widget.mnemonic);

      // final result = await pubKey.asPublic();

      wallet = await walletService.createSharedWallet(
        widget.descriptor,
        internalDescriptor,
        widget.mnemonic,
        Network.Testnet,
        null,
      );

      descriptorBox.put('wallet_${widget.mnemonic}', widget.descriptor);

      // Fetch the wallet's receive address
      final wallAddress = await walletService.getAddress(wallet);
      setState(() {
        address = wallAddress;
      });

      // Fetch the balance of the wallet
      final availableBalance = await walletService.getAvailableBalance(address);
      setState(() {
        avBalance = availableBalance; // Set the available balance
      });

      final ledgerBalance = await walletService.getLedgerBalance(address);
      setState(() {
        ledBalance = ledgerBalance; // Set the ledger balance
      });

      // Fetch and set the transactions
      List<Map<String, dynamic>> transactions =
          await walletService.getTransactions(address);
      setState(() {
        _transactions = transactions;
      });

      await _syncWallet();
    } catch (e) {
      // print("Error creating or fetching balance for wallet: $e");
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
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

                _txToSend = await walletService.createPartialTx(
                  recipientAddressStr,
                  amount,
                  wallet,
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
          title: const Text('Sending Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Adjust the size of the dialog
            children: [
              TextFormField(
                controller: _recipientController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Recipient Address',
                  hintText: 'Enter Recipient\'s Address',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Amount (Sats)',
                  hintText: 'Enter Amount',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                icon: Icons.send_rounded,
                iconColor: Colors.black,
                label: 'Send All',
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () async {
                final String recipientAddressStr = _recipientController.text;
                final int amount = int.parse(_amountController.text);

                _txToSend = await walletService.createPartialTx(
                  recipientAddressStr,
                  amount,
                  wallet,
                );

                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _signTransaction() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sending Menu'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Adjust the size of the dialog
            children: [
              // TextField for Recipient Address
              TextField(
                controller: _psbtController,
                decoration: const InputDecoration(
                  labelText: 'Psbt',
                  hintText: 'Enter psbt',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await walletService.syncWallet(wallet);

                // print("PSBT Raw: ${_psbtController.text}");

                final decoded = _psbtController.text;

                // print("Decoded Transaction: $decoded");
                // print("Mnemonic: " + widget.mnemonic);

                final psbt = PartiallySignedTransaction(psbtBase64: decoded);
                await walletService.signBroadcastTx(psbt, wallet);

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

  Future<void> _extractOlderWithPrivateKey(String descriptor) async {
    final regExp =
        RegExp(r'older\((\d+)\).*?pk\(\[.*?](tp(?:rv|ub)[a-zA-Z0-9]+)');
    final matches = regExp.allMatches(descriptor);

    // Clear the list before populating it with new values
    List<int> newOlderValues = [];

    for (var match in matches) {
      String olderValue = match.group(1)!;
      // print('Found older value: $olderValue'); // Print each found value
      newOlderValues.add(int.parse(olderValue));
    }

    // Update state with the new list
    setState(() {
      _olderValues = newOlderValues;
    });
  }

  Future<void> _syncWallet() async {
    // print('Descriptor: ' + widget.descriptor);

    await walletService.syncWallet(wallet);

    await _fetchCurrentBlockHeight();

    await _extractOlderWithPrivateKey(widget.descriptor);

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
      title: const Text('Shared Wallet Page'),
      body: RefreshIndicator(
        key: _refreshIndicatorKey, // Assign the GlobalKey to RefreshIndicator
        onRefresh:
            _syncWallet, // Call this method when the user pulls to refresh
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  // Display wallet address
                  _buildInfoBox('Address', address, () {
                    // Handle tap events for Address
                  }),
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
                  const SizedBox(height: 8), // Add some spacing
                  _buildInfoBox('Transaction to Sign', _txToSend.toString(),
                      () {
                    // Handle tap events for the transaction content if needed
                    _signTransaction();
                  }),
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
                      foregroundColor: Colors.black,
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
                            _sendTx();
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.orange, // Bitcoin orange color for text
                          icon: Icons.arrow_upward, // Icon you want to use
                          iconColor: Colors.orange, // Color for the icon
                        ),
                        const SizedBox(width: 8),
                        // Scan To Send Button
                        CustomButton(
                          onPressed: () async {
                            // Handle scanning address functionality
                            final recipientAddressStr = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const QRScannerPage()),
                            );

                            // If a valid Bitcoin address was scanned, show the transaction dialog
                            if (recipientAddressStr != null) {
                              // Show the transaction dialog after the scanning
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
                        // Receive Button
                        CustomButton(
                          onPressed: () {
                            // Handle receive functionality
                            _showQRCodeDialog(address); // Show the QR code
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

    int blockHeight = tx['status'] != null &&
            tx['status']['confirmed'] != null &&
            tx['status']['confirmed']
        ? tx['status']['block_height']
        : 0;

    int confirmations = blockHeight == 0 ? 0 : currentBlockHeight - blockHeight;

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
                          : confirmations < 0
                              ? 'Unconfirmed'
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
                Column(
                  children: _olderValues.map((olderValue) {
                    // Calculate the number of remaining blocks
                    int remainingBlocks = olderValue - confirmations;

                    // Calculate the estimated time in minutes (10 minutes per block)
                    int remainingMinutes = remainingBlocks * 10;

                    // Convert minutes to a more readable format (e.g., days, hours, minutes)
                    int days = remainingMinutes ~/ (60 * 24);
                    int hours = (remainingMinutes % (60 * 24)) ~/ 60;
                    int minutes = remainingMinutes % 60;

                    // Format the estimated time remaining
                    String estimatedTime = days > 0
                        ? '$days days, $hours hours, $minutes minutes'
                        : hours > 0
                            ? '$hours hours, $minutes minutes'
                            : '$minutes minutes';

                    return Row(
                      children: [
                        const Icon(Icons.lock_clock, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          confirmations < 1
                              ? 'Timelock not started yet'
                              : confirmations > olderValue
                                  ? 'Timelock $olderValue expired! ETA: $confirmations'
                                  : '$remainingBlocks blocks remaining! \nEstimated time remaining: $estimatedTime',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
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
