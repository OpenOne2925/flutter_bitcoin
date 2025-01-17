import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
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
  String address = '';
  String? _txToSend;
  String? _error = 'No Errors, for now';
  String? _descriptor = 'Descriptor here';

  int balance = 0;
  int ledBalance = 0;
  int avBalance = 0;
  int currentBlockHeight = 0;

  List<Map<String, dynamic>> _transactions = [];
  List<int> _olderValues = []; // Declare a list to store all older values

  bool _isLoading = true;

  late Box<dynamic> descriptorBox;

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _psbtController = TextEditingController();

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  late WalletData? _walletData;
  late Wallet wallet;
  late WalletService walletService;

  final WalletStorageService _walletStorageService = WalletStorageService();

  @override
  void initState() {
    super.initState();

    walletService = WalletService();

    openBoxAndCheckWallet();
  }

  final secureStorage = FlutterSecureStorage();

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// METHODS
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  Future<void> openBoxAndCheckWallet() async {
    // Open the box
    descriptorBox = Hive.box('descriptorBox');

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

    await _syncWallet();
  }

  Future<void> loadWallet() async {
    try {
      wallet = await walletService.createSharedWallet(widget.descriptor);

      setState(() {
        // balance = wallet.getBalance().total.toInt();
        address = wallet
            .getAddress(
              addressIndex: const AddressIndex.peek(index: 0),
            )
            .address
            .toString();
        _descriptor = widget.descriptor;
      });

      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());

      if (connectivityResult.contains(ConnectivityResult.none)) {
        String walletAddress = walletService.getAddress(wallet);
        setState(() {
          address = walletAddress;
        });

        _walletData = await _walletStorageService.loadWalletData(walletAddress);

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
        }
      } else {
        // Fetch the wallet's receive address
        // final wallAddress = walletService.getAddress(walletState!);
        // setState(() {
        //   address = wallAddress;
        // });

        await walletService.saveLocalData(wallet);

        // Fetch the balance of the wallet
        final availableBalance =
            await walletService.getAvailableBalance(address);
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
      }
    } catch (e) {
      // print("Error creating or fetching balance for wallet: $e");
      throw ("Error creating or fetching balance for wallet: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> createWalletFromDescriptor() async {
    try {
      // print('DescriptorWidget: ${widget.descriptor}');

      wallet = await walletService.createSharedWallet(widget.descriptor);

      descriptorBox.put(widget.mnemonic, widget.descriptor);

      await walletService.saveLocalData(wallet);

      // Fetch the wallet's receive address
      final wallAddress = walletService.getAddress(wallet);
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
  void _showTransactionDialog(String recipientAddressStr) async {
    Map<String, dynamic>? selectedPath; // Variable to store the selected path
    int? selectedIndex; // Variable to store the selected path

    List<Map<String, dynamic>> availablePaths = []; // List to store the paths

    if (!mounted) return;

    final externalWalletPolicy = wallet.policies(KeychainKind.externalChain)!;

    walletService.printPrettyJson(externalWalletPolicy.toString());

    final Map<String, dynamic> policy =
        jsonDecode(externalWalletPolicy.asString());

    // print('Bool: $multiSig');
    Mnemonic trueMnemonic = await Mnemonic.fromString(widget.mnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) =
        await walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.asString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];
    print("Fingerprint: $targetFingerprint");

    // Fetch the paths before showing the dialog
    final paths = walletService.extractAllPathsToFingerprint(
      policy,
      targetFingerprint,
    );

    print(paths);

    if (paths.isNotEmpty) {
      availablePaths = paths;
      selectedPath = availablePaths[0]; // Default to the first path
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background color for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: const Text('Send Bitcoin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800], // Slightly darker background
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
                child: Text(
                  'Recipient: $recipientAddressStr',
                  style: TextStyle(
                    color: Colors.orange, // Text color for emphasis
                    fontSize: 16.0, // Slightly larger font size
                    fontWeight: FontWeight.bold, // Bold text
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              // Dropdown for selecting the spending path
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedPath,
                items: availablePaths
                    .asMap()
                    .entries
                    .map(
                      (entry) => DropdownMenuItem<Map<String, dynamic>>(
                        value: entry.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12), // Add padding for better spacing
                          decoration: BoxDecoration(
                            color: selectedPath == entry.value
                                ? Colors.orange
                                    .withOpacity(0.2) // Highlight selected item
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                8), // Rounded corners for each item
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "IDs: ${entry.value['ids'].join(' > ')}",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Indexes: ${entry.value['indexes'].join(' > ')}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (Map<String, dynamic>? newValue) {
                  setState(() {
                    selectedPath = newValue; // Update the selected path
                    selectedIndex =
                        availablePaths.indexOf(newValue!); // Update the index
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Select Spending Path',
                  labelStyle: const TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius:
                        BorderRadius.circular(12), // Match dialog theme
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                dropdownColor:
                    Colors.grey[850], // Match the dialog background color
                style: const TextStyle(
                    color: Colors.white), // Text color inside dropdown
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.white), // Dropdown icon color
              ),
              const SizedBox(height: 16),
              InkwellButton(
                onTap: () async {
                  try {
                    final int availableBalance =
                        await walletService.getAvailableBalance(address);

                    final int sendAllBalance =
                        await walletService.calculateSendAllBalance(
                      recipientAddress: recipientAddressStr,
                      wallet: wallet,
                      availableBalance: availableBalance,
                      walletService: walletService,
                    );

                    _amountController.text = sendAllBalance.toString();
                    // print('Final Send All Balance: $sendAllBalance');
                  } catch (e) {
                    print('Error: $e');
                    _amountController.text = 'No balance Available';
                  }
                },
                label: 'Send All',
                icon: Icons.account_balance_wallet_rounded,
                backgroundColor: Colors.orange,
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
                  final int amount = int.parse(_amountController.text);

                  final result = await walletService.createPartialTx(
                    _descriptor.toString(),
                    widget.mnemonic,
                    recipientAddressStr,
                    BigInt.from(amount),
                    selectedIndex,
                    availablePaths,
                  );

                  setState(() {
                    _txToSend = result;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transaction created successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
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
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendTx() async {
    Map<String, dynamic>? selectedPath; // Variable to store the selected path
    int? selectedIndex; // Variable to store the selected path

    List<Map<String, dynamic>> availablePaths = []; // List to store the paths

    if (!mounted) return;

    final externalWalletPolicy = wallet.policies(KeychainKind.externalChain)!;

    walletService.printPrettyJson(externalWalletPolicy.toString());

    final Map<String, dynamic> policy =
        jsonDecode(externalWalletPolicy.asString());

    // print('Bool: $multiSig');
    Mnemonic trueMnemonic = await Mnemonic.fromString(widget.mnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) =
        await walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.asString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];
    print("Fingerprint: $targetFingerprint");

    // Fetch the paths before showing the dialog
    final paths = walletService.extractAllPathsToFingerprint(
      policy,
      targetFingerprint,
    );

    print(paths);

    if (paths.isNotEmpty) {
      availablePaths = paths;
      selectedPath = availablePaths[0]; // Default to the first path
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background color for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: const Text('Sending Menu'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
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
                  // Dropdown for selecting the spending path
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedPath,
                    items: availablePaths
                        .asMap()
                        .entries
                        .map(
                          (entry) => DropdownMenuItem<Map<String, dynamic>>(
                            value: entry.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal:
                                      12), // Add padding for better spacing
                              decoration: BoxDecoration(
                                color: selectedPath == entry.value
                                    ? Colors.orange.withOpacity(
                                        0.2) // Highlight selected item
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                    8), // Rounded corners for each item
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "IDs: ${entry.value['ids'].join(' > ')}",
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Indexes: ${entry.value['indexes'].join(' > ')}",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (Map<String, dynamic>? newValue) {
                      setState(() {
                        selectedPath = newValue; // Update the selected path
                        selectedIndex = availablePaths
                            .indexOf(newValue!); // Update the index
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Select Spending Path',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white),
                        borderRadius:
                            BorderRadius.circular(12), // Match dialog theme
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.orange),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor:
                        Colors.grey[850], // Match the dialog background color
                    style: const TextStyle(
                        color: Colors.white), // Text color inside dropdown
                    icon: const Icon(Icons.arrow_drop_down,
                        color: Colors.white), // Dropdown icon color
                  ),

                  const SizedBox(height: 16),
                  InkwellButton(
                    onTap: () async {
                      try {
                        final int availableBalance =
                            await walletService.getAvailableBalance(address);
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
                      } catch (e) {
                        print('Error: $e');
                        _amountController.text = 'No balance Available';
                      }
                    },
                    label: 'Send All',
                    icon: Icons.account_balance_wallet_rounded,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                    iconColor: Colors.white,
                  ),
                ],
              );
            },
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

                  final result = await walletService.createPartialTx(
                    _descriptor.toString(),
                    widget.mnemonic,
                    recipientAddressStr,
                    BigInt.from(amount),
                    selectedIndex, // Use the selected path
                    availablePaths,
                  );

                  setState(() {
                    _txToSend = result;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transaction created successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
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
              backgroundColor: Colors.orange,
              textColor: Colors.white,
            ),
          ],
        );
      },
    );
  }

  void _signTransaction() async {
    Map<String, dynamic>? selectedPath; // Variable to store the selected path
    int? selectedIndex; // Variable to store the selected path

    List<Map<String, dynamic>> availablePaths = []; // List to store the paths

    if (!mounted) return;

    final externalWalletPolicy = wallet.policies(KeychainKind.externalChain)!;
    final Map<String, dynamic> policy =
        jsonDecode(externalWalletPolicy.asString());

    // print('Bool: $multiSig');
    Mnemonic trueMnemonic = await Mnemonic.fromString(widget.mnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) =
        await walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.asString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];
    print("Fingerprint: $targetFingerprint");

    // Fetch the paths before showing the dialog
    final paths = walletService.extractAllPathsToFingerprint(
      policy,
      targetFingerprint,
    );

    if (paths.isNotEmpty) {
      availablePaths = paths;
      selectedPath = availablePaths[0]; // Default to the first path
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign MultiSig Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Adjust the size of the dialog
            children: [
              // TextField for Recipient Address
              TextField(
                controller: _psbtController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Psbt',
                  hintText: 'Enter psbt',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 16),
              // Dropdown for selecting the spending path
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedPath,
                items: availablePaths
                    .asMap()
                    .entries
                    .map(
                      (entry) => DropdownMenuItem<Map<String, dynamic>>(
                        value: entry.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12), // Add padding for better spacing
                          decoration: BoxDecoration(
                            color: selectedPath == entry.value
                                ? Colors.orange
                                    .withOpacity(0.2) // Highlight selected item
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                8), // Rounded corners for each item
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "IDs: ${entry.value['ids'].join(' > ')}",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Indexes: ${entry.value['indexes'].join(' > ')}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (Map<String, dynamic>? newValue) {
                  setState(() {
                    selectedPath = newValue; // Update the selected path
                    selectedIndex =
                        availablePaths.indexOf(newValue!); // Update the index
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Select Spending Path',
                  labelStyle: const TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius:
                        BorderRadius.circular(12), // Match dialog theme
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                dropdownColor:
                    Colors.grey[850], // Match the dialog background color
                style: const TextStyle(
                    color: Colors.white), // Text color inside dropdown
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.white), // Dropdown icon color
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () async {
                try {
                  log("PSBT Raw: ${_psbtController.text}");

                  final psbtString = _psbtController.text;

                  // print("Decoded Transaction: $decoded");
                  // print("Mnemonic: " + widget.mnemonic);

                  final result = await walletService.signBroadcastTx(
                    psbtString,
                    _descriptor.toString(),
                    widget.mnemonic,
                    selectedIndex,
                  );

                  setState(() {
                    _txToSend = result;
                  });

                  // Show a success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transaction created successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Assuming `e` is the exception
                  final errorMessage = e.toString();

                  // Using a regular expression to extract the parts
                  final regex = RegExp(r'Error:\s(.+?)\spsbt:\s(.+)');
                  final match = regex.firstMatch(errorMessage);

                  if (match != null) {
                    _error = match.group(1) ??
                        "Unknown error"; // Extract the error part
                    _txToSend = match.group(2) ?? ""; // Extract the PSBT part
                  } else {
                    // Handle cases where the format doesn't match
                    _error = "Unexpected error format: $e";
                    _txToSend = "";
                  }
                  // Show error message in a snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _error.toString(),
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

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
              color: Colors.orange, // Highlighted title color
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
                        color: Colors.orange, // Highlighted icon color
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

  Future<void> _extractOlder(String descriptor) async {
    final regExp =
        RegExp(r'older\((\d+)\).*?pk\(\[.*?]([tx]p(?:rv|ub)[a-zA-Z0-9]+)');
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

  Map<String, List<Map<String, dynamic>>> extractAllPathsAndIdsForFingerprint(
      Map<String, dynamic> policy, String targetFingerprint) {
    Map<String, List<Map<String, dynamic>>> resultPaths = {};

    void traverse(dynamic node, List<int> currentPath, List<String> idPath) {
      if (node == null) return;

      // Check if the node contains the target fingerprint
      if (node['keys'] != null) {
        for (var key in node['keys']) {
          if (key['fingerprint'] == targetFingerprint) {
            // Add the path and IDs to the result
            resultPaths.putIfAbsent(node['id'], () => []).add({
              'path': Uint32List.fromList(currentPath),
              'ids': [...idPath, node['id']],
            });
          }
        }
      }

      // Recursively traverse children if the node has items
      if (node['items'] != null) {
        for (int i = 0; i < node['items'].length; i++) {
          traverse(
            node['items'][i],
            [...currentPath, i],
            [...idPath, node['id']],
          );
        }
      }
    }

    // Start traversing from the root policy
    traverse(policy, [], []);

    return resultPaths;
  }

  Future<void> _syncWallet() async {
    _descriptor = widget.descriptor;

    walletService.printInChunks(_descriptor.toString());

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    // print(connectivityResult);

    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _extractOlder(widget.descriptor);

      String walletAddress = walletService.getAddress(wallet);
      setState(() {
        address = walletAddress;
      });

      _walletData = await _walletStorageService.loadWalletData(walletAddress);

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
      }
    } else {
      // print('walletState: $walletState');
      await walletService.syncWallet(wallet);

      await _fetchCurrentBlockHeight();

      await _extractOlder(widget.descriptor);

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
    }
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
              color: Colors.orange,
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
              backgroundColor: Colors.orange,
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
              'Your Private Data',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange, // Highlighted title color
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
                      color: Colors.orange, // Border color for emphasis
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
                          color: Colors.orange, // Highlighted icon color
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
                const SizedBox(height: 16),
                const Text(
                  'Here is your saved descriptor:',
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
                      color: Colors.orange, // Border color for emphasis
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _descriptor.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70, // Softer text color
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8), // Space between text and icon
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.orange, // Highlighted icon color
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _descriptor.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  const Text('Descriptor copied to clipboard!'),
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
                backgroundColor: Colors.orange,
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

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// MAIN WIDGET
  ///
  ///
  ///
  ///
  ///
  ///
  ///

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
                  _buildInfoBox(
                    'Address',
                    address,
                    () {
                      // Handle tap events for Address
                    },
                    showCopyButton: true,
                  ),
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
                  _buildInfoBox(
                    'MultiSig Transactions',
                    _txToSend != null
                        ? _txToSend.toString()
                        : 'No transactions to sign',
                    () {
                      // Handle tap events for the transaction content if needed
                      _signTransaction();
                    },
                    showCopyButton: true,
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
                    CustomButton(
                      onPressed: () {
                        _showPinDialog(context);
                      },
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      icon: Icons.remove_red_eye, // Icon for the new button
                      iconColor: Colors.orange,
                      label: 'Private Data',
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

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// WIDGET BUILD HELPERS
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  // Box for displaying general wallet info with onTap functionality
  Widget _buildInfoBox(String title, String data, VoidCallback onTap,
      {bool showCopyButton = false}) {
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
                      icon: const Icon(Icons.copy, color: Colors.orange),
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
        : 0;

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

        final amount =
            int.parse(amountSent) - int.parse(amountSubtract.toString()) - fee;

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

    // int blockHeight = tx['status'] != null &&
    //         tx['status']['confirmed'] != null &&
    //         tx['status']['confirmed']
    //     ? tx['status']['block_height']
    //     : 0;

    int blockHeight = tx['locktime'];

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

                    // Calculate the estimated time in minutes (20 minutes per block)
                    int remainingMinutes = remainingBlocks * 20;

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
                                  : '$remainingBlocks blocks remaining! \nEstimated time remaining: \n$estimatedTime',
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
