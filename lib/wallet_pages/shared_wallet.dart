import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/qr_scanner_page.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// SharedWallet Page
///
/// This class represents a shared Bitcoin wallet page where users can:
/// - View wallet details such as address, balance, and transactions.
/// - Create and sign multi-signature transactions.
/// - Explore spending paths and check available UTXOs.
/// - Interact with the wallet using QR codes for sending and receiving Bitcoin.
///
/// ### Features and Functionalities:
///
/// #### Wallet Initialization
/// - **`openBoxAndCheckWallet`**: Opens the Hive box and checks if the wallet already exists.
/// - **`createWalletFromDescriptor`**: Creates a wallet from a given descriptor and saves it locally.
/// - **`loadWallet`**: Loads an existing wallet and syncs it with the blockchain.
///
/// #### Wallet Sync and Data Management
/// - **`_syncWallet`**: Synchronizes the wallet with the blockchain, fetching balances and transactions.
/// - **`_fetchCurrentBlockHeight`**: Retrieves the current blockchain height for transaction management.
///
/// #### Transaction Management
/// - **`_sendTx`**: Handles transaction creation and signing, including multi-signature paths and time-locked transactions.
/// - **`_sortTransactionsByConfirmations`**: Sorts transactions by block confirmation time.
///
/// #### User Interaction and Dialogs
/// - **`_showQRCodeDialog`**: Displays the wallet's QR code for receiving Bitcoin.
/// - **`_showPinDialog`**: Prompts the user to enter their PIN for accessing private data.
/// - **`_showPathsDialog`**: Displays all available spending paths, including multi-signature and time-locked options.
/// - **`_showTransactionsDialog`**: Displays detailed information about a specific transaction.
///
/// #### Utilities
/// - **`verifyPin`**: Verifies the entered PIN and displays the user's private data (e.g., mnemonic and descriptor).
/// - **`_buildInfoBox`**: Creates reusable UI elements for displaying wallet details.
/// - **`_buildTransactionsBox`**: Builds a scrollable view of the wallet's transactions.
/// - **`_buildTransactionItem`**: Formats and displays individual transaction items.
///
/// ### Widgets
/// - **`BaseScaffold`**: Provides a consistent layout with a gradient background and navigation bar.
/// - **`CustomButton`**: Styled button used throughout the app for actions like sending, receiving, and viewing data.
/// - **`InkwellButton`**: Alternative button style for dialog actions.
///
/// ### Interaction Flow
/// 1. **Initialization**:
///    - The page initializes by checking if the wallet exists and syncing it with the blockchain.
///    - If the wallet doesn't exist, it is created using the provided descriptor and mnemonic.
/// 2. **Display Wallet Details**:
///    - The UI displays wallet details such as the address, balance, and transactions.
/// 3. **Transaction Management**:
///    - Users can create transactions, explore spending paths, and sign multi-signature transactions.
/// 4. **Spending Paths**:
///    - Users can view all available paths for spending UTXOs, including conditions like time-locks and multi-signature thresholds.
/// 5. **Receive and Send Bitcoin**:
///    - Users can receive Bitcoin using QR codes and send Bitcoin by specifying an address and amount.
///
/// ### Notes:
/// - The class heavily relies on the `bdk_flutter` library for Bitcoin wallet functionalities.
/// - Hive is used for local data storage, ensuring offline availability.
/// - Connectivity checks are performed to handle both online and offline use cases.
///
/// ### Dependencies:
/// - `bdk_flutter`: For wallet management and transaction creation.
/// - `hive_flutter`: For local data storage.
/// - `connectivity_plus`: To check the network connectivity status.
/// - `flutter_secure_storage`: For securely storing sensitive user data.
/// - `qr_flutter`: For generating QR codes.
///
/// ### UI Highlights:
/// - A clean, consistent design with rounded cards and a gradient background.
/// - Dynamic updates to the UI based on wallet data and user interactions.
/// - Accessibility features such as copy-to-clipboard functionality and scrollable transaction lists.

class SharedWallet extends StatefulWidget {
  final String descriptor;
  final String mnemonic;
  final List<Map<String, String>> pubKeysAlias;
  final String? descriptorName;

  const SharedWallet({
    super.key,
    required this.descriptor,
    required this.mnemonic,
    required this.pubKeysAlias,
    this.descriptorName,
  });

  @override
  SharedWalletState createState() => SharedWalletState();
}

class SharedWalletState extends State<SharedWallet> {
  String address = '';
  String? _txToSend;
  String? _descriptor = 'Descriptor here';
  String _descriptorName = "";

  late DateTime _lastRefreshed;
  late Timer _timer;
  String _elapsedTime = '';

  int ledBalance = 0;
  int avBalance = 0;
  double ledCurrencyBalance = 0.0;
  double avCurrencyBalance = 0.0;

  DateTime? _timeStamp;

  List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = true;

  bool showInSatoshis = true; // Toggle display state
  bool isPubKeyVisible = false;

  int _currentHeight = 0;

