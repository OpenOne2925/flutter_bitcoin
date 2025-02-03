import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:english_words/english_words.dart';

/// WalletService Class
///
/// This class provides a comprehensive suite of tools for managing Bitcoin wallets
/// using the `bdk_flutter` library. It supports both single and shared wallet functionalities,
/// descriptor-based wallet management, transaction creation, and interaction with blockchain
/// APIs like Mempool.space. The class also handles wallet synchronization, balance retrieval,
/// and multi-signature (multisig) wallets.
///
/// **INDEX**
///
/// **Common Methods**
/// - **`isValidDescriptor`**: Validates a wallet descriptor.
/// - **`getBalance`**: Retrieves the total balance from a wallet.
/// - **`getLedgerBalance`**: Fetches the ledger balance for a given address.
/// - **`getAvailableBalance`**: Fetches the available balance for a given address.
/// - **`loadSavedWallet`**: Restores a wallet using a saved mnemonic.
/// - **`syncWallet`**: Synchronizes a wallet with the blockchain.
/// - **`getAddress`**: Retrieves the current receiving address from a wallet.
/// - **`blockchainInit`**: Initializes a connection to the blockchain via an Electrum server.
/// - **`fetchCurrentBlockHeight`**: Fetches the current block height from the blockchain.
/// - **`fetchAverageBlockTime`**: Fetches the average block time from the blockchain.
/// - **`calculateRemainingTimeInSeconds`**: Calculates the remaining time for a specific number of blocks.
/// - **`formatTime`**: Formats a duration in seconds into a human-readable format.
/// - **`getUtxos`**: Fetches the unspent transaction outputs (UTXOs) for a given address.
///
/// **Single Wallet**
/// - **`createOrRestoreWallet`**: Creates or restores a single-user wallet from a mnemonic.
/// - **`calculateSendAllBalance`**: Computes the maximum amount that can be sent after deducting fees.
/// - **`sendTx`**: Creates, signs, and broadcasts a single-user transaction.
///
/// **Shared Wallet**
/// - **`createSharedWallet`**: Creates a wallet for multi-signature use.
/// - **`createWalletDescriptor`**: Generates a descriptor for shared wallets with time-lock and multisig conditions.
/// - **`createPartialTx`**: Creates a partially signed Bitcoin transaction (PSBT) for shared wallets.
/// - **`signBroadcastTx`**: Signs a PSBT with the second user and broadcasts it to the blockchain.
///
/// **Utilities**
/// - **`printInChunks`**: Prints long strings in chunks for readability.
/// - **`printPrettyJson`**: Pretty-prints JSON strings for debugging.
/// - **`checkCondition`**: Checks whether a specific condition is met for UTXO spending.
///
/// **Blockchain Interaction**
/// - **`getFeeRate`**: Retrieves the current recommended fee rate for transactions.
/// - **`getTransactions`**: Fetches transaction history for a given address.
///
/// **Multi-signature Utilities**
/// - **`replacePubKeyWithPrivKeyMultiSig`**: Replaces public keys with private keys in a multisig descriptor.
/// - **`replacePubKeyWithPrivKeyOlder`**: Replaces public keys with private keys in timelocked descriptors.
/// - **`extractOlderWithPrivateKey`**: Extracts the "older" value from a descriptor and associates it with private keys.
///
/// **Descriptor Key Derivation**
/// - **`deriveDescriptorKeys`**: Derives descriptor secret and public keys based on a derivation path and mnemonic.
///
/// **Policy and Path Extraction**
/// - **`extractAllPathsToFingerprint`**: Extracts all policy paths to a specific fingerprint.
/// - **`extractDataByFingerprint`**: Extracts data related to a specific fingerprint from the wallet policy.
/// - **`extractAllPaths`**: Extracts all policy paths from a wallet descriptor.
///
/// **Data Storage**
/// - **`saveLocalData`**: Saves wallet-related data, such as balances and transactions, to local storage.

class WalletService {
  final WalletStorageService _walletStorageService = WalletStorageService();

  // Base URL for Mempool Space Testnet API
  final String baseUrl = 'https://mempool.space/testnet4/api';

  // Base URL for Mempool Space Mainnet API
  // final String baseUrl = 'https://mempool.space/api';

  final Network network = Network.testnet;

  late Wallet wallet;
  late Blockchain blockchain;

  List<String> electrumServers = [
    // "ssl://electrum.blockstream.info:50002", // TODO: MAINNET SERVER
    "ssl://mempool.space:40002", // TODO: TESTNET4 SERVER
    "ssl://blockstream.info:993",
    // "ssl://tn.not.fyi:55002", // Only for Testnet
    "ssl://electrum.blockonomics.co:51002",
    // "ssl://testnet.aranguren.org:51002" // Only for Testnet
  ];

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// Common Methods
  ///
  ///
  ///
  ///
  ///
  ///

  Future<ValidationResult> isValidDescriptor(
      String descriptorStr, String publicKey) async {
    try {
      // print(publicKey);
      // printInChunks(descriptorStr);

      if (descriptorStr.contains(publicKey)) {
        // Try creating the descriptor
        final descriptor = await Descriptor.create(
          descriptor: descriptorStr,
          network: network,
        );

        // Try creating the wallet with the descriptor
        await Wallet.create(
          descriptor: descriptor,
          network: network,
          databaseConfig: const DatabaseConfig.memory(),
        );

        return ValidationResult(isValid: true);
      } else {
        return ValidationResult(
          isValid: false,
          errorMessage:
              'Error: Your public key is not contained in this descriptor',
        );
      }
    } catch (e) {
      // print('Error creating wallet with descriptor: $e');
      // If any error occurs during creation, set isValid to false
      return ValidationResult(
        isValid: false,
        errorMessage: 'Error creating wallet with the descriptor provided',
      );
    }
  }

