import 'dart:convert';
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

    // Define the timelock conditions for Bob and Alice
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
      // debugPrint("Error: ${e.toString()}");
      throw Exception('Failed to send Transaction (Error: ${e.toString()})');
    }
  }

  String replacePubKeyWithPrivKeyMultiSig(
      String descriptor, String pubKey, String privKey) {
    // Extract the derivation path and pubkey portion for dynamic matching
    final regexPathPub = RegExp.escape('${pubKey.split(']')[0]}]') +
        r'tpub[A-Za-z0-9]+\/\d+\/\*';

    // Create a regex to match the exact pubKey
    final regex = RegExp(regexPathPub);

    // Replace only the matching public key with the private key
    return descriptor.replaceFirstMapped(regex, (match) {
      return privKey;
    });
  }

  String replacePubKeyWithPrivKeyOlder(
      String descriptor, String pubKey, String privKey) {
    // Extract the derivation path prefix and ensure we match tpub keys with trailing paths
    final regexPathPub = RegExp(
      RegExp.escape('${pubKey.split(']')[0]}]') +
          r'tpub[A-Za-z0-9]+\/(\d+)\/\*',
    );

    int matchCounter = 0;

    // Replace all matches dynamically
    return descriptor.replaceAllMapped(regexPathPub, (match) {
      matchCounter++;
      // Capture the derivation index (e.g., "0" or "1")

      // Update the path for the second match to use "/1/*"
      if (matchCounter == 2) {
        return '${privKey.substring(0, privKey.length - 4)}/1/*';
      } else {
        return pubKey;
      }
    });
  }

  Future<(DescriptorSecretKey, DescriptorPublicKey)> deriveDescriptorKeys(
    DerivationPath hardenedPath,
    DerivationPath unHardenedPath,
    Mnemonic mnemonic,
  ) async {
    // Create the root secret key from the mnemonic
    final secretKey = await DescriptorSecretKey.create(
      network: Network.testnet,
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
        RegExp(r'older\((\d+)\).*?pk\(\[.*?](tp(?:rv|ub)[a-zA-Z0-9]+)');
    final matches = regExp.allMatches(descriptor);

    int older = 0;

    for (var match in matches) {
      String olderValue = match.group(1)!; // Extract the older value
      String keyType = match.group(2)!; // Capture whether it's tprv or tpub

      // Only process the match if it's a private key (tprv)
      if (keyType.startsWith("tprv")) {
        debugPrint(
            'Found older value associated with private key: $olderValue');
        older = int.parse(olderValue);
      }
    }

    return older;
  }

  // Method to create a PSBT for a multisig transaction, this psbt is signed by the first user
  Future<String?> createPartialTx(
    String descriptor,
    String mnemonic,
    String recipientAddressStr,
    BigInt amount,
    bool multiSig,
  ) async {
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

    if (multiSig) {
      descriptor = replacePubKeyWithPrivKeyMultiSig(
        descriptor,
        receivingPublicKey.toString(),
        receivingSecretKey.toString(),
      );

      wallet = await Wallet.create(
        descriptor: await Descriptor.create(
          descriptor: descriptor,
          network: Network.testnet,
        ),
        network: Network.testnet,
        databaseConfig: const DatabaseConfig.memory(),
      );
    } else {
      descriptor = replacePubKeyWithPrivKeyOlder(
        descriptor,
        receivingPublicKey.toString(),
        receivingSecretKey.toString(),
      );

      // print('Timelock Descriptor: $descriptor');

      // print('PubKey: ${receivingPublicKey.toString()}');
      // print('PrivKey: ${receivingSecretKey.toString()}');

      wallet = await Wallet.create(
        descriptor: await Descriptor.create(
          descriptor: descriptor,
          network: Network.testnet,
        ),
        network: Network.testnet,
        databaseConfig: const DatabaseConfig.memory(),
      );
    }

    final olderValue = await extractOlderWithPrivateKey(descriptor);

    await syncWallet(wallet);

    final utxos = wallet.getBalance();
    debugPrint("Available UTXOs: ${utxos.confirmed}");

    final unspent = wallet.listUnspent();
    final feeRate = await getFeeRate();

    final totalSpending = amount + BigInt.from(feeRate);
    debugPrint("Total Spending: $totalSpending");

    // Check If there are enough funds available
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

      var internalChangeAddress = wallet.getInternalAddress(
          addressIndex: const AddressIndex.peek(index: 0));

      final changeScript = internalChangeAddress.address.scriptPubkey();

      // final internalWalletPolicy = wallet.policies(KeychainKind.internalChain);
      final externalWalletPolicy = wallet.policies(KeychainKind.externalChain);

      // debugPrintPrettyJson(internalWalletPolicy!.asString());
      // debugPrintPrettyJson(externalWalletPolicy!.asString());

      if (multiSig) {
        multiSigPath = {
          externalWalletPolicy!.id():
              Uint32List.fromList([0]), // Returns the MULTISIG path
        };

        debugPrint("Generated multiSigPath: $multiSigPath");
      } else {
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
        String timeLockId = timeLockPairs.firstWhere(
            (pair) => pair["value"] == olderValue.toString())["id"]!;

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
        timeLockPath = {
          threshIds[0]: Uint32List.fromList(
              [1]), // Top-level THRESH (selects second item)
          threshIds[1]: Uint32List.fromList(
              [correctIndex]), // Nested THRESH containing timelock
          threshIds[timeLockIndex]: Uint32List.fromList(
              [0, 1]) // Satisfies both timelock and signature
        };

        debugPrint("Generated timeLockPath: $timeLockPath");
      }

      // Build the transaction:
      (PartiallySignedTransaction, TransactionDetails) txBuilderResult;

      if (multiSig) {
        debugPrint('MultiSig Builder');
        txBuilderResult = await txBuilder
            // .enableRbf()
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, multiSigPath!)
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
            // .enableRbf()
            // .enableRbfWithSequence(olderValue)
            .addRecipient(recipientScript, amount) // Send to recipient
            .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
            .policyPath(KeychainKind.internalChain, timeLockPath!)
            .policyPath(KeychainKind.externalChain, timeLockPath)
            .feeRate(
                feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
            .drainTo(changeScript) // Specify the address to send the change
            .finish(wallet); // Finalize the transaction with wallet's UTXOs

        debugPrint('Transaction Built');

        debugPrint('PSBT Before Signing: ');
        debugPrintInChunks(txBuilderResult.$1.toString());

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

        debugPrint('PSBT After Signing: ');
        debugPrintInChunks(txBuilderResult.$1.toString());
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
  Future<String> signBroadcastTx(
    String psbtString,
    String descriptor,
    String mnemonic,
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

    descriptor = replacePubKeyWithPrivKeyMultiSig(
      descriptor,
      receivingPublicKey.toString(),
      receivingSecretKey.toString(),
    );

    wallet = await Wallet.create(
      descriptor: await Descriptor.create(
        descriptor: descriptor,
        network: Network.testnet,
      ),
      network: Network.testnet,
      databaseConfig: const DatabaseConfig.memory(),
    );

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
        // throw Exception('Not signed');
      }

      debugPrintInChunks('Transaction after Signing: $psbt');

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

      throw Exception("Error: ${e.toString()} psbt: $psbt");
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
