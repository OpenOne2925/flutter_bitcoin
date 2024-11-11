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

    // print(descriptorSecretKey);

    // Define your derivation path (for example, BIP84 path for Testnet)
    String derivationPathString =
        "m/84'/1'/0'/0/0"; // For Testnet (m/84'/0'/0'/0/0 for Mainnet)

    // Create the derivation path object
    final derivationPath =
        await DerivationPath.create(path: derivationPathString);

    // print(derivationPath);

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

    // print(descriptorSecretKey);

    String derivationPathString = "m/84'/1'/0'/1/0";

    // Create the derivation path object
    final derivationPath =
        await DerivationPath.create(path: derivationPathString);

    // print(derivationPath);

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
      // print("Error: ${e.toString()}");
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

      // print(res);

      return res;
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
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

      // print('Ciaooooooooo ' + internalDescriptor);

      final internalDescriptorWallet = await Descriptor.create(
        descriptor: internalDescriptor,
        network: network,
      );

      // print('Ciaoooooooooooooo');

      final wallet = await Wallet.create(
        descriptor: descriptorWallet,
        changeDescriptor: internalDescriptorWallet,
        network: network,
        databaseConfig: const DatabaseConfig.memory(),
      );

      return wallet;
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw Exception('Failed to create wallet (Error: ${e.toString()})');
    }
  }

  BigInt getBalance(Wallet wallet) {
    // await syncWallet(wallet);
    Balance balance = wallet.getBalance();

    // print(balance.total);

    return balance.total;
  }

  Future<int> getLedgerBalance(String address) async {
    final memPoolUrl = '$baseUrl/address/$address';

    // print(address);

    final response = await http.get(Uri.parse(memPoolUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // print(response.body);

      // Ledger Balance: chain_stats
      // (founded txo_sum - spent_txo_sum)
      int chainFundedTxoSum =
          jsonResponse['chain_stats']['funded_txo_sum'] as int;
      int chainSpentTxoSum =
          jsonResponse['chain_stats']['spent_txo_sum'] as int;

      // print(chainSpentTxoSum);
      // print(chainFundedTxoSum);

      int ledgerJsonBalance = chainFundedTxoSum - chainSpentTxoSum;

      // print("Ledger Balance: " + ledgerJsonBalance.toString());

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

      // print(response.body);

      // Available Balance: mempool_stats
      // Ledger Balance + (founded_txo_sum - spent_txo_sum)
      int memFundedTxoSum =
          jsonResponse['mempool_stats']['funded_txo_sum'] as int;
      int memSpentTxoSum =
          jsonResponse['mempool_stats']['spent_txo_sum'] as int;

      int ledgerJsonBalance = await getLedgerBalance(address);

      int availableJsonBalance =
          (ledgerJsonBalance + (memFundedTxoSum - memSpentTxoSum));

      // print("Available Balance: " + availableJsonBalance.toString());

      return availableJsonBalance;
    } else {
      throw Exception('Failed to fetch available balance');
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
        Network.testnet,
        null, // Use a saved password if required
      );
      // print(wallet);
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
    // print("Available UTXOs: ${utxos.total}");

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

      // TODO: should work correctly, still needs testing

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
      // print("Error: ${e.toString()}");
      throw Exception('Failed to create wallet (Error: ${e.toString()})');
    }
  }

  // Method to create a PSBT for a multisig transaction, this psbt is signed by the first user
  Future<String> createPartialTx(
    String recipientAddressStr,
    BigInt amount,
    Wallet wallet,
  ) async {
    await syncWallet(wallet);

    final utxos = wallet.getBalance();
    print("Available UTXOs: ${utxos.spendable}");

    final unspent = wallet.listUnspent();

    for (var utxo in unspent) {
      print('UTXO: ${utxo.outpoint.txid}, Amount: ${utxo.txout.value}');
    }

    try {
      // Build the transaction
      final txBuilder = TxBuilder();

      // const String timelockDescriptor =
      //     "wsh(and_v(v:older(2),pk([24d87569/84'/1'/0'/0/0]tpubDHebJGZWZaZ3JkhwTx5DytaRpFhK9ffFaN9PMBm7m63bdkdxqKgXkSPMzYzfDAGStx8LWt4b2CgGm86BwtNuG6PdsxsLVmuf6EjREX3oHjL/1/*)))";

      // final descriptor = await Descriptor.create(
      //   descriptor: timelockDescriptor,
      //   network: Network.Testnet,
      // );

      // final wallet2 = await Wallet.create(
      //   descriptor: descriptor,
      //   network: Network.Testnet,
      //   databaseConfig: DatabaseConfig.memory(),
      // );

      // Create recipient address
      // final recipientAddress =
      //     await Address.create(address: recipientAddressStr);
      // final recipientScript = await recipientAddress.scriptPubKey();

      // final changeAddressStr = await getAddress(wallet);

      // print(changeAddressStr);

      // print('Nope: ${internalChangeAddress.index}');

      // Create the change address
      // final changeAddress =
      //     await Address.create(address: internalChangeAddress.address);
      // final changeScript = await changeAddress.scriptPubKey();

      // print(internalChangeAddress.address);
      // print('Ciao');

      final recipientAddress = await Address.fromString(
          s: recipientAddressStr, network: wallet.network());
      final recipientScript = recipientAddress.scriptPubkey();
      // final feeRate = await estimateFeeRate(25, blockchain);

      final internalChangeAddress = wallet.getInternalAddress(
          addressIndex: const AddressIndex.peek(index: 0));
      final changeScript = internalChangeAddress.address.scriptPubkey();

      final feeRate = await getFeeRate();

      // 'multiSigId': Uint32List.fromList([0, 1]),    // Example multi-sig node ID
      // 'timeLockId2': Uint32List.fromList([0]),      // Example `older(2)` node ID
      // 'timeLockId6': Uint32List.fromList([1]),      // Example `older(6)` node ID

      final internalWalletPolicy = wallet.policies(KeychainKind.internalChain);
      final externalWalletPolicy = wallet.policies(KeychainKind.externalChain);

      printPrettyJson(internalWalletPolicy!.asString());
      printPrettyJson(externalWalletPolicy!.asString());
      print("Contribution: ${externalWalletPolicy.contribution()}");
      print("Satisfaction: ${externalWalletPolicy.satisfaction()}");
      print("Item: ${externalWalletPolicy.item()}");
      print("Requires Path: ${externalWalletPolicy.requiresPath()}");

      // Define paths for each part of the policy
      Map<String, Uint32List> intPath = {
        internalWalletPolicy.id(): Uint32List.fromList([0]),
      };

      // Define paths for each part of the policy
      Map<String, Uint32List> extPath = {
        externalWalletPolicy.id(): Uint32List.fromList([0]),
      };

      debugPrint("Internal policy Path: $intPath\n");

      debugPrint("External policy Path: $extPath\n");

      // Build the transaction:
      // - Send `amount` to the recipient
      // - Any remaining funds (change) will be sent to the change address
      // TODO SharedWallet with timelocks .policyPath to be added now available
      final txBuilderResult = await txBuilder
          // .enableRbf()
          .enableRbfWithSequence(2)
          .addRecipient(recipientScript, amount) // Send to recipient
          .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
          // .doNotSpendChange()
          .policyPath(KeychainKind.internalChain, intPath)
          .policyPath(KeychainKind.externalChain, extPath)
          .feeRate(
              feeRate.toDouble()) // Set the fee rate (in satoshis per byte)
          .drainTo(changeScript) // Specify the address to send the change
          .finish(wallet); // Finalize the transaction with wallet's UTXOs

      print('Signing');

      try {
        final psbt = await wallet.sign(
          psbt: txBuilderResult.$1,
          signOptions: const SignOptions(
            // assumeHeight: 54235,
            trustWitnessUtxo: false,
            allowAllSighashes: true,
            removePartialSigs: true,
            tryFinalize: true,
            signWithTapInternalKey: true,
            allowGrinding: true,
          ),
        );

        print('Sending');

        if (psbt) {
          final tx = txBuilderResult.$1.extractTx();

          for (var input in await tx.input()) {
            print("Input sequence number: ${input.sequence}");
          }
          final isLockTime = await tx.isLockTimeEnabled();
          print('LockTime enabled: $isLockTime');
          final lockTime = await tx.lockTime();
          print('LockTime: ${lockTime}');

          try {
            await blockchain.broadcast(transaction: tx);
            print('Transaction sent');

            final psbtString = txBuilderResult.$1.asString();

            return psbtString;
          } catch (broadcastError) {
            throw Exception("Broadcasting error: ${broadcastError.toString()}");
          }
        } else {
          print("Signing failed: Wallet returned false on sign attempt.");
          throw Exception(
              "Signing process returned false, possible policy path or UTXO mismatch.");
        }
      } catch (signingError) {
        throw Exception(
            "Transaction signing error: ${signingError.toString()}");
      }
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw Exception("Error: ${e.toString()}");
    }
  }

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

  // This method takes a PSBT, signs it with the second user and then broadcasts it
  Future<void> signBroadcastTx(String psbtString, Wallet wallet) async {
    // Convert the psbt String to a PartiallySignedTransaction
    final psbt = await PartiallySignedTransaction.fromString(psbtString);

    try {
      final isFinalized = await wallet.sign(
        psbt: psbt,
        signOptions: const SignOptions(
          trustWitnessUtxo: false,
          allowAllSighashes: false,
          removePartialSigs: false,
          tryFinalize: false,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      if (isFinalized) {
        final tx = psbt.extractTx();
        await blockchain.broadcast(transaction: tx);
      } else {
        debugPrint("Psbt not finalized!");
      }
    } on Exception catch (e) {
      throw Exception("Error: ${e.toString()}");
    }
  }

  Future<void> blockchainInit() async {
    blockchain = await Blockchain.create(
      config: BlockchainConfig.electrum(
        config: ElectrumConfig(
          // url: "ssl://electrum.blockstream.info:50002",
          url: "ssl://mempool.space:40002",
          timeout: 5,
          retry: 5,
          stopGap: BigInt.from(10),
          validateDomain: false,
        ),
      ),
    );
  }

  Future<int> getFeeRate() async {
    final memPoolUrl = '$baseUrl/v1/fees/recommended';

    final response = await http.get(Uri.parse(memPoolUrl));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // print(response.body);

      int feeRate = jsonResponse['halfHourFee'];

      // print('FeeRate: $feeRate');

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
      // print('Error: $e');
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