  BigInt getBalance(Wallet wallet) {
    // await syncWallet(wallet);
    Balance balance = wallet.getBalance();

    // print(balance.total);

    return balance.total;
  }

  Future<bool> checkMnemonic(String mnemonic) async {
    try {
      final descriptors = await getDescriptors(mnemonic);

      await Wallet.create(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: network,
        databaseConfig: const DatabaseConfig.memory(),
      );

      return true;
    } on Exception {
      // print("Error: ${e.toString()}");
      return false;
    }
  }

  Future<Wallet> loadSavedWallet(String? mnemonic) async {
    var walletBox = Hive.box('walletBox');
    String? savedMnemonic = walletBox.get('walletMnemonic');

    // print(savedMnemonic);

    if (savedMnemonic != null) {
      // Restore the wallet using the saved mnemonic
      wallet = await createOrRestoreWallet(
        savedMnemonic,
      );
      // print(wallet);
      return wallet;
    } else {
      wallet = await createOrRestoreWallet(
        mnemonic!,
      );
    }
    return wallet;
  }

  Future<void> syncWallet(Wallet wallet) async {
    await blockchainInit(); // Ensure blockchain is initialized before usage

    // print(wallet.getBalance().total.toInt());

    await wallet.sync(blockchain: blockchain);
  }

  String getAddress(Wallet wallet) {
    // await syncWallet(wallet);

    var addressInfo =
        wallet.getAddress(addressIndex: const AddressIndex.peek(index: 0));
    return addressInfo.address.asString();
  }

  Future<int> calculateSendAllBalance({
    required String recipientAddress,
    required Wallet wallet,
    required int availableBalance,
    required WalletService walletService,
  }) async {
    try {
      final int feeRate = await walletService.getFeeRate();

      final recipient = await Address.fromString(
        s: recipientAddress,
        network: network,
      );
      final recipientScript = recipient.scriptPubkey();

      final externalWalletPolicy = wallet.policies(KeychainKind.externalChain);
      final path = {
        externalWalletPolicy!.id(): Uint32List.fromList([0]), // MULTISIG path
      };

      final txBuilder = TxBuilder();

      await txBuilder
          .addRecipient(recipientScript, BigInt.from(availableBalance))
          .policyPath(KeychainKind.internalChain, path)
          .policyPath(KeychainKind.externalChain, path)
          .feeRate(feeRate.toDouble())
          .finish(wallet);

      return availableBalance; // If no exception occurs, return available balance
    } catch (e) {
      // Handle insufficient funds
      if (e.toString().contains("InsufficientFundsException")) {
        final RegExp regex = RegExp(r'Needed: (\d+),');
        final match = regex.firstMatch(e.toString());
        if (match != null) {
          final int neededAmount = int.parse(match.group(1)!);
          final int fee = neededAmount - availableBalance;
          final int sendAllBalance = availableBalance - fee;

          if (sendAllBalance > 0) {
            return sendAllBalance; // Return adjusted send all balance
          } else {
            throw Exception('No balance available after fee deduction');
          }
        } else {
          throw Exception('Failed to extract Needed amount from exception');
        }
      } else {
        rethrow; // Re-throw unhandled exceptions
      }
    }
  }

  // Use the first available server in the list
  Future<void> blockchainInit() async {
    for (var url in electrumServers) {
      try {
        blockchain = await Blockchain.create(
          config: BlockchainConfig.electrum(
            config: ElectrumConfig(
              url: url,
              timeout: 5,
              retry: 5,
              stopGap: BigInt.from(10),
              validateDomain: true,
            ),
          ),
        );
        print("Connected to Electrum server: $url");
        return;
      } catch (e) {
        print("Failed to connect to Electrum server: $url, trying next...");
      }
    }
    throw Exception("Failed to connect to any Electrum server.");
  }