  List<String> signersList = [];

  late Box<dynamic> descriptorBox;

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _psbtController = TextEditingController();
  final TextEditingController _signingAmountController =
      TextEditingController();

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  int avgBlockTime = 0;
  List<dynamic> utxos = [];

  late WalletData? _walletData;
  late Wallet wallet;
  late SettingsProvider settingsProvider;
  late WalletService walletService;
  late List<Map<String, dynamic>> spendingPaths;
  late Map<String, dynamic> policy;
  late Policy externalWalletPolicy;
  late String myFingerPrint;
  late String myAlias;
  late String myPubKey;
  late List<Map<String, dynamic>> mySpendingPaths;
  final TextEditingController _pubKeyController = TextEditingController();

  final WalletStorageService _walletStorageService = WalletStorageService();

  bool isInitialized = false;

  @override
  void initState() {
    super.initState();

    walletService = WalletService();
    settingsProvider = SettingsProvider();

    setState(() {
      _lastRefreshed = DateTime.now();
      _elapsedTime = 'Just now'; // Reset elapsed time on refresh
    });

    openBoxAndCheckWallet().then((_) {
      _initializeSpendingPaths();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

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

    String? existingDescriptor;

    print('Widget list: ${widget.pubKeysAlias}');
    print(widget.descriptorName);

    for (var i = 0; i < descriptorBox.length; i++) {
      final key = descriptorBox.keyAt(i); // Get the key
      final value = descriptorBox.getAt(i); // Get the value

      if (value != null) {
        try {
          // Decode the JSON string into a Map
          Map<String, dynamic> valueMap = jsonDecode(value);

          // Check if the "descriptor" matches
          if (valueMap['descriptor'] == widget.descriptor) {
            print('Match found for key: $key');
            walletService.printInChunks('Matching Value: $value');

            // final keyParts = key.split('_descriptor');
            // final descriptorName = keyParts.length > 1
            //     ? keyParts[1].replaceFirst('_', '')
            //     : 'Unnamed Descriptor';

            setState(() {
              final newName = walletService.generateRandomName();

              _descriptorName = widget.descriptorName!.isNotEmpty
                  ? widget.descriptorName!
                  : newName;
            });

            final newKey = key.replaceFirst(
                RegExp(r'_descriptor_.+'), '_descriptor_$_descriptorName');

            final Map<String, dynamic> newValueMap = {
              'descriptor': widget.descriptor,
              'pubKeysAlias': widget.pubKeysAlias,
            };

            print('_descriptorName: $_descriptorName');

            final String newValue = jsonEncode(newValueMap);

            // Remove the old record and insert the updated one
            descriptorBox.delete(key); // Remove the old key-value pair

            descriptorBox.put(newKey, newValue); // Add the new key-value pair

            print('Updated key: $newKey');
            print('New value stored: $newValue');

            existingDescriptor = valueMap['descriptor'];
            break; // Stop iterating if a match is found
          }
        } catch (e) {
          print('Error decoding value for key $key: $e');
        }
      } else {
        print('Value for key $key is null.');
      }
    }

    // walletService.printInChunks(
    //     'Retrieved descriptor: ${existingDescriptor!['descriptor']}');

    if (existingDescriptor != null) {
      // print('Wallet with this mnemonic already exists.');
      await loadWallet();
    } else {
      await createWalletFromDescriptor();
    }

    await _syncWallet();
  }

  Future<void> loadWallet() async {
    print('Loading');
    try {
      wallet = await walletService.createSharedWallet(widget.descriptor);

      setState(() {
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
            _currentHeight = _walletData!.currentHeight;
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

        Map<String, int> balance =
            await walletService.getBitcoinBalance(address);

        setState(() {
          avBalance = balance['confirmedBalance']!; // Set the available balance
          ledBalance = balance['pendingBalance']!; // Set the ledger balance
        });

        await _fetchCurrentBlockHeight();

        // Fetch and set the transactions
        List<Map<String, dynamic>> transactions =
            await walletService.getTransactions(address);
        transactions = walletService.sortTransactionsByConfirmations(
          transactions,
          _currentHeight,
        );

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
      print('Creating');
      // print('DescriptorWidget: ${widget.descriptor}');

      wallet = await walletService.createSharedWallet(widget.descriptor);

      // Combine descriptor and pubKeysAlias
      final combinedValue = jsonEncode({
        'descriptor': widget.descriptor,
        'pubKeysAlias': widget.pubKeysAlias,
      });

      setState(() {
        final newName = walletService.generateRandomName();

        _descriptorName = widget.descriptorName!.isNotEmpty
            ? widget.descriptorName!
            : newName;
      });

      final compositeKey = '${widget.mnemonic}_descriptor_$_descriptorName';

      descriptorBox.put(compositeKey, combinedValue);

      await walletService.saveLocalData(wallet);

      // Fetch the wallet's receive address
      final wallAddress = walletService.getAddress(wallet);
      setState(() {
        address = wallAddress;
      });

      Map<String, int> balance = await walletService.getBitcoinBalance(address);

      setState(() {
        avBalance = balance['confirmedBalance']!; // Set the available balance
        ledBalance = balance['pendingBalance']!; // Set the ledger balance
      });

      // Fetch and set the transactions
      List<Map<String, dynamic>> transactions =
          await walletService.getTransactions(address);
      transactions = walletService.sortTransactionsByConfirmations(
        transactions,
        _currentHeight,
      );

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

  /// Helper method to extract wallet policies and spending paths
  Future<void> _initializeSpendingPaths() async {
    try {
      // Extract wallet policies
      externalWalletPolicy = wallet.policies(KeychainKind.externalChain)!;
      policy = jsonDecode(externalWalletPolicy.asString());

      // Convert mnemonic to object
      Mnemonic trueMnemonic = await Mnemonic.fromString(widget.mnemonic);

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

      print('pubkey: $receivingPublicKey');

      // Extract fingerprint
      final RegExp regex = RegExp(r'\[([^\]]+)\]');
      final Match? match = regex.firstMatch(receivingPublicKey.asString());

      // Extract spending paths
      setState(() {
        spendingPaths = walletService.extractAllPaths(policy);
        myFingerPrint = match!.group(1)!.split('/')[0];
        myAlias = walletService.getAliasesFromFingerprint(
            widget.pubKeysAlias, [myFingerPrint]).first;
        mySpendingPaths =
            walletService.extractDataByFingerprint(policy, myFingerPrint);
        myPubKey = receivingPublicKey.toString();
        _pubKeyController.text = myPubKey;

        isInitialized = true; // Mark as loaded
      });

      print('myAlias: $myAlias');
    } catch (e) {
      print("Error initializing spending paths: $e");
    }
  }

  Future<void> _fetchCurrentBlockHeight() async {
    int currentHeight = await walletService.fetchCurrentBlockHeight();

    DateTime? blockTimestamp = await walletService.fetchBlockTimestamp();

    setState(() {
      _currentHeight = currentHeight;
      _timeStamp = blockTimestamp;
    });
  }

  void _sendTx(bool isCreating, {String? recipientAddressQr}) async {
    if (recipientAddressQr != null) {
      setState(() {
        _recipientController.text = recipientAddressQr;
      });
    }

    Map<String, dynamic>? selectedPath; // Variable to store the selected path
    int? selectedIndex; // Variable to store the selected path

    if (!mounted) return;

    final extractedData =
        walletService.extractDataByFingerprint(policy, myFingerPrint);

    if (extractedData.isNotEmpty) {
      selectedPath = extractedData[0]; // Default to the first path
    }

    // print('extractedData: $extractedData');

    List<String>? signers;

    PartiallySignedTransaction psbt;

    bool isSelectable = true;

    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background color for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title:
              Text(isCreating ? 'Sending Menu' : 'Sign MultiSig Transaction'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Adjust the size of the dialog
                      children: [
                        TextFormField(
                          readOnly: !isCreating,
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

                        Visibility(
                          visible: !isCreating,
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _psbtController,
                                onFieldSubmitted: (event) async {
                                  try {
                                    psbt = await PartiallySignedTransaction
                                        .fromString(_psbtController.text);

                                    Transaction result = psbt.extractTx();

                                    final outputs = result.output();

                                    signers =
                                        walletService.getSignersFromPsbt(psbt);

                                    final signersAliases =
                                        walletService.getAliasesFromFingerprint(
                                            widget.pubKeysAlias, signers!);

                                    bool isInternalTransaction = false;

                                    int totalSpent = 0;

                                    isInternalTransaction = await walletService
                                        .areEqualAddresses(outputs);

                                    Address? receiverAddress;

                                    for (final output in outputs) {
                                      receiverAddress = await walletService
                                          .getAddressFromScriptOutput(output);

                                      // TODO: Do not add change address

                                      print(
                                          'receiverAddress: $receiverAddress');

                                      if (isInternalTransaction) {
                                        totalSpent += output.value.toInt();
                                      } else if (receiverAddress.asString() !=
                                          address) {
                                        totalSpent += output.value.toInt();
                                      }
                                    }

                                    setState(() {
                                      _signingAmountController.text =
                                          totalSpent.toString();
                                      signersList = signersAliases;
                                      _recipientController.text =
                                          receiverAddress.toString();
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invalid PSBT: $e',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }

                                  // print("Total spent: $totalSpent");

                                  // walletService.printInChunks(psbt.asString());
                                },
                                decoration:
                                    CustomTextFieldStyles.textFieldDecoration(
                                  context: context,
                                  labelText: 'Psbt',
                                  hintText: 'Enter psbt',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (signersList.isNotEmpty)
                          Visibility(
                            visible: signersList.isNotEmpty,
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 6.0,
                                  children: signersList.map((signer) {
                                    return Chip(
                                      label: Text(
                                        signer,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.blue,
                                      avatar: Icon(Icons.verified,
                                          color: Colors.white),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),

                        isCreating
                            ? TextFormField(
                                controller: _amountController,
                                onFieldSubmitted: (value) {
                                  setState(() {
                                    // print('Editing');
                                  });
                                },
                                decoration:
                                    CustomTextFieldStyles.textFieldDecoration(
                                  context: context,
                                  labelText: 'Amount (Sats)',
                                  hintText: 'Enter Amount',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                keyboardType: TextInputType.number,
                              )
                            : TextFormField(
                                controller: _signingAmountController,
                                readOnly: true,
                                onChanged: (value) {
                                  setState(() {
                                    // print('Editing');
                                  });
                                },
                                decoration:
                                    CustomTextFieldStyles.textFieldDecoration(
                                  context: context,
                                  labelText: 'Amount (Sats)',
                                  hintText: 'Enter Amount',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                keyboardType: TextInputType.number,
                              ),

                        const SizedBox(height: 16),

                        // Dropdown for selecting the spending path
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedPath,
                          items: extractedData.map((data) {
                            // Check if the item meets the condition
                            isSelectable = walletService.checkCondition(
                              data,
                              utxos,
                              isCreating
                                  ? _amountController.text
                                  : _signingAmountController.text,
                              _currentHeight,
                            );

                            // print(isSelectable);

                            // Replace fingerprints with aliases
                            List<String> aliases =
                                (data['fingerprints'] as List<dynamic>)
                                    .map<String>((fingerprint) {
                              final matchedAlias =
                                  widget.pubKeysAlias.firstWhere(
                                (pubKeyAlias) => pubKeyAlias['publicKey']!
                                    .contains(fingerprint),
                                orElse: () => {
                                  'alias': fingerprint
                                }, // Fallback to fingerprint
                              );

                              return matchedAlias['alias'] ?? fingerprint;
                            }).toList();

                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: data,
                              enabled:
                                  isSelectable, // Disable interaction for unselectable items
                              child: Text(
                                "Type: ${data['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK: ${data['timelock']} blocks' : 'MULTISIG'}, "
                                "${data['threshold'] != null ? '${data['threshold']} of ${aliases.length}, ' : ''} Keys: ${aliases.join(', ')}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelectable
                                      ? Colors.white
                                      : Colors
                                          .grey, // Use gray for unselectable
                                ),
                              ),
                            );
                          }).toList(),
                          onTap: () {
                            setState(() {
                              // print('Rebuilding');
                            });
                          },
                          onChanged: (Map<String, dynamic>? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedPath =
                                    newValue; // Update the selected path
                                selectedIndex = extractedData
                                    .indexOf(newValue); // Update the index
                              });
                            } else {
                              // Optionally handle the selection of unselectable items
                              print("This item is unavailable.");
                            }
                          },
                          selectedItemBuilder: (BuildContext context) {
                            return extractedData.map((data) {
                              isSelectable = walletService.checkCondition(
                                data,
                                utxos,
                                isCreating
                                    ? _amountController.text
                                    : _signingAmountController.text,
                                _currentHeight,
                              );

                              // print(isSelectable);

                              return Text(
                                "Type: ${data['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK' : 'MULTISIG'} ${data['threshold']}, ...",
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isSelectable ? Colors.white : Colors.grey,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList();
                          },
                          decoration: InputDecoration(
                            labelText: 'Select Spending Path',
                            labelStyle: const TextStyle(color: Colors.white),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.blue),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          dropdownColor: Colors.grey[850],
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.white),
                        ),

                        const SizedBox(height: 16),

                        if (isCreating)
                          InkwellButton(
                            onTap: () async {
                              try {
                                // Validate recipient address
                                if (_recipientController.text.isEmpty) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors
                                            .grey[900], // Dark background color
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(Icons.error,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Error',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ],
                                        ),
                                        content: Text(
                                          'Please enter a recipient address.',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('OK',
                                                style: TextStyle(
                                                    color: Colors.blue)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  return; // Exit the function early if validation fails
                                }

                                try {
                                  walletService.validateAddress(
                                      _recipientController.text);
                                } catch (e) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Row(
                                          children: [
                                            Icon(Icons.error,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Invalid Address'),
                                          ],
                                        ),
                                        content: Text(e.toString()),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  return; // Exit the function early if address is invalid
                                }

                                // Validate spending path
                                if (selectedPath == null) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors
                                            .grey[900], // Dark background color
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(Icons.error,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Error',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ],
                                        ),
                                        content: Text(
                                          'Please select a spending path.',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('OK',
                                                style: TextStyle(
                                                    color: Colors.blue)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  return; // Exit the function early if validation fails
                                }

                                final availableBalance =
                                    wallet.getBalance().spendable;

                                final String recipientAddress =
                                    _recipientController.text.toString();

                                final int sendAllBalance = int.parse(
                                    (await walletService.createPartialTx(
                                  _descriptor.toString(),
                                  widget.mnemonic,
                                  recipientAddress,
                                  availableBalance,
                                  selectedIndex,
                                  isSendAllBalance: true,
                                  spendingPaths: spendingPaths,
                                ))!);

                                _amountController.text =
                                    sendAllBalance.toString();
                              } catch (e) {
                                print('Error: $e');
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: Colors
                                          .grey[900], // Dark background color
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(Icons.error, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Error',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                      content: Text(
                                        'An error occurred: ${e.toString()}',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text('OK',
                                              style: TextStyle(
                                                  color: Colors.blue)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            },
                            label: 'Use Available Balance',
                            icon: Icons.account_balance_wallet_rounded,
                            backgroundColor: Colors.blue,
                            textColor: Colors.white,
                            iconColor: Colors.white,
                          ),
                      ],
                    ),
                  ),
                ),
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
                  String recipientAddressStr = "";
                  int amount = 0;

                  String psbtString;
                  String? result;

                  if (isCreating) {
                    recipientAddressStr = _recipientController.text;
                    amount = int.parse(_amountController.text);

                    result = await walletService.createPartialTx(
                      _descriptor.toString(),
                      widget.mnemonic,
                      recipientAddressStr,
                      BigInt.from(amount),
                      selectedIndex, // Use the selected path
                    );
                  } else {
                    psbtString = _psbtController.text;

                    result = await walletService.signBroadcastTx(
                      psbtString,
                      _descriptor.toString(),
                      widget.mnemonic,
                      selectedIndex,
                    );
                  }

                  setState(() {
                    _txToSend = result;
                  });

                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(isCreating
                          ? 'Transaction Created Successfully.'
                          : 'Transaction Signed Successfully'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                } catch (e) {
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
              label: 'Submit',
              backgroundColor: Colors.blue,
              textColor: Colors.white,
            ),
          ],
        );
      },
    ).then((_) {
      _recipientController.clear();
      _psbtController.clear();
      _signingAmountController.clear();
      _amountController.clear();

      signersList = [];

      selectedPath = null; // Reset the dropdown selection
      selectedIndex = null; // Reset the selected index
    });
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

  Future<void> _syncWallet() async {
    // walletService.printTransactionDetails();

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

    _descriptor = widget.descriptor;

    // walletService.printPrettyJson(
    //     wallet.policies(KeychainKind.externalChain)!.toString());

    // walletService.printInChunks(_descriptor.toString());
    // print(widget.pubKeysAlias);

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());

    // print(connectivityResult);

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
          _currentHeight = _walletData!.currentHeight;
          _timeStamp = _walletData!.timeStamp;
          _isLoading = false;
        });
      }
    } else {
      // print('walletState: $walletState');
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

      // Fetch the average block time
      final averageBlockTime = await walletService.fetchAverageBlockTime();

      // Fetch all transactions for the wallet
      final walletUtxos = await walletService.getUtxos(address);

      setState(() {
        avgBlockTime = averageBlockTime;
        utxos = walletUtxos;
      });
    }
  }

  // Function to show a PIN input dialog
  void _showPinDialog(BuildContext context) {
    TextEditingController pinController =
        TextEditingController(); // Controller for the PIN input

    final rootContext = context;

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
                  Navigator.of(context).pop();
                  verifyPin(pinController); // Call the verification function
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

  void verifyPin(TextEditingController pinController) async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    String savedMnemonic = walletBox.get('walletMnemonic');
    final rootContext = context;

    if (savedPin == pinController.text) {
      showDialog(
        context: rootContext,
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
                    borderRadius: BorderRadius.circular(8.0), // Rounded edges
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
                      const SizedBox(width: 8), // Space between text and icon
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Colors.blue, // Highlighted icon color
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
                      color: Colors.blue, // Border color for emphasis
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
                          color: Colors.blue, // Highlighted icon color
                        ),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _descriptor.toString()));
                          ScaffoldMessenger.of(rootContext).showSnackBar(
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
              TextButton(
                onPressed: () async {
                  // Serialize data to JSON
                  final data = jsonEncode({
                    'descriptor': _descriptor,
                    'publicKeysWithAlias': widget.pubKeysAlias,
                    'descriptorName': _descriptorName,
                  });

                  // Request storage permission (required for Android 11 and below)
                  if (await Permission.storage.request().isGranted) {
                    // Get default Downloads directory
                    final directory = Directory('/storage/emulated/0/Download');
                    if (!await directory.exists()) {
                      await directory.create(recursive: true);
                    }

                    String fileName = '$_descriptorName.json';
                    String filePath = '${directory.path}/$fileName';
                    File file = File(filePath);

                    // Check if the file already exists
                    if (await file.exists()) {
                      final shouldProceed = await showDialog<bool>(
                          context: rootContext,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors
                                  .grey[900], // Dark background for the dialog
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    20.0), // Rounded corners
                              ),
                              title: const Text('File Already Exists'),
                              content: const Text(
                                  ' A file with the same name already exists. Do you want to save it anyway?'),
                              actions: [
                                InkwellButton(
                                  onTap: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  label: 'Cancel',
                                  backgroundColor: Colors.white,
                                  textColor: Colors.black,
                                  icon: Icons.cancel_rounded,
                                  iconColor: Colors.redAccent,
                                ),
                                InkwellButton(
                                  onTap: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  label: 'Yes',
                                  backgroundColor: Colors.white,
                                  textColor: Colors.black,
                                  icon: Icons.check_circle,
                                  iconColor: Colors.blueAccent,
                                ),
                              ],
                            );
                          });

                      // If the user chooses not to proceed, exit
                      if (!shouldProceed!) {
                        return;
                      }

                      // Increment the file name index until a unique file name is found
                      int index = 1;
                      while (await file.exists()) {
                        fileName = '$_descriptorName($index).json';
                        filePath = '${directory.path}/$fileName';
                        file = File(filePath);
                        index++;
                      }
                    }
                    // Write JSON data to the file
                    await file.writeAsString(data);

                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content:
                            Text('File saved to ${directory.path}/$fileName'),
                      ),
                    );
                  } else {
                    // Permission denied
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Storage permission is required to save the file'),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
                child: const Text('Download Descriptor'),
              ),
              InkwellButton(
                onTap: () {
                  Navigator.of(context)
                      .pop(); // Close the dialog without action
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
    } else {
      ScaffoldMessenger.of(rootContext).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  void _showPathsDialog(
    BuildContext context,
    Map<String, dynamic> policy,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background for the dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: const Text(
            'Available Spending Paths',
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
              children: spendingPaths.map<Widget>((pathInfo) {
                // Extract aliases for the current pathInfo's fingerprints
                final List<String> pathAliases =
                    (pathInfo['fingerprints'] as List<dynamic>)
                        .map<String>((fingerprint) {
                  final matchedAlias = widget.pubKeysAlias.firstWhere(
                    (pubKeyAlias) =>
                        pubKeyAlias['publicKey']!.contains(fingerprint),
                    orElse: () =>
                        {'alias': fingerprint}, // Fallback to fingerprint
                  );
                  return matchedAlias['alias'] ?? fingerprint;
                }).toList();

                // Extract timelock for the path
                final timelock = pathInfo['timelock'] ?? 0;

                // print('Timelock for the path: $timelock');
                // print('Current blockchain height: $currentHeight');

                String timeRemaining = 'Spendable';

                // Gather all transactions for the display
                List<Widget> transactionDetails = utxos.map<Widget>((utxo) {
                  // Debug print for transaction ID
                  // print('Processing Transaction ID: ${utxo['txid']}');

                  // Access the block_height of the transaction
                  final blockHeight = utxo['status']['block_height'];
                  // print(
                  //     'Transaction block height: $blockHeight, $_currentHeight');

                  final value = utxo['value'];

                  if (blockHeight == null) {
                    // Handle unconfirmed UTXOs
                    return Text(
                      "Value: $value sats - Unconfirmed",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    );
                  }

                  // Determine if the transaction is spendable
                  final isSpendable =
                      blockHeight + timelock - 1 <= _currentHeight ||
                          timelock == 0;
                  // print('Is transaction spendable? $isSpendable');

                  final remainingBlocks =
                      blockHeight + timelock - 1 - _currentHeight;
                  // print(
                  //     'Remaining blocks until timelock expires: $remainingBlocks');

                  // Calculate time remaining if not spendable
                  if (!isSpendable) {
                    // print('Calculating time remaining...');
                    // print('Average block time: $avgBlockTime seconds');
                    final totalSeconds = remainingBlocks * avgBlockTime;
                    timeRemaining = walletService.formatTime(totalSeconds);
                    // print('Formatted time remaining: $timeRemaining');
                  }

                  return Text(
                    isSpendable
                        ? "$value sats can be spent!"
                        : "Value: $value sats \nTime Remaining: $timeRemaining \nBlocks remaining: $remainingBlocks",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  );
                }).toList();

                // Display spending path details
                return Container(
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
                      Text(
                        "Type: ${pathInfo['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK' : 'MULTISIG'}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      pathInfo['threshold'] != null
                          ? Text(
                              "Threshold: ${pathInfo['threshold']}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            )
                          : const SizedBox.shrink(),
                      Text.rich(
                        TextSpan(
                          children: [
                            for (int i = 0; i < pathAliases.length; i++)
                              TextSpan(
                                text: pathAliases[i] +
                                    (i == pathAliases.length - 1
                                        ? ""
                                        : ", "), // Remove comma for last item
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: pathAliases[i] == myAlias
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),

                      Text(
                        "Transaction info:",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      ...transactionDetails, // Display all transaction details
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop(); // Close the dialog
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
    // Determine color and sign
    Color balanceColor = ledBalance > 0
        ? Colors.blue
        : (ledBalance < 0 ? Colors.red : Colors.grey);

    return BaseScaffold(
      title: Text(_descriptorName),
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
                  _buildInfoBox(
                    'Address',
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            showInSatoshis
                                ? Text(
                                    '$avBalance sats',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  )
                                : Text.rich(
                                    TextSpan(
                                      text:
                                          '${avCurrencyBalance.toStringAsFixed(2)} ',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: settingsProvider.currency,
                                        ),
                                      ],
                                    ),
                                  ),
                            const SizedBox(width: 8),
                            ledBalance != 0
                                ? showInSatoshis
                                    ? Text(
                                        ledBalance > 0
                                            ? '+ $ledBalance sats'
                                            : '$ledBalance sats',
                                        style: TextStyle(
                                          color: balanceColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      )
                                    : Text.rich(
                                        TextSpan(
                                          text: ledBalance > 0
                                              ? '+ ${ledCurrencyBalance.toStringAsFixed(2)}'
                                              : ledCurrencyBalance
                                                  .toStringAsFixed(2),
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: balanceColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          children: [
                                            TextSpan(
                                                text:
                                                    settingsProvider.currency),
                                          ],
                                        ),
                                      )
                                : Text(''),
                          ],
                        ),
                        const Divider(
                          height: 20,
                          thickness: 1,
                          color: Colors.grey,
                        ),
                        Text(
                          'We are currently at Block Height: $_currentHeight\n'
                          'Timestamp: $_timeStamp',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: isInitialized
                          ? TextField(
                              controller: _pubKeyController,
                              obscureText: !isPubKeyVisible,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                border:
                                    InputBorder.none, // ✅ No default underline
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            )
                          : const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              ),
                            ), // ✅ Shows CircularProgressIndicator if not initialized
                    ),
                    onTap: () {
                      _convertCurrency();
                    },
                    showCopyButton: true,
                    subtitle: (DateTime.now()
                                .difference(_lastRefreshed)
                                .inHours >=
                            2)
                        ? '$_elapsedTime have passed! \nIt\'s time to refresh!'
                        : null,
                  ),
                  // Spending Paths Layout
                  Align(
                    alignment: Alignment.center,
                    child: isInitialized
                        ? mySpendingPaths.isEmpty
                            ? const Text(
                                "No spending paths available",
                                style: TextStyle(color: Colors.grey),
                              )
                            : Align(
                                alignment: Alignment
                                    .centerLeft, // Try center or centerLeft
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: mySpendingPaths
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int index = entry.key; // Get index
                                      var path = entry.value; // Get path item

                                      return _buildSpendingPathBox(
                                        path,
                                        index,
                                        mySpendingPaths.length,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              )
                        : const CircularProgressIndicator(color: Colors.blue),
                  ),

                  _buildTransactionsBox(),

                  const SizedBox(height: 8),

                  _buildInfoBoxMultisig(
                    'MultiSig Transactions',
                    _txToSend != null
                        ? _txToSend.toString()
                        : 'No transactions to sign',
                    onTap: () {
                      _sendTx(false);
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CustomButton(
                          onPressed: () {
                            _showPinDialog(context);
                          },
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          icon: Icons.remove_red_eye, // Icon for the new button
                          iconColor: Colors.blue,
                          label: 'Private Data',
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          onPressed: () {
                            _showPathsDialog(
                              context,
                              policy,
                            );
                          },
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          icon: Icons.pattern, // Icon for the new button
                          iconColor: Colors.blue,
                          label: 'Spending Summary',
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Send Button
                        CustomButton(
                          onPressed: () {
                            _sendTx(true);
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.blue, // Bitcoin green color for text
                          icon: Icons.arrow_upward, // Icon you want to use
                          iconColor: Colors.blue, // Color for the icon
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
                              // _showTransactionDialog(recipientAddressStr);
                              _sendTx(true,
                                  recipientAddressQr: recipientAddressStr);
                            }
                          },
                          backgroundColor: Colors.white, // White background
                          foregroundColor:
                              Colors.blue, // Bitcoin green color for text
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
                              Colors.blue, // Bitcoin green color for text
                          icon: Icons.arrow_downward, // Icon you want to use
                          iconColor: Colors.blue, // Color for the icon
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
  Widget _buildInfoBox(
    String title,
    Widget section1,
    Widget section2,
    Widget pubKeyWidget, {
    VoidCallback? onTap,
    bool showCopyButton = false,
    String? subtitle,
  }) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
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

                  // First Section: Address (with Copy Button)
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
                            // Assuming section1 is Text, extract the text for copying
                            if (section1 is Text) {
                              Clipboard.setData(
                                  ClipboardData(text: (section1).data ?? ''));
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

                  Text(
                    "Public Key",
                    style: TextStyle(color: Colors.blue),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: pubKeyWidget,
                      ),
                      if (isInitialized)
                        IconButton(
                          icon: Icon(
                            isPubKeyVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.green,
                          ),
                          tooltip:
                              isPubKeyVisible ? "Hide PubKey" : "Show PubKey",
                          onPressed: () {
                            setDialogState(() {
                              isPubKeyVisible = !isPubKeyVisible;
                            });
                          },
                        ),
                      if (isInitialized && isPubKeyVisible)
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          tooltip: 'Copy PubKey',
                          onPressed: () {
                            String pubKeyText = _pubKeyController.text;

                            if (pubKeyText.isNotEmpty) {
                              Clipboard.setData(
                                  ClipboardData(text: pubKeyText));

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Public Key copied to clipboard"),
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
      },
    );
  }

  Widget _buildSpendingPathBox(
    Map<String, dynamic> path,
    int index,
    int length,
  ) {
    // print('Spending paths: $path');

    // Extract aliases for the current pathInfo's fingerprints
    final List<String> pathAliases =
        (path['fingerprints'] as List<dynamic>).map<String>((fingerprint) {
      final matchedAlias = widget.pubKeysAlias.firstWhere(
        (pubKeyAlias) => pubKeyAlias['publicKey']!.contains(fingerprint),
        orElse: () => {'alias': fingerprint}, // Fallback to fingerprint
      );
      return matchedAlias['alias'] ?? fingerprint;
    }).toList();

    // Extract timelock for the path
    final timelock = path['timelock'] ?? 0;

    // print('Timelock for the path: $timelock');
    // print('Current blockchain height: $currentHeight');

    String timeRemaining = 'Spendable';

    int totalSpendable = 0;
    int totalUnconfirmed = 0;
    Map<int, int> blockHeightTotals = {};
    List<Widget> transactionDetails = [];

    for (var utxo in utxos) {
      final blockHeight = utxo['status']['block_height'];
      final value = utxo['value'];

      if (blockHeight == null) {
        totalUnconfirmed += value as int;

        continue;
      }

      // print('totalUncofnirmed: $totalUnconfirmed');

      // Determine if the transaction is spendable
      final isSpendable =
          blockHeight + timelock - 1 <= _currentHeight || timelock == 0;

      // Calculate time remaining if not spendable
      if (isSpendable) {
        totalSpendable += value as int;
      } else {
        // print(utxo['txid']);

        // print(blockHeight);

        if (blockHeightTotals.containsKey(blockHeight)) {
          blockHeightTotals[blockHeight] =
              blockHeightTotals[blockHeight]! + value as int;
        } else {
          blockHeightTotals[blockHeight] = value;
        }
      }
    }

    List<Widget> waitingTransactions = blockHeightTotals.entries.map((entry) {
      int utxoBlockHeight = entry.key;
      int totalValue = entry.value;

      final remainingBlocks = utxoBlockHeight + timelock - 1 - _currentHeight;
      final totalSeconds = remainingBlocks * avgBlockTime;
      timeRemaining = walletService.formatTime(totalSeconds as int);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock, color: Colors.blueAccent, size: 16),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              "$totalValue sats available in $timeRemaining",
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ],
      );
    }).toList();

    transactionDetails.insertAll(0, waitingTransactions);

    // ✅ Add the total unconfirmed amount to the transaction details list
    if (totalUnconfirmed > 0) {
      transactionDetails.insert(
        0, // Add at the top
        Text(
          "Total Unconfirmed: $totalUnconfirmed sats",
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    // Construct alias string for transaction details
    List<String> otherAliases = List.from(pathAliases)..remove(myAlias);

    String aliasText = totalSpendable > 0
        ? "You ($myAlias) can spend $totalSpendable sats now"
        : "You ($myAlias) cannot spend sats now";

    if (otherAliases.isNotEmpty) {
      aliasText += "\nTogether with: ${otherAliases.join(', ')}";
    }

    return Stack(
      children: [
        // 🌟 Main Card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 5,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 **Spending Path Label**
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      path['type'].contains('RELATIVETIMELOCK')
                          ? 'Timelock: $timelock blocks'
                          : 'MULTISIG',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.vpn_key,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        _showPathsDialog(context, policy);
                      },
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.black54,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 🔹 **Spendable Balance (Big Bold Text)**
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          aliasText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 🔹 **Transaction Details**
                if (transactionDetails.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Upcoming Funds:",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...transactionDetails,
                    ],
                  ),
              ],
            ),
          ),
        ),

        // 🔹 **Index Badge (Top-Right Corner)**
        Positioned(
          top: 13,
          right: 13,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${index + 1} of $length',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Box for displaying general wallet info with onTap functionality
  Widget _buildInfoBoxMultisig(String title, String data,
      {VoidCallback? onTap, bool showCopyButton = false, String? subtitle}) {
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
                  color: Colors.blue, // Match button text color
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
                      icon: const Icon(Icons.copy, color: Colors.blue),
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
          ? Colors.amber
          : isSent
              ? Colors.redAccent[100]
              : Colors.tealAccent,
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
                  color: isConfirmed ? Colors.blue : Colors.amber,
                ),
                Text(
                  // Show only the fee payed for internal transactions
                  isInternal
                      ? "Internal: - $fee satoshis"
                      : '${isSent ? "Sent: - " : "Received: + "}$amount satoshis',
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
            if (isSent && !isInternal)
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
