import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class WalletService {
  final WalletStorageService _walletStorageService = WalletStorageService();

  // Base URL for Mempool Space Testnet API
  final String baseUrl = 'https://mempool.space/testnet4/api';

  late Wallet wallet;

  List<String> electrumServers = [
    "ssl://mempool.space:40002",
    "ssl://blockstream.info:993",
    "ssl://tn.not.fyi:55002",
    "ssl://electrum.blockonomics.co:51002",
    "ssl://testnet.aranguren.org:51002"
  ];
  late Blockchain blockchain;

  TextEditingController mnemonic = TextEditingController();
  TextEditingController recipientAddress = TextEditingController();
  TextEditingController amount = TextEditingController();

  String? displayText;
  String? balance;
  String? address;
  String? ledgerBalance;
  String? availableBalance;

  final secureStorage = FlutterSecureStorage();

  Future<Mnemonic> generateMnemonicHandler() async {
    return await Mnemonic.create(WordCount.words12);
  }

  Future<DescriptorSecretKey> getSecretKeyfromMnemonic(String mnemonic) async {
    final mnemonicObj = await Mnemonic.fromString(mnemonic);

    // Create a descriptor secret key (this holds the seed/private key)
    final descriptorSecretKey = await DescriptorSecretKey.create(
      network: Network.testnet, // Use Network.Mainnet for main Bitcoin network
      mnemonic: mnemonicObj,
      password: '',
    );

    // debugPrint(descriptorSecretKey);

    // Define your derivation path (for example, BIP84 path for Testnet)
    String derivationPathString =
        "m/84'/1'/0'/0/0"; // For Testnet (m/84'/0'/0'/0/0 for Mainnet)

    // Create the derivation path object
    final derivationPath =
        await DerivationPath.create(path: derivationPathString);

    // debugPrint(derivationPath);

    // Specify the derivation path, e.g., "m/84'/1'/0'/0/0" for testnet or "m/84'/0'/0'/0/0" for mainnet
    final derivedSecretKey = await descriptorSecretKey.derive(derivationPath);

    return derivedSecretKey;
  }

  Future<DescriptorSecretKey> getInternalSecretKeyfromMnemonic(
      String mnemonic) async {
    final mnemonicObj = await Mnemonic.fromString(mnemonic);

    // Create a descriptor secret key (this holds the seed/private key)
    final descriptorSecretKey = await DescriptorSecretKey.create(
      network: Network.testnet,
      mnemonic: mnemonicObj,
      password: '',
    );

    // debugPrint(descriptorSecretKey);

    String derivationPathString = "m/84'/1'/0'/1/0";

    // Create the derivation path object
    final derivationPath =
        await DerivationPath.create(path: derivationPathString);

    // debugPrint(derivationPath);

    final derivedSecretKey = await descriptorSecretKey.derive(derivationPath);

    return derivedSecretKey;
  }

  Future<List<Descriptor>> getDescriptors(String mnemonic) async {
    final descriptors = <Descriptor>[];
    try {
      for (var e in [KeychainKind.externalChain, KeychainKind.internalChain]) {
        final mnemonicObj = await Mnemonic.fromString(mnemonic);

        final descriptorSecretKey = await DescriptorSecretKey.create(
          network: Network.testnet,
          mnemonic: mnemonicObj,
        );

        final descriptor = await Descriptor.newBip84(
          secretKey: descriptorSecretKey,
          network: Network.testnet,
          keychain: e,
        );

        descriptors.add(descriptor);
      }
      return descriptors;
    } on Exception catch (e) {
      // debugPrint("Error: ${e.toString()}");
      throw ("Error: ${e.toString()}");
    }
  }

  Future<Wallet> createOrRestoreWallet(
      String mnemonic, Network network, String? password) async {
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

      // debugPrint(res);

      return res;
    } on Exception catch (e) {
      // debugPrint("Error: ${e.toString()}");
      throw Exception('Failed to create wallet (Error: ${e.toString()})');
    }
  }

  Future<Wallet> createSharedWallet(
    String descriptorStr,
    String internalDescriptor,
    String mnemonic,
    Network network,
    String? password,
  ) async {
    try {
      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        await blockchainInit();
      }

      final descriptorWallet = await Descriptor.create(
        descriptor: descriptorStr,
        network: network, // Use Network.Mainnet for mainnet
      );

      // final internalDescriptorWallet = await bdk.Descriptor.newBip84(
      //   secretKey: await getInternalSecretKeyfromMnemonic(mnemonic),
      //   network: network,
      //   keychain: bdk.KeychainKind.Internal,
      // );

      // debugPrint('Ciaooooooooo ' + internalDescriptor);

      final internalDescriptorWallet = await Descriptor.create(
        descriptor: internalDescriptor,
        network: network,
      );

      // debugPrint('Ciaoooooooooooooo');

      final wallet = await Wallet.create(
        descriptor: descriptorWallet,
        changeDescriptor: internalDescriptorWallet,
        network: network,
        databaseConfig: const DatabaseConfig.memory(),
      );

      return wallet;
    } on Exception catch (e) {
      // debugPrint("Error: ${e.toString()}");
      throw Exception('Failed to create wallet (Error: ${e.toString()})');
    }
  }

  BigInt getBalance(Wallet wallet) {
    // await syncWallet(wallet);
    Balance balance = wallet.getBalance();

    // debugPrint(balance.total);

    return balance.total;
  }

  Future<int> getLedgerBalance(String address) async {
    final memPoolUrl = '$baseUrl/address/$address';

    // debugPrint(address);

    final response = await http.get(Uri.parse(memPoolUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // debugPrint(response.body);

      // Ledger Balance: chain_stats
      // (founded txo_sum - spent_txo_sum)
      int chainFundedTxoSum =
          jsonResponse['chain_stats']['funded_txo_sum'] as int;
      int chainSpentTxoSum =
          jsonResponse['chain_stats']['spent_txo_sum'] as int;

      // debugPrint(chainSpentTxoSum);
      // debugPrint(chainFundedTxoSum);

      int ledgerJsonBalance = chainFundedTxoSum - chainSpentTxoSum;

      // debugPrint("Ledger Balance: " + ledgerJsonBalance.toString());

      return ledgerJsonBalance;
    } else {
      throw Exception('Failed to fetch ledger balance');
    }
  }

  Future<int> getAvailableBalance(String address) async {
    final memPoolUrl = '$baseUrl/address/$address';

    final response = await http.get(Uri.parse(memPoolUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // debugPrint(response.body);

      // Available Balance: mempool_stats
      // Ledger Balance + (founded_txo_sum - spent_txo_sum)
      int memFundedTxoSum =
          jsonResponse['mempool_stats']['funded_txo_sum'] as int;
      int memSpentTxoSum =
          jsonResponse['mempool_stats']['spent_txo_sum'] as int;

      int ledgerJsonBalance = await getLedgerBalance(address);

      int availableJsonBalance =
          (ledgerJsonBalance + (memFundedTxoSum - memSpentTxoSum));

      // debugPrint("Available Balance: " + availableJsonBalance.toString());

      return availableJsonBalance;
    } else {
      throw Exception('Failed to fetch available balance');
    }
  }

  Future<Wallet> loadSavedWallet(String? mnemonic) async {
    var walletBox = Hive.box('walletBox');
    String? savedMnemonic = walletBox.get('walletMnemonic');

    // debugPrint(savedMnemonic);

    if (savedMnemonic != null) {
      // Restore the wallet using the saved mnemonic
      wallet = await createOrRestoreWallet(
        savedMnemonic,
        Network.testnet,
        null, // Use a saved password if required
      );
      // debugPrint(wallet);
      return wallet;
    } else {
      wallet = await createOrRestoreWallet(
        mnemonic!,
        Network.testnet,
        null,
      );
    }
    return wallet;
  }

  Future<void> saveLocalData(Wallet wallet) async {
    String currentAddress = getAddress(wallet);

    final walletData = WalletData(
      address: currentAddress,
      balance: int.parse(getBalance(wallet).toString()),
      ledgerBalance: await getLedgerBalance(currentAddress),
      availableBalance: await getAvailableBalance(currentAddress),
      transactions: await getTransactions(currentAddress),
    );

    // Save the data to Hive
    await _walletStorageService.saveWalletData(currentAddress, walletData);
  }

  Future<void> syncWallet(Wallet wallet) async {
    await blockchainInit(); // Ensure blockchain is initialized before usage

    await wallet.sync(blockchain: blockchain);
  }

  String getAddress(Wallet wallet) {
    // await syncWallet(wallet);

    var addressInfo =
        wallet.getAddress(addressIndex: const AddressIndex.peek(index: 0));
    return addressInfo.address.asString();
  }

  // Method to create, sign and broadcast a single user transaction
  Future<void> sendTx(
    String recipientAddressStr,
    BigInt amount,
    Wallet wallet,
    String changeAddressStr,
  ) async {
    await syncWallet(wallet);

    // final utxos = await wallet.getBalance();
    // debugPrint("Available UTXOs: ${utxos.total}");

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      // Create recipient address
      // final recipientAddress =
      //     await Address.create(address: recipientAddressStr);
      // final recipientScript = await recipientAddress.scriptPubKey();

      // Create the change address
      // final changeAddress = await Address.create(address: changeAddressStr);
      // final changeScript = await changeAddress.scriptPubKey();

      final recipientAddress = await Address.fromString(
          s: recipientAddressStr, network: wallet.network());
      final recipientScript = recipientAddress.scriptPubkey();
      // final feeRate = await estimateFeeRate(25, blockchain);

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
      // debugPrint("Error: ${e.toString()}");
      throw Exception('Failed to send Transaction (Error: ${e.toString()})');
    }
  }

  // Method to create a PSBT for a multisig transaction, this psbt is signed by the first user
  Future<String?> createPartialTx(
    String recipientAddressStr,
    BigInt amount,
    Wallet wallet,
    int olderValue,
    bool multiSig,
  ) async {
    await syncWallet(wallet);

    final utxos = wallet.getBalance();
    debugPrint("Available UTXOs: ${utxos.confirmed}");

    final unspent = wallet.listUnspent();
    final feeRate = await getFeeRate();

    final totalSpending = amount + BigInt.from(feeRate);
    debugPrint("Total Spending: $totalSpending");

    // Filter out unconfirmed UTXOs
    if (utxos.confirmed < totalSpending) {
      // Exit early if no confirmed UTXOs are available
      throw Exception(
          "Not enough confirmed funds available. Please wait until your transactions confirm.");
    }

    for (var utxo in unspent) {
      debugPrint('UTXO: ${utxo.outpoint.txid}, Amount: ${utxo.txout.value}');
    }

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      final recipientAddress = await Address.fromString(
          s: recipientAddressStr, network: wallet.network());
      final recipientScript = recipientAddress.scriptPubkey();

      final internalChangeAddress = wallet.getInternalAddress(
          addressIndex: const AddressIndex.peek(index: 0));
      final changeScript = internalChangeAddress.address.scriptPubkey();

      final internalWalletPolicy = wallet.policies(KeychainKind.internalChain);
      final externalWalletPolicy = wallet.policies(KeychainKind.externalChain);

      // debugPrintPrettyJson(internalWalletPolicy!.asString());
      // debugPrintPrettyJson(externalWalletPolicy!.asString());

      String policyString = externalWalletPolicy!.asString();

      // Regular expression to capture both "id" and "type" fields
      RegExp idTypePattern = RegExp(r'"id":\s*"(\w+)",\s*"type":\s*"(\w+)"');
      List<Map<String, String>> idTypePairs = [];

      // Extract both ID and type pairs
      for (final match in idTypePattern.allMatches(policyString)) {
        String id = match.group(1)!;
        String type = match.group(2)!;
        idTypePairs.add({"id": id, "type": type});
      }

      debugPrint("Extracted ID and Type pairs: $idTypePairs");

      RegExp timeLockPattern = RegExp(
          r'"id":\s*"(\w+)",\s*"type":\s*"RELATIVETIMELOCK",\s*"value":\s*(\d+)');
      List<Map<String, String>> timeLockPairs = [];

      // Extract IDs, types, and values
      for (final match in timeLockPattern.allMatches(policyString)) {
        String id = match.group(1)!; // Extract the "id"
        String value = match.group(2)!; // Extract the "value" as a string
        timeLockPairs.add({"id": id, "value": value});
      }

      // Extract only the IDs where the value is olderValue
      String timeLockId = timeLockPairs
          .firstWhere((pair) => pair["value"] == olderValue.toString())["id"]!;

      debugPrint("TimeLock ID: $timeLockId");

      // Extract only the IDs where the type is "THRESH"
      List<String> threshIds = idTypePairs
          .where((pair) => pair["type"] == "THRESH")
          .map((pair) => pair["id"]!)
          .toList();

      // threshIds.removeWhere((id) => id == timeLockId);

      debugPrint("THRESH IDs: $threshIds");

      // Extract IDs using a regular expression
      RegExp idPattern = RegExp(r'"id":\s*"(\w+)"');
      List<String> ids = [];

      for (final match in idPattern.allMatches(policyString)) {
        ids.add(match.group(1)!);
      }

      debugPrint("Extracted IDs: $ids");

      int index = ids.indexOf(timeLockId);

      String? previousId = ids[index - 1];

      debugPrint("Previous ID: $previousId");

      int timeLockIndex = threshIds.indexOf(previousId);

      debugPrint('timeLock Index: $timeLockIndex');
      int correctIndex = 0;

      if (timeLockIndex == 3) {
        correctIndex = 1;
      } else if (timeLockIndex == 2) {
        correctIndex = 0;
      }

      // Use IDs as needed
      Map<String, Uint32List> timeLockPath = {
        threshIds[0]:
            Uint32List.fromList([1]), // Top-level THRESH (selects second item)
        threshIds[1]: Uint32List.fromList(
            [correctIndex]), // Nested THRESH containing timelock
        threshIds[timeLockIndex]:
            Uint32List.fromList([0, 1]) // Satisfies both timelock and signature
      };

      debugPrint("Generated timeLockPath: $timeLockPath");

      Map<String, Uint32List> multiSigPath = {
        externalWalletPolicy.id():
            Uint32List.fromList([0]), // Returns the MULTISIG path
      };

      debugPrint("Generated multiSigPath: $multiSigPath");

      // Build the transaction:
      (PartiallySignedTransaction, TransactionDetails) txBuilderResult;

      if (multiSig) {
        debugPrint('MultiSig Builder');
        txBuilderResult = await txBuilder
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, multiSigPath)
            .policyPath(KeychainKind.externalChain, multiSigPath)
            .feeRate(
                feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        debugPrint('Transaction Built');

        // debugPrint('PSBT Before Signing: ');
        // debugPrintInChunks(txBuilderResult.$1.toString());

        final signed = await wallet.sign(
          psbt: txBuilderResult.$1,
          signOptions: const SignOptions(
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            removePartialSigs: false,
            tryFinalize: false,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        if (signed) {
          debugPrint('Signing returned true');
        } else {
          debugPrint('Signing returned false');
        }

        // debugPrint('PSBT After Signing: ');
        // debugPrintInChunks(txBuilderResult.$1.toString());
      } else {
        debugPrint('TimeLock Builder');
        txBuilderResult = await txBuilder
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, timeLockPath)
            .policyPath(KeychainKind.externalChain, timeLockPath)
            .feeRate(
                feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        debugPrint('Transaction Built');

        // debugPrint('PSBT Before Signing: ');
        // debugPrintInChunks(txBuilderResult.$1.toString());

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
          debugPrint('Signing returned true');
        } else {
          debugPrint('Signing returned false');
        }

        // debugPrint('PSBT After Signing: ');
        // debugPrintInChunks(txBuilderResult.$1.toString());
      }

      try {
        if (multiSig) {
          debugPrint('MultiSig Broadcast');

          final psbtString = base64Encode(txBuilderResult.$1.serialize());

          // debugPrint('Encoded: ');
          // debugPrintInChunks(psbtString);

          return psbtString;
        } else {
          debugPrint('TimeLock Broadcast');

          debugPrint('Sending');
          final tx = txBuilderResult.$1.extractTx();

          for (var input in await tx.input()) {
            debugPrint("Input sequence number: ${input.sequence}");
          }
          final isLockTime = await tx.isLockTimeEnabled();
          debugPrint('LockTime enabled: $isLockTime');
          final lockTime = await tx.lockTime();
          debugPrint('LockTime: $lockTime');

          await blockchain.broadcast(transaction: tx);
          debugPrint('Transaction sent');
          return null;
        }
      } catch (broadcastError) {
        throw Exception("Broadcasting error: ${broadcastError.toString()}");
      }
    } on Exception catch (e) {
      print("Error: ${e.toString()}");

      throw Exception("Error: ${e.toString()}");
    }
  }

  void debugPrintInChunks(String text, {int chunkSize = 800}) {
    for (int i = 0; i < text.length; i += chunkSize) {
      debugPrint(text.substring(
          i, i + chunkSize > text.length ? text.length : i + chunkSize));
    }
  }

  void debugPrintPrettyJson(String jsonString) {
    final jsonObject = json.decode(jsonString);
    const encoder = JsonEncoder.withIndent('  ');
    debugPrintInChunks(encoder.convert(jsonObject));
  }

  // This method takes a PSBT, signs it with the second user and then broadcasts it
  Future<String> signBroadcastTx(String psbtString, Wallet wallet) async {
    await syncWallet(wallet);

    // Convert the psbt String to a PartiallySignedTransaction
    final psbt = await PartiallySignedTransaction.fromString(psbtString);

    debugPrintInChunks('Transaction Not Signed: $psbt');

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
        debugPrint('Signing returned true');
      } else {
        debugPrint('Signing returned false');
      }

      debugPrintInChunks('Transaction Signed: $psbt');

      final tx = psbt.extractTx();
      debugPrint('Extracting');

      final lockTime = await tx.lockTime();

      print('LockTime: $lockTime');
      for (var input in await tx.input()) {
        debugPrint("Input sequence number: ${input.sequence}");
      }

      final currentHeight = await blockchain.getHeight();
      debugPrint('Current height: $currentHeight');

      await blockchain.broadcast(transaction: tx);
      debugPrint('Transaction sent');

      return psbt.toString();
    } on Exception catch (e) {
      print("Error: ${e.toString()}");

      throw Exception("Error: ${e.toString()}");
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
              validateDomain: false,
            ),
          ),
        );
        debugPrint("Connected to Electrum server: $url");
        return;
      } catch (e) {
        debugPrint(
            "Failed to connect to Electrum server: $url, trying next...");
      }
    }
    throw Exception("Failed to connect to any Electrum server.");
  }

  Future<int> getFeeRate() async {
    final memPoolUrl = '$baseUrl/v1/fees/recommended';

    final response = await http.get(Uri.parse(memPoolUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // debugPrint(response.body);

      int feeRate = jsonResponse['halfHourFee'];

      // debugPrint('FeeRate: $feeRate');

      return feeRate + 4;
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

      // Check if the response was successful (status code 200)
      if (response.statusCode == 200) {
        // Parse the JSON response
        List<dynamic> transactionsJson = jsonDecode(response.body);

        // Cast to List<Map<String, dynamic>> for easier processing
        List<Map<String, dynamic>> transactions =
            List<Map<String, dynamic>>.from(transactionsJson);

        // Return the list of transactions
        return transactions;
      } else {
        throw Exception(
            'Failed to load transactions. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      // debugPrint('Error: $e');
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
}