  Future<int> getFeeRate() async {
    final memPoolUrl = '$baseUrl/v1/fees/recommended';

    final response = await http.get(Uri.parse(memPoolUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // print(response.body);

      int feeRate = jsonResponse['halfHourFee'];

      // print('FeeRate: $feeRate');

      return feeRate;
    } else {
      throw Exception('Failed to fetch available balance');
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions(String address) async {
    try {
      // Construct the URL
      final url = '$baseUrl/address/$address/txs';

      // Send the GET request to the API
      final response = await http.get(Uri.parse(url));

      // Check if the response was successful
      if (response.statusCode == 200) {
        // Parse the JSON response
        List<dynamic> transactionsJson = jsonDecode(response.body);

        // Cast to List<Map<String, dynamic>> for easier processing
        return List<Map<String, dynamic>>.from(transactionsJson);
      } else {
        throw Exception(
            'Failed to load transactions. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<int> fetchCurrentBlockHeight() async {
    final url = '$baseUrl/blocks/tip/height';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return int.parse(response.body); // The current block height
    } else {
      throw Exception('Failed to fetch current block height');
    }
  }

  Future<DateTime?> fetchBlockTimestamp() async {
    try {
      // API endpoint to fetch the latest block hash
      final String hashApiUrl = '$baseUrl/blocks/tip/hash';

      // Make GET request to fetch the current block hash
      final responseHash = await http.get(Uri.parse(hashApiUrl));

      if (responseHash.statusCode == 200) {
        // Extract the block hash from the response body
        String currentHash = responseHash.body.trim();

        // API endpoint to fetch block details
        final String blockApiUrl = '$baseUrl/block/$currentHash';

        // Make GET request to fetch block details
        final response = await http.get(Uri.parse(blockApiUrl));

        if (response.statusCode == 200) {
          // Decode JSON response
          final Map<String, dynamic> jsonData = json.decode(response.body);

          // Check if data contains the `time` field
          if (jsonData.containsKey('timestamp')) {
            int timestamp = jsonData['timestamp']; // Extract timestamp
            // TODO: localization
            return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
                .toLocal(); // Convert to local DateTime
          } else {
            print('Error: "time" field not found in response.');
            return null;
          }
        } else {
          // Handle HTTP errors for block details API
          print('HTTP Error (Block API): ${response.statusCode}');
          return null;
        }
      } else {
        // Handle HTTP errors for hash API
        print('HTTP Error (Hash API): ${responseHash.statusCode}');
        return null;
      }
    } catch (e) {
      // Handle any unexpected exceptions
      print('Exception occurred: $e');
      return null;
    }
  }

  Future<int> fetchAverageBlockTime() async {
    final url = '$baseUrl/v1/difficulty-adjustment';

    try {
      final response = await http.get(Uri.parse(url));
      // print('API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract and validate `timeAvg`
        final timeAvg = data['timeAvg'] ?? 0;
        final avgBlockTime =
            timeAvg > 10000 ? (timeAvg ~/ 1000) : timeAvg; // Adjust if in ms

        // Sanity check
        if (avgBlockTime < 300 || avgBlockTime > 1200) {
          print('Warning: avgBlockTime seems incorrect: $avgBlockTime');
        }

        return avgBlockTime;
      } else {
        print('Failed to fetch data. HTTP Status: ${response.statusCode}');
        return 0; // Return 0 if the request fails
      }
    } catch (e) {
      print('Error fetching data: $e');
      return 0; // Return 0 in case of an error
    }
  }

  Future<int> calculateRemainingTimeInSeconds(int remainingBlocks) async {
    final avgTime = await fetchAverageBlockTime();

    if (avgTime > 0) {
      // Calculate remaining time in seconds
      return remainingBlocks * avgTime;
    } else {
      throw Exception('Invalid average block time.');
    }
  }

  String formatTime(int totalSeconds) {
    if (totalSeconds <= 0) return "0 seconds";

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '$hours hours, $minutes minutes, $seconds seconds';
  }

  Future<List<dynamic>> getUtxos(String address) async {
    final url = '$baseUrl/address/$address/utxo';
    List<dynamic> transactions = [];

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        transactions = json.decode(response.body);
      } else {
        print(
            'Failed to fetch transactions. HTTP status: ${response.statusCode}');
      }
      return transactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return transactions;
    }
  }

  bool checkCondition(
    Map<String, dynamic> data,
    List<dynamic> utxos,
    String amount,
    int currentHeight,
  ) {
    // Ensure 'timelock' has a default value if it's null
    final timelock = data['timelock'] ?? 0;

    // print('Amount: $amount');

    // Parse the required amount into a number
    final requiredAmount = double.tryParse(amount) ?? 0.0;

    // Accumulate the total value of spendable UTXOs
    double totalSpendableValue = 0.0;

    for (var utxo in utxos) {
      final blockHeight =
          utxo['status']['block_height'] ?? 0; // Default to 0 if null
      final utxoValue = utxo['value'] ?? 0.0; // Ensure a default value for UTXO

      final isSpendable =
          blockHeight + timelock <= currentHeight || timelock == 0;

      if (isSpendable) {
        totalSpendableValue += utxoValue; // Add spendable UTXO value
      }

      // Check if MULTISIG condition is satisfied
      if (data['type'] != null &&
          data['type'].contains('MULTISIG') &&
          data['timelock'] == null) {
        return true; // MULTISIG condition with null timelock
      }
    }

    // Check if the total spendable value is sufficient
    return totalSpendableValue >= requiredAmount;
  }

  Future<bool> areEqualAddresses(List<TxOut> outputs) async {
    Address? firstAddress;

    for (final output in outputs) {
      final testAddress = await Address.fromScript(
        script: ScriptBuf(bytes: output.scriptPubkey.bytes),
        network: network,
      );

      if (firstAddress == null) {
        // Store the first address for comparison
        firstAddress = testAddress;
      } else if (testAddress.asString() != firstAddress.asString()) {
        // If an address does not match the first one, set the flag to false
        return false;
      }
    }
    return true;
  }

  Future<Address> getAddressFromScript(TxOut output) {
    return Address.fromScript(
        script: ScriptBuf(bytes: output.scriptPubkey.bytes), network: network);
  }

  void validateAddress(String address) async {
    try {
      await Address.fromString(s: address, network: network);
    } on AddressException catch (e) {
      throw Exception('Invalid address format: $e');
    } catch (e) {
      throw Exception('Unknown error while validating address: $e');
    }
  }

  List<Map<String, String>> extractPublicKeysWithAliases(String descriptor) {
    // Regular expression to extract public keys (tpub) and their fingerprints with paths
    final publicKeyRegex = RegExp(r"\[([^\]]+)\](tpub[A-Za-z0-9]+[^\s,)]*)");

    // Extract matches
    final matches = publicKeyRegex.allMatches(descriptor);

    // Use a Set to ensure uniqueness
    final Set<String> seenKeys = {};
    List<Map<String, String>> result = [];

    for (var match in matches) {
      // Extract alias (fingerprint) and full public key
      final fingerprint = match.group(1)!.split('/')[0]; // Extract fingerprint
      final publicKey =
          "[${match.group(1)!}]${match.group(2)!}"; // Full public key with path

      // Avoid duplicates
      if (!seenKeys.contains(fingerprint)) {
        seenKeys.add(fingerprint);
        result.add({'publicKey': publicKey, 'alias': fingerprint});
      }
    }

    return result;
  }

  Future<double> convertSatoshisToCurrency(
      int satoshis, String currency) async {
    final url = 'https://blockchain.info/ticker';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      // print(response.body);
      final data = json.decode(response.body);
      final btcToCurrency = data[currency]['buy'];
      final satoshiToCurrency = (btcToCurrency / 100000000) * satoshis;

      return double.parse(satoshiToCurrency.toStringAsFixed(2));
    } else {
      throw Exception('Failed to fetch conversion rate');
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// Single Wallet
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  Future<Wallet> createOrRestoreWallet(String mnemonic) async {
    try {
      final descriptors = await getDescriptors(mnemonic);

      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        await blockchainInit();
      }

      final res = await Wallet.create(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: network,
        databaseConfig: const DatabaseConfig.memory(),
      );
      // var addressInfo =
      //     await res.getAddress(addressIndex: const AddressIndex());

      // print(res);

      return res;
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw Exception('Failed to create wallet (Error: ${e.toString()})');
    }
  }

  Future<List<Descriptor>> getDescriptors(String mnemonic) async {
    final descriptors = <Descriptor>[];
    try {
      for (var e in [KeychainKind.externalChain, KeychainKind.internalChain]) {
        final mnemonicObj = await Mnemonic.fromString(mnemonic);

        final descriptorSecretKey = await DescriptorSecretKey.create(
          network: network,
          mnemonic: mnemonicObj,
        );

        final descriptor = await Descriptor.newBip84(
          secretKey: descriptorSecretKey,
          network: network,
          keychain: e,
        );

        descriptors.add(descriptor);
      }
      return descriptors;
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw ("Error: ${e.toString()}");
    }
  }

  // Method to create, sign and broadcast a single user transaction
  Future<void> sendTx(
    String recipientAddressStr,
    BigInt amount,
    Wallet wallet,
    String changeAddressStr,
  ) async {
    await syncWallet(wallet);

    final utxos = wallet.getBalance();
    print("Available UTXOs: ${utxos.total.toInt()}");
    print(wallet.getAddress(addressIndex: AddressIndex.peek(index: 0)));

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      final recipientAddress = await Address.fromString(
          s: recipientAddressStr, network: wallet.network());
      final recipientScript = recipientAddress.scriptPubkey();

      final changeAddress = await Address.fromString(
          s: changeAddressStr, network: wallet.network());
      final changeScript = changeAddress.scriptPubkey();

      final feeRate = await getFeeRate();

      // Build the transaction:
      // - Send `amount` to the recipient
      // - Any remaining funds (change) will be sent to the change address
      final txBuilderResult = await txBuilder
          .enableRbf()
          .addRecipient(recipientScript, amount) // Send to recipient
          .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
          .feeRate(
              feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
          .drainTo(
              changeScript) // Specify the custom address to send the change
          .finish(wallet); // Finalize the transaction with wallet's UTXOs

      // Sign the transaction
      final isFinalized = await wallet.sign(psbt: txBuilderResult.$1);

      // Broadcast the transaction only if it is finalized
      if (isFinalized) {
        final tx = txBuilderResult.$1.extractTx();
        // Broadcast the transaction to the network only if it is finalized
        await blockchain.broadcast(transaction: tx);
      }
    } on Exception catch (e) {
      print("Error: ${e.toString()}");
      throw Exception('Failed to send Transaction (Error: ${e.toString()})');
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// Shared Wallet
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  Future<Wallet> createSharedWallet(String descriptor) async {
    return wallet = await Wallet.create(
      descriptor: await Descriptor.create(
        descriptor: descriptor,
        network: network,
      ),
      network: network,
      databaseConfig: const DatabaseConfig.memory(),
    );
  }

  String createWalletDescriptor(
    String primaryReceivingSecret,
    String secondaryReceivingPublic,
    int primaryTimelock,
    int secondaryTimelock,
    String primaryChangePublic,
    String secondaryChangePublic,
  ) {
    // Define the multi-sig condition based on timelock priority
    String multi = (primaryTimelock < secondaryTimelock)
        ? 'multi(2,$primaryReceivingSecret,$secondaryReceivingPublic)'
        : 'multi(2,$secondaryReceivingPublic,$primaryReceivingSecret)';

    // Define the timelock conditions for Perro and Gato
    String timelockPerro =
        'and_v(v:older($secondaryTimelock),pk($secondaryChangePublic))';
    String timelockGato =
        'and_v(v:older($primaryTimelock),pk($primaryChangePublic))';

    // Combine the timelock conditions
    String timelockCondition = (primaryTimelock < secondaryTimelock)
        ? 'or_i($timelockGato,$timelockPerro)'
        : 'or_i($timelockPerro,$timelockGato)';

    // Return the final walletDescriptor
    return 'wsh(or_d($multi,$timelockCondition))';
  }

  Future<void> saveLocalData(Wallet wallet) async {
    String currentAddress = getAddress(wallet);

    final walletData = WalletData(
      address: currentAddress,
      balance: int.parse(getBalance(wallet).toString()),
      ledgerBalance: wallet.getBalance().total.toInt(),
      availableBalance: wallet.getBalance().confirmed.toInt(),
      transactions: await getTransactions(currentAddress),
      currentHeight: await fetchCurrentBlockHeight(),
    );

    // Save the data to Hive
    await _walletStorageService.saveWalletData(currentAddress, walletData);
  }

  String replacePubKeyWithPrivKeyMultiSig(
      String descriptor, String pubKey, String privKey) {
    // Extract the derivation path and pubkey portion for dynamic matching
    final regexPathPub = RegExp(RegExp.escape('${pubKey.split(']')[0]}]') +
        r'[tx]pub[A-Za-z0-9]+\/\d+\/\*'); // tpub for testnet and xpub for mainnet

    // Replace only the matching public key with the private key
    return descriptor.replaceFirstMapped(regexPathPub, (match) {
      return privKey;
    });
  }

  String replacePubKeyWithPrivKeyOlder(
    int? chosenPath, // The specific index to target
    String descriptor,
    String pubKey,
    String privKey,
  ) {
    // print('------------Replacing------------');
    // printInChunks('Descriptor Before Replacement:\n$descriptor');
    // print('Chosen Path Index: $chosenPath');
    // print('Public Key: $pubKey');
    // print('Private Key: ${privKey.substring(0, privKey.length - 4)}');

    // Extract the derivation path prefix and ensure we match tpub/xpub keys with trailing paths
    final regexPathPub = RegExp(
      RegExp.escape('${pubKey.split(']')[0]}]') +
          r'[tx]pub[A-Za-z0-9]+\/(\d+)\/\*',
    ); // Matches tpub for testnet and xpub for mainnet

    int currentIndex = 0; // Tracks the current match index

    // Replace only the match at the specified `chosenPath` index
    final result = descriptor.replaceAllMapped(regexPathPub, (match) {
      final trailingPath =
          match.group(1); // Extract the trailing path (e.g., "0", "1", "2")

      // Debugging info for each match
      // print('Match Found: ${match.group(0)}');
      // print('Trailing Path Extracted: $trailingPath');
      // print('Current Match Index: $currentIndex');

      if (currentIndex == chosenPath) {
        // print(
        //     'Replacing with Private Key: ${privKey.substring(0, privKey.length - 4)}/$trailingPath/*');
        currentIndex++; // Increment the index for the next match
        return '${privKey.substring(0, privKey.length - 4)}/$trailingPath/*';
      } else {
        // print('Keeping Original Public Key: ${match.group(0)}');
        currentIndex++; // Increment the index for the next match
        return match
            .group(0)!; // Keep the original matched string for other paths
      }
    });

    // printInChunks('Descriptor After Replacement:\n$result');
    // print('------------Replacement Complete------------');

    return result;
  }

  Future<(DescriptorSecretKey, DescriptorPublicKey)> deriveDescriptorKeys(
    DerivationPath hardenedPath,
    DerivationPath unHardenedPath,
    Mnemonic mnemonic,
  ) async {
    // Create the root secret key from the mnemonic
    final secretKey = await DescriptorSecretKey.create(
      network: network,
      mnemonic: mnemonic,
    );

    // Derive the key at the hardened path
    final derivedSecretKey = await secretKey.derive(hardenedPath);

    // Extend the derived secret key further using the unhardened path
    final derivedExtendedSecretKey =
        await derivedSecretKey.extend(unHardenedPath);

    // Convert the derived secret key to its public counterpart
    final publicKey = derivedSecretKey.toPublic();

    // Extend the public key using the same unhardened path
    final derivedExtendedPublicKey =
        await publicKey.extend(path: unHardenedPath);

    return (derivedExtendedSecretKey, derivedExtendedPublicKey);
  }

  Future<int> extractOlderWithPrivateKey(String descriptor) async {
    // Adjusted regex to match only "older" values followed by "pk(...tprv...)"
    final regExp =
        RegExp(r'older\((\d+)\).*?pk\(\[.*?]([tx]p(?:rv|ub)[a-zA-Z0-9]+)');
    final matches = regExp.allMatches(descriptor);

    int older = 0;

    for (var match in matches) {
      String olderValue = match.group(1)!; // Extract the older value
      String keyType = match.group(2)!; // Capture whether it's tprv or tpub

      // Only process the match if it's a private key (tprv)
      if (keyType.startsWith("tprv") || keyType.startsWith("xprv")) {
        // print('Found older value associated with private key: $olderValue');
        older = int.parse(olderValue);
      }
    }

    return older;
  }

  // Function to traverse and extract both the id and the path to the fingerprint
  List<Map<String, dynamic>> extractAllPathsToFingerprint(
    Map<String, dynamic> policy,
    String targetFingerprint,
  ) {
    List<Map<String, dynamic>> result = [];

    void traverse(dynamic node, List<int> currentPath, List<String> idPath) {
      if (node == null) return;

      // // Debugging: Print the current node and paths being processed
      // print('Traversing Node: ${node['id'] ?? 'No ID'}');
      // print('Current Path: $currentPath');
      // print('ID Path: $idPath');

      // Check if the node itself has a matching fingerprint
      if (node['fingerprint'] == targetFingerprint) {
        print('Match Found in Node: ${node['id']}');
        result.add({
          'ids': [...idPath, node['id']],
          'indexes': currentPath,
        });
      }

      // Check if the node contains `keys` with matching fingerprints
      if (node['keys'] != null) {
        for (var key in node['keys']) {
          // print('Checking Key Fingerprint: ${key['fingerprint']}');
          if (key['fingerprint'] == targetFingerprint) {
            // print('Match Found in Keys: Adding Path');
            result.add({
              'ids': [...idPath, node['id']],
              'indexes': currentPath,
            });
          }
        }
      }

      // Recursively traverse children if the node has `items`
      if (node['items'] != null) {
        for (int i = 0; i < node['items'].length; i++) {
          // print('Traversing Child at Index: $i');
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

    // print('Final Result: $result');
    return result;
  }

  List<Map<String, dynamic>> extractDataByFingerprint(
      Map<String, dynamic> json, String fingerprint) {
    List<Map<String, dynamic>> result = [];

    void traverse(Map<String, dynamic> node, List<String> path,
        List<dynamic>? parentItems) {
      // print(
      //     "Traversing node: ${node['id'] ?? 'Unknown ID'}, Path: ${path.join(' > ')}");

      // Check for keys in the current node
      if (node['keys'] != null) {
        // print("Checking keys in node: ${node['id'] ?? 'Unknown ID'}");
        List<dynamic> keys = node['keys'];
        final matchingKeys =
            keys.where((key) => key['fingerprint'] == fingerprint).toList();

        if (matchingKeys.isNotEmpty) {
          String type = node['type'];
          int? timelockValue;

          if (node['threshold'] != null) {
            type = "THRESH > $type";
          }

          // Check sibling constraints
          if (parentItems != null) {
            for (var sibling in parentItems) {
              if (sibling['type'] == 'RELATIVETIMELOCK') {
                type = "RELATIVETIMELOCK > $type";
                timelockValue = sibling['value']; // Capture timelock value
              }
            }
          }

          // print(
          //     "Fingerprint match found in node: ${node['id'] ?? 'Unknown ID'}");
          result.add({
            'type': type,
            'threshold': node['threshold'],
            'fingerprints': keys.map((key) => key['fingerprint']).toList(),
            'path': path.join(' > '),
            'timelock': timelockValue,
          });
          // print("Added to result: ${result.last}");
        } else {
          print("No fingerprint match in node: ${node['id'] ?? 'Unknown ID'}");
        }
      }

      // Check if this node has a direct fingerprint reference (e.g., ECDSASIGNATURE)
      if (node['type'] == 'ECDSASIGNATURE' &&
          node['fingerprint'] == fingerprint) {
        String type = node['type'];
        int? timelockValue;

        // Check sibling constraints for timelocks
        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";
              timelockValue = sibling['value'];
            }
          }
        }

        result.add({
          'type': type,
          'threshold': null,
          'fingerprints': [fingerprint],
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
        // print("Added ECDSASIGNATURE to result: ${result.last}");
      }

      // Recursively traverse child nodes in "items"
      if (node['items'] != null) {
        // print(
        //     "Node has child items: ${node['items'].length} found in node: ${node['id'] ?? 'Unknown ID'}");
        List<dynamic> items = node['items'];
        for (int i = 0; i < items.length; i++) {
          traverse(
            items[i],
            [...path, '${node['type']}[$i]'],
            items, // Pass sibling items for constraint checks
          );
        }
      } else {
        // print("No child items in node: ${node['id'] ?? 'Unknown ID'}");
      }
    }

    // print("Starting traversal with fingerprint: $fingerprint");
    traverse(json, [], null);
    // print("Traversal complete. Results: $result");
    return result;
  }

  List<Map<String, dynamic>> extractAllPaths(Map<String, dynamic> json) {
    List<Map<String, dynamic>> result = [];

    void traverse(Map<String, dynamic> node, List<String> path,
        List<dynamic>? parentItems) {
      // print(
      //     "Traversing node: ${node['id'] ?? 'Unknown ID'}, Path: ${path.join(' > ')}");

      // Check if this node has keys
      if (node['keys'] != null) {
        // print("Checking keys in node: ${node['id'] ?? 'Unknown ID'}");
        List<dynamic> keys = node['keys'];
        List<String> fingerprints =
            keys.map((key) => key['fingerprint'] as String).toList();

        // Determine the type and additional constraints
        String type = node['type'];
        int? timelockValue;

        if (node['threshold'] != null) {
          type = "THRESH > $type";
        }

        // Look for sibling constraints (e.g., RELATIVETIMELOCK)
        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";
              timelockValue = sibling['value']; // Capture the timelock value
            }
          }
        }

        // print("Path found in node: ${node['id'] ?? 'Unknown ID'}");
        result.add({
          'type': type, // Type reflects sibling constraints
          'threshold': node['threshold'],
          'fingerprints': fingerprints,
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
        // print("Added to result: ${result.last}");
      }

      // Check if this node has a direct fingerprint reference (e.g., ECDSASIGNATURE)
      if (node['type'] == 'ECDSASIGNATURE') {
        // print("Checking ECDSASIGNATURE in node: ${node['id'] ?? 'Unknown ID'}");
        String type = "ECDSASIGNATURE";
        int? timelockValue;

        // Look for sibling constraints (e.g., RELATIVETIMELOCK)
        if (parentItems != null) {
          for (var sibling in parentItems) {
            if (sibling['type'] == 'RELATIVETIMELOCK') {
              type = "RELATIVETIMELOCK > $type";
              timelockValue = sibling['value']; // Capture the timelock value
            }
          }
        }

        result.add({
          'type': type,
          'threshold': null, // No threshold for ECDSASIGNATURE
          'fingerprints': [node['fingerprint']], // Single fingerprint
          'path': path.join(' > '),
          'timelock': timelockValue,
        });
        // print("Added ECDSASIGNATURE to result: ${result.last}");
      }

      // Recursively traverse child nodes in "items"
      if (node['items'] != null) {
        // print(
        //     "Node has child items: ${node['items'].length} found in node: ${node['id'] ?? 'Unknown ID'}");
        List<dynamic> items = node['items'];
        for (int i = 0; i < items.length; i++) {
          traverse({
            ...items[i],
            'parentItems': items, // Pass sibling items as context
          }, [
            ...path,
            '${node['type']}[$i]'
          ], items);
        }
      } else {
        // print("No child items in node: ${node['id'] ?? 'Unknown ID'}");
      }
    }

    // print("Starting traversal for all paths");
    traverse(json, [], null);
    // print("Traversal complete. Results: $result");
    return result;
  }

  // Method to create a PSBT for a multisig transaction, this psbt is signed by the first user
  Future<String?> createPartialTx(String descriptor, String mnemonic,
      String recipientAddressStr, BigInt amount, int? chosenPath,
      {bool isSendAllBalance = false,
      List<Map<String, dynamic>>? spendingPaths}) async {
    Map<String, Uint32List>? multiSigPath;
    Map<String, Uint32List>? timeLockPath;

    // print('Bool: $multiSig');
    Mnemonic trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = await deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    // print(receivingPublicKey);

    // Extract the content inside square brackets
    final RegExp regex = RegExp(r'\[([^\]]+)\]');
    final Match? match = regex.firstMatch(receivingPublicKey.asString());

    final String targetFingerprint = match!.group(1)!.split('/')[0];
    // print("Fingerprint: $targetFingerprint");

    descriptor = (chosenPath == 0)
        ? replacePubKeyWithPrivKeyMultiSig(
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          )
        : replacePubKeyWithPrivKeyOlder(
            chosenPath,
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          );

    printInChunks('Sending Descriptor: $descriptor');

    wallet = await createSharedWallet(descriptor);

    await syncWallet(wallet);

    final utxos = wallet.getBalance();
    print("Available UTXOs: ${utxos.confirmed}");

    final unspent = wallet.listUnspent();
    final feeRate = await getFeeRate();

    BigInt totalSpending;

    if (!isSendAllBalance) {
      // totalSpending = amount + BigInt.from(feeRate);

      totalSpending = amount;
      print("Total Spending: $totalSpending");
      print("Confirmed Utxos: ${utxos.confirmed}");
      // Check If there are enough funds available
      if (utxos.confirmed < totalSpending) {
        // Exit early if no confirmed UTXOs are available
        throw Exception(
            "Not enough confirmed funds available. Please wait until your transactions confirm.");
      }
    }

    List<OutPoint> spendableOutpoints = [];

    for (var utxo in unspent) {
      print('UTXO: ${utxo.outpoint.txid}, Amount: ${utxo.txout.value}');
    }

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      final recipientAddress = await Address.fromString(
          s: recipientAddressStr, network: wallet.network());
      final recipientScript = recipientAddress.scriptPubkey();

      var internalChangeAddress = wallet.getInternalAddress(
          addressIndex: const AddressIndex.peek(index: 0));

      final changeScript = internalChangeAddress.address.scriptPubkey();

      // final internalWalletPolicy = wallet.policies(KeychainKind.internalChain);
      final Policy externalWalletPolicy =
          wallet.policies(KeychainKind.externalChain)!;

      // print(externalWalletPolicy.contribution());

      // printPrettyJson(internalWalletPolicy!.asString());
      // printPrettyJson(externalWalletPolicy!.asString());

      // const String targetFingerprint = "fb94d032";

      final Map<String, dynamic> policy =
          jsonDecode(externalWalletPolicy.asString());

      final path = extractAllPathsToFingerprint(policy, targetFingerprint);

      // print(path);

      if (chosenPath == 0) {
        // First Path: Direct MULTISIG
        multiSigPath = {
          for (int i = 0; i < path[0]["ids"].length - 1; i++)
            path[0]["ids"][i]: Uint32List.fromList([path[0]["indexes"][i]])
        };

        // print("Generated multiSigPath: $multiSigPath");
      } else {
        timeLockPath = {
          for (int i = 0; i < path[chosenPath!]["ids"].length - 1; i++)
            path[chosenPath]["ids"][i]: Uint32List.fromList(i ==
                    path[chosenPath]["ids"].length -
                        2 // Check if it's the second-to-last item
                ? [0, 1] // Select both indexes for the last `THRESH` node
                : [path[chosenPath]["indexes"][i]])
        };

        // print("Generated timeLockPath: $timeLockPath");
      }

      // Build the transaction:
      (PartiallySignedTransaction, TransactionDetails) txBuilderResult;

      if (isSendAllBalance) {
        print(amount.toInt());
        try {
          if (chosenPath == 0) {
            await txBuilder
                .addRecipient(recipientScript, amount)
                .policyPath(KeychainKind.internalChain, multiSigPath!)
                .policyPath(KeychainKind.externalChain, multiSigPath)
                .feeRate(feeRate.toDouble())
                .finish(wallet);
          } else {
            await txBuilder
                .addRecipient(recipientScript, amount)
                .policyPath(KeychainKind.internalChain, timeLockPath!)
                .policyPath(KeychainKind.externalChain, timeLockPath)
                .feeRate(feeRate.toDouble())
                .finish(wallet);
          }

          return amount.toString();
        } catch (e) {
          // print('Error: $e');

          final utxos = await getUtxos(wallet
              .getAddress(addressIndex: AddressIndex.peek(index: 0))
              .address
              .toString());

          // print(spendingPaths);
          // print(chosenPath);

          List<dynamic> spendableUtxos = [];

          if (chosenPath == 0) {
            spendableUtxos = utxos;
          } else {
            final timelock = spendingPaths![chosenPath!]['timelock'];
            print('Timelock value: $timelock');

            int currentHeight = await fetchCurrentBlockHeight();
            print('Current block height: $currentHeight');

            final spendableUtxos = utxos.where((utxo) {
              final blockHeight = utxo['status']['block_height'];
              print(
                  'Evaluating UTXO: txid=${utxo['txid']}, blockHeight=$blockHeight');

              final isSpendable = blockHeight != null &&
                  (blockHeight + timelock - 1 <= currentHeight ||
                      timelock == 0);

              print('Is spendable: $isSpendable');
              return isSpendable;
            }).toList();

            print('Spendable UTXOs found: ${spendableUtxos.length}');
            for (var spendableUtxo in spendableUtxos) {
              print(
                  'Spendable UTXO: txid=${spendableUtxo['txid']}, blockHeight=${spendableUtxo['status']['block_height']}');
            }
          }

          // Sum the value of spendable UTXOs
          final totalSpendableBalance = spendableUtxos.fold<int>(
            0,
            (sum, utxo) => sum + (utxo['value'] as int),
          );

          print('totalSpendableBalance: $totalSpendableBalance');
          // for (var spendableUtxo in spendableUtxos) {
          //   print("Spendable Outputs: ${spendableUtxo['txid']}");
          // }
          // Handle insufficient funds
          if (e.toString().contains("InsufficientFundsException")) {
            print(e);
            final RegExp regex = RegExp(r'Needed: (\d+),');
            final match = regex.firstMatch(e.toString());
            if (match != null) {
              final int neededAmount = int.parse(match.group(1)!);
              final int fee = neededAmount - amount.toInt();
              final int sendAllBalance = totalSpendableBalance - fee;

              if (sendAllBalance > 0) {
                return sendAllBalance
                    .toString(); // Return adjusted send all balance
              } else {
                throw Exception('No balance available after fee deduction');
              }
            } else {
              throw Exception('Failed to extract Needed amount from exception');
            }
          } else {
            rethrow; // Re-throw unhandled exceptions
          }
        }
      }
      print('Spending: $amount');

      final utxos = await getUtxos(wallet
          .getAddress(addressIndex: AddressIndex.peek(index: 0))
          .address
          .toString());

      spendingPaths = extractAllPaths(policy);

      if (chosenPath == 0) {
        spendableOutpoints = utxos
            .map((utxo) => OutPoint(txid: utxo['txid'], vout: utxo['vout']))
            .toList();
      } else {
        final timelock = spendingPaths[chosenPath!]['timelock'];
        print('Timelock value: $timelock');

        int currentHeight = await fetchCurrentBlockHeight();
        print('Current block height: $currentHeight');

        // Filter spendable UTXOs
        spendableOutpoints = utxos
            .where((utxo) {
              final blockHeight = utxo['status']['block_height'];
              return blockHeight != null &&
                  (blockHeight + timelock - 1 <= currentHeight ||
                      timelock == 0);
            })
            .map((utxo) => OutPoint(
                  txid: utxo['txid'],
                  vout: utxo['vout'],
                ))
            .toList();
      }

      print(spendableOutpoints);

      if (chosenPath == 0) {
        print('MultiSig Builder');
        txBuilderResult = await txBuilder
            // .enableRbf()
            .addUtxos(spendableOutpoints)
            .manuallySelectedOnly()
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, multiSigPath!)
            .policyPath(KeychainKind.externalChain, multiSigPath)
            .feeRate(
                feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        print('Transaction Built');
      } else {
        print('TimeLock Builder');
        for (var spendableOutpoint in spendableOutpoints) {
          print('Spendable Outputs: ${spendableOutpoint.txid}');
        }
        txBuilderResult = await txBuilder
            // .enableRbf()
            // .enableRbfWithSequence(olderValue)
            .addUtxos(spendableOutpoints)
            .manuallySelectedOnly()
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, timeLockPath!)
            .policyPath(KeychainKind.externalChain, timeLockPath)
            .feeRate(
                feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        print('Transaction Built');
      }

      try {
        final signed = await wallet.sign(
          psbt: txBuilderResult.$1,
          signOptions: const SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            removePartialSigs: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        if (signed) {
          print('Signing returned true');

          // printInChunks(txBuilderResult.$1.asString());

          print('Sending');
          final tx = txBuilderResult.$1.extractTx();

          for (var input in await tx.input()) {
            print("Input sequence number: ${input.previousOutput.txid}");
          }

          final isLockTime = await tx.isLockTimeEnabled();
          print('LockTime enabled: $isLockTime');

          final lockTime = await tx.lockTime();
          print('LockTime: $lockTime');

          await blockchain.broadcast(transaction: tx);
          print('Transaction sent');

          return null;
        } else {
          print('Signing returned false');

          final psbtString = base64Encode(txBuilderResult.$1.serialize());

          return psbtString;
        }
      } catch (broadcastError) {
        print("Broadcasting error: ${broadcastError.toString()}");
        throw Exception("Broadcasting error: ${broadcastError.toString()}");
      }
    } on Exception catch (e) {
      print("Error: ${e.toString()}");

      throw Exception("Error: ${e.toString()}");
    }
  }

  // This method takes a PSBT, signs it with the second user and then broadcasts it
  Future<String> signBroadcastTx(
    String psbtString,
    String descriptor,
    String mnemonic,
    int? chosenPath,
  ) async {
    Mnemonic trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) = await deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    descriptor = (chosenPath == 0)
        ? replacePubKeyWithPrivKeyMultiSig(
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          )
        : replacePubKeyWithPrivKeyOlder(
            chosenPath,
            descriptor,
            receivingPublicKey.toString(),
            receivingSecretKey.toString(),
          );

    wallet = await Wallet.create(
      descriptor: await Descriptor.create(
        descriptor: descriptor,
        network: network,
      ),
      network: network,
      databaseConfig: const DatabaseConfig.memory(),
    );

    await syncWallet(wallet);

    // Convert the psbt String to a PartiallySignedTransaction
    final psbt = await PartiallySignedTransaction.fromString(psbtString);

    printInChunks('Transaction Not Signed: $psbt');

    try {
      final signed = await wallet.sign(
        psbt: psbt,
        signOptions: const SignOptions(
          trustWitnessUtxo: false,
          allowAllSighashes: true,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: true,
          allowGrinding: true,
        ),
      );

      if (signed) {
        print('Signing returned true');
        final tx = psbt.extractTx();
        print('Extracting');

        final lockTime = await tx.lockTime();
        print('LockTime: $lockTime');

        for (var input in await tx.input()) {
          print("Input sequence number: ${input.sequence}");
        }

        final currentHeight = await blockchain.getHeight();
        print('Current height: $currentHeight');

        await blockchain.broadcast(transaction: tx);
        print('Transaction sent');
      } else {
        print('Signing returned false');
        // throw Exception('Not signed');
        return psbt.toString();
      }

      // printInChunks('Transaction after Signing: $psbt');

      return psbt.toString();
    } on Exception catch (e) {
      print("Error: ${e.toString()}");

      throw Exception("Error: ${e.toString()} psbt: $psbt");
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  ///
  /// UTILITIES
  ///
  ///
  ///
  ///
  ///
  ///
  ///

  void printInChunks(String text, {int chunkSize = 800}) {
    for (int i = 0; i < text.length; i += chunkSize) {
      print(text.substring(
          i, i + chunkSize > text.length ? text.length : i + chunkSize));
    }
  }

  void printPrettyJson(String jsonString) {
    final jsonObject = json.decode(jsonString);
    const encoder = JsonEncoder.withIndent('  ');
    printInChunks(encoder.convert(jsonObject));
  }

  String generateRandomName() {
    final random = Random();

    // Get random nouns and adjectives from the package
    final adjective = WordPair.random().first;
    final noun = WordPair.random().second;

    return '${adjective.capitalize()}${noun.capitalize()}${random.nextInt(1000)}';
  }
}

extension StringExtension on String {
  String capitalize() => this[0].toUpperCase() + substring(1);
}
