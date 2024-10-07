import 'dart:convert';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/services/wallet_storage_service.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class WalletService {
  final WalletStorageService _walletStorageService = WalletStorageService();

  // Base URL for Mempool Space Testnet API
  final String baseUrl = 'https://mempool.space/testnet/api';

  late bdk.Wallet wallet;
  late bdk.Blockchain blockchain;

  TextEditingController mnemonic = TextEditingController();
  TextEditingController recipientAddress = TextEditingController();
  TextEditingController amount = TextEditingController();

  String? displayText;
  String? balance;
  String? address;
  String? ledgerBalance;
  String? availableBalance;

  Future<bdk.Mnemonic> generateMnemonicHandler() async {
    return await bdk.Mnemonic.create(bdk.WordCount.Words12);
  }

  Future<bdk.DescriptorSecretKey> getSecretKeyfromMnemonic(
      String mnemonic) async {
    final mnemonicObj = await bdk.Mnemonic.fromString(mnemonic);

    // Create a descriptor secret key (this holds the seed/private key)
    final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
      network:
          bdk.Network.Testnet, // Use Network.Mainnet for main Bitcoin network
      mnemonic: mnemonicObj,
      password: '',
    );

    // print(descriptorSecretKey);

    // Define your derivation path (for example, BIP84 path for Testnet)
    String derivationPathString =
        "m/84'/1'/0'/0/0"; // For Testnet (m/84'/0'/0'/0/0 for Mainnet)

    // Create the derivation path object
    final derivationPath =
        await bdk.DerivationPath.create(path: derivationPathString);

    // print(derivationPath);

    // Specify the derivation path, e.g., "m/84'/1'/0'/0/0" for testnet or "m/84'/0'/0'/0/0" for mainnet
    final derivedSecretKey = await descriptorSecretKey.derive(derivationPath);

    return derivedSecretKey;
  }

  Future<bdk.DescriptorSecretKey> getInternalSecretKeyfromMnemonic(
      String mnemonic) async {
    final mnemonicObj = await bdk.Mnemonic.fromString(mnemonic);

    // Create a descriptor secret key (this holds the seed/private key)
    final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
      network: bdk.Network.Testnet,
      mnemonic: mnemonicObj,
      password: '',
    );

    // print(descriptorSecretKey);

    String derivationPathString = "m/84'/1'/0'/1/0";

    // Create the derivation path object
    final derivationPath =
        await bdk.DerivationPath.create(path: derivationPathString);

    // print(derivationPath);

    final derivedSecretKey = await descriptorSecretKey.derive(derivationPath);

    return derivedSecretKey;
  }

  Future<List<bdk.Descriptor>> getDescriptors(String mnemonic) async {
    final descriptors = <bdk.Descriptor>[];
    try {
      for (var e in [bdk.KeychainKind.External, bdk.KeychainKind.Internal]) {
        final mnemonicObj = await bdk.Mnemonic.fromString(mnemonic);

        final descriptorSecretKey = await bdk.DescriptorSecretKey.create(
          network: bdk.Network.Testnet,
          mnemonic: mnemonicObj,
        );

        final descriptor = await bdk.Descriptor.newBip84(
          secretKey: descriptorSecretKey,
          network: bdk.Network.Testnet,
          keychain: e,
        );

        descriptors.add(descriptor);
      }
      return descriptors;
    } on Exception catch (e) {
      print("Error: ${e.toString()}");
      rethrow;
    }
  }

  Future<bdk.Wallet> createOrRestoreWallet(
      String mnemonic, bdk.Network network, String? password) async {
    try {
      final descriptors = await getDescriptors(mnemonic);

      final List<ConnectivityResult> connectivityResult =
          await (Connectivity().checkConnectivity());
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        await blockchainInit();
      }

      final res = await bdk.Wallet.create(
        descriptor: descriptors[0],
        changeDescriptor: descriptors[1],
        network: network,
        databaseConfig: const bdk.DatabaseConfig.memory(),
      );
      // var addressInfo =
      //     await res.getAddress(addressIndex: const AddressIndex());

      // print(res);

      return res;
    } on Exception catch (e) {
      print("Error: ${e.toString()}");
      throw Exception('Failed to create wallet');
    }
  }

  Future<bdk.Wallet> createSharedWallet(
    String descriptorStr,
    String internalDescriptor,
    String mnemonic,
    bdk.Network network,
    String? password,
  ) async {
    try {
      await blockchainInit();

      final descriptorWallet = await bdk.Descriptor.create(
        descriptor: descriptorStr,
        network: network, // Use Network.Mainnet for mainnet
      );

      // final internalDescriptorWallet = await bdk.Descriptor.newBip84(
      //   secretKey: await getInternalSecretKeyfromMnemonic(mnemonic),
      //   network: network,
      //   keychain: bdk.KeychainKind.Internal,
      // );

      // print('Ciaooooooooo ' + internalDescriptor);

      final internalDescriptorWallet = await bdk.Descriptor.create(
        descriptor: internalDescriptor,
        network: network,
      );

      // print('Ciaoooooooooooooo');

      final wallet = await bdk.Wallet.create(
        descriptor: descriptorWallet,
        changeDescriptor: internalDescriptorWallet,
        network: network,
        databaseConfig: const bdk.DatabaseConfig.memory(),
      );

      return wallet;
    } on Exception catch (e) {
      print("Error: ${e.toString()}");
      throw Exception('Failed to create wallet');
    }
  }

  Future<int> getBalance(bdk.Wallet wallet) async {
    // await syncWallet(wallet);
    bdk.Balance balance = await wallet.getBalance();

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

  Future<bdk.Wallet> loadSavedWallet(String? mnemonic) async {
    var walletBox = Hive.box('walletBox');
    String? savedMnemonic = walletBox.get('walletMnemonic');

    // print(savedMnemonic);

    if (savedMnemonic != null) {
      // Restore the wallet using the saved mnemonic
      wallet = await createOrRestoreWallet(
        savedMnemonic,
        bdk.Network.Testnet,
        null, // Use a saved password if required
      );
      // print(wallet);
      return wallet;
    } else {
      wallet = await createOrRestoreWallet(
        mnemonic!,
        bdk.Network.Testnet,
        null,
      );
    }
    return wallet;
  }

  Future<void> saveLocalData(bdk.Wallet wallet) async {
    String currentAddress = await getAddress(wallet);

    final walletData = WalletData(
      address: currentAddress,
      balance: await getBalance(wallet),
      ledgerBalance: await getLedgerBalance(currentAddress),
      availableBalance: await getAvailableBalance(currentAddress),
      transactions: await getTransactions(currentAddress),
    );

    // Save the data to Hive
    await _walletStorageService.saveWalletData(currentAddress, walletData);
  }

  Future<void> syncWallet(bdk.Wallet wallet) async {
    await blockchainInit(); // Ensure blockchain is initialized before usage

    await wallet.sync(blockchain);
  }

  Future<String> getAddress(bdk.Wallet wallet) async {
    // await syncWallet(wallet);

    var addressInfo = await wallet.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0));
    return addressInfo.address;
  }

  // Method to create, sign and broadcast a single user transaction
  Future<void> sendTx(String recipientAddressStr, int amount, bdk.Wallet wallet,
      String changeAddressStr) async {
    await syncWallet(wallet);

    final utxos = await wallet.getBalance();
    print("Available UTXOs: ${utxos.total}");

    try {
      // Build the transaction
      final txBuilder = bdk.TxBuilder();

      // Create recipient address
      final recipientAddress =
          await bdk.Address.create(address: recipientAddressStr);
      final recipientScript = await recipientAddress.scriptPubKey();

      // Create the change address
      final changeAddress = await bdk.Address.create(address: changeAddressStr);
      final changeScript = await changeAddress.scriptPubKey();

      // Build the transaction:
      // - Send `amount` to the recipient
      // - Any remaining funds (change) will be sent to the change address
      final txBuilderResult = await txBuilder
          .addRecipient(recipientScript, amount) // Send to recipient
          .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
          .feeRate(50.0) // Set the fee rate (in satoshis per byte)
          .drainTo(
              changeScript) // Specify the custom address to send the change
          .finish(wallet); // Finalize the transaction with wallet's UTXOs

      // Sign the transaction
      final sbt = await wallet.sign(psbt: txBuilderResult.psbt);

      // Extract the finalized transaction
      final tx = await sbt.extractTx();

      // Broadcast the transaction to the network
      await blockchain.broadcast(tx);
    } on Exception catch (e) {
      print("Error: ${e.toString()}");
    }
  }

  // Method to create a PSBT for a multisig transaction, this psbt is signed by the first user
  Future<String> createPartialTx(
    String recipientAddressStr,
    int amount,
    bdk.Wallet wallet,
  ) async {
    await syncWallet(wallet);

    final utxos = await wallet.getBalance();
    print("Available UTXOs: ${utxos.total}");

    final unspent = await wallet.listUnspent();

    for (var utxo in unspent) {
      print('UTXO: ${utxo.outpoint.txid}, Amount: ${utxo.txout.value}');
    }

    try {
      // Build the transaction
      final txBuilder = bdk.TxBuilder();

      // Create recipient address
      final recipientAddress =
          await bdk.Address.create(address: recipientAddressStr);
      final recipientScript = await recipientAddress.scriptPubKey();

      // final changeAddressStr = await getAddress(wallet);

      // print(changeAddressStr);

      final internalChangeAddress = await wallet.getInternalAddress(
          addressIndex: const bdk.AddressIndex.peek(index: 0));

      print('Nope: ${internalChangeAddress.index}');

      // Create the change address
      final changeAddress =
          await bdk.Address.create(address: internalChangeAddress.address);

      final changeScript = await changeAddress.scriptPubKey();

      print(internalChangeAddress.address);
      print('Ciao');
      // final keychainKind =
      //     await wallet.getDescriptorForKeyChain(bdk.KeychainKind.Internal);
      // final result = await keychainKind.asString();
      // print(result);

      // const outpoint = bdk.OutPoint(
      //   txid:
      //       "a4d8dc5c695c0109f8b7a3f7f9070870e7695e826e3d805a7123916c00df15be",
      //   vout: 0,
      // );

      // Build the transaction:
      // - Send `amount` to the recipient
      // - Any remaining funds (change) will be sent to the change address

      // int amountChange = utxos.total - amount;

      // TODO SharedWallet with timelocks
      final txBuilderResult = await txBuilder
          // .enableRbf()
          .addRecipient(recipientScript, amount) // Send to recipient
          // .addRecipient(changeScript, amountChange)
          // .addUtxo(outpoint)
          // .manuallySelectedOnly()
          .drainWallet() // Drain all wallet UTXOs, sending change to a custom address
          // .onlySpendChange()
          .doNotSpendChange()
          .feeRate(50.0) // Set the fee rate (in satoshis per byte)
          .drainTo(changeScript) // Specify the address to send the change
          .finish(wallet); // Finalize the transaction with wallet's UTXOs

      print('Finally');

      // Sign the transaction
      final sbt = await wallet.sign(
        psbt: txBuilderResult.psbt,
        signOptions: const bdk.SignOptions(
          isMultiSig: true,
          trustWitnessUtxo: false,
          allowAllSighashes: false,
          removePartialSigs: false,
          tryFinalize: false,
          signWithTapInternalKey: false,
          // assumeHeight: await fetchCurrentBlockHeight() + 6,
          allowGrinding: true,
        ),
      );

      print('Ciao');

      // final transaction = await txBuilderResult.psbt.serialize();

      // // final psbt = bdk.PartiallySignedTransaction(psbtBase64: transaction);
      // final sbt = await wallet.sign(psbt: txBuilderResult.psbt);

      // // Extract the finalized transaction
      // final tx = await sbt.extractTx();

      // // Broadcast the transaction to the network
      // await blockchain.broadcast(tx);

      return sbt.serialize();
    } on Exception catch (e) {
      // print("Error: ${e.toString()}");
      throw Exception("Error: ${e.toString()}");
    }
  }

  // This method takes a PSBT, signs it with the second user and then broadcasts it
  Future<void> signBroadcastTx(
      bdk.PartiallySignedTransaction sbt, bdk.Wallet wallet) async {
    // final sbt2 = await wallet.sign(psbt: sbt);

    final sbt2 = await wallet.sign(
      psbt: sbt,
      signOptions: const bdk.SignOptions(
        isMultiSig: true,
        trustWitnessUtxo: false,
        allowAllSighashes: false,
        removePartialSigs: false,
        tryFinalize: false,
        signWithTapInternalKey: false,
        allowGrinding: true,
      ),
    );

    final combinedpsbt = await sbt.combine(sbt2);

    // Extract the finalized transaction
    final tx = await combinedpsbt.extractTx();

    // Broadcast the transaction to the network
    await blockchain.broadcast(tx);
  }

  Future<void> blockchainInit() async {
    blockchain = await bdk.Blockchain.create(
      config: const bdk.BlockchainConfig.electrum(
        config: bdk.ElectrumConfig(
          url: "ssl://electrum.blockstream.info:60002",
          timeout: 5,
          retry: 5,
          stopGap: 10,
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

      int feeRate = jsonResponse['fastestFee'];

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
      print('Error: $e');
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
