import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';

class WalletSpendingPathHelpers {
  final List<Map<String, String>> pubKeysAlias;
  final List<Map<String, dynamic>> mySpendingPaths;
  final List<Map<String, dynamic>> spendingPaths;
  final List<dynamic> utxos;
  final int currentHeight;
  final int avgBlockTime;
  final WalletService walletService;
  final String myAlias;
  final BuildContext context;
  final Map<String, dynamic> policy;

  WalletSpendingPathHelpers({
    required this.pubKeysAlias,
    required this.mySpendingPaths,
    required this.spendingPaths,
    required this.utxos,
    required this.currentHeight,
    required this.avgBlockTime,
    required this.walletService,
    required this.myAlias,
    required this.context,
    required this.policy,
  });

  // 🔹 Call this from your main widget
  Widget buildDynamicSpendingPaths(bool isInitialized) {
    return Align(
      alignment: Alignment.center,
      child: isInitialized
          ? mySpendingPaths.isEmpty
              ? const Text(
                  "No spending paths available",
                  style: TextStyle(color: Colors.grey),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: mySpendingPaths.asMap().entries.map((entry) {
                        int index = entry.key;
                        var path = entry.value;

                        return buildSpendingPathBox(
                          path,
                          index,
                          mySpendingPaths.length,
                        );
                      }).toList(),
                    ),
                  ),
                )
          : const CircularProgressIndicator(color: Colors.green),
    );
  }

  Widget buildSpendingPathBox(
    Map<String, dynamic> path,
    int index,
    int length,
  ) {
    // print('Spending paths: $path');

    // Extract aliases for the current pathInfo's fingerprints
    final List<String> pathAliases =
        (path['fingerprints'] as List<dynamic>).map<String>((fingerprint) {
      final matchedAlias = pubKeysAlias.firstWhere(
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
          blockHeight + timelock - 1 <= currentHeight || timelock == 0;

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

    List<MapEntry<int, int>> sortedEntries = blockHeightTotals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    int futureTotal = 0;

    List<Widget> waitingTransactions = [];

    for (var i = 0; i < sortedEntries.length; i++) {
      int utxoBlockHeight = sortedEntries[i].key;
      int totalValue = sortedEntries[i].value;

      final remainingBlocks = utxoBlockHeight + timelock - 1 - currentHeight;
      final totalSeconds = remainingBlocks * avgBlockTime;
      timeRemaining = walletService.formatTime(totalSeconds as int);

      if (i == 0) {
        waitingTransactions.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_clock,
                color: Colors.greenAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  "$totalValue sats available in $timeRemaining",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        futureTotal += totalValue;
      }
    }

    if (futureTotal > 0) {
      waitingTransactions.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty,
                color: Colors.amberAccent, size: 16),
            const SizedBox(width: 6),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                "$futureTotal sats will be available in the future",
                style: const TextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
          ],
        ),
      );
    }

    transactionDetails.insertAll(0, waitingTransactions);

    // ✅ Add the total unconfirmed amount to the transaction details list
    if (totalUnconfirmed > 0) {
      transactionDetails.add(
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
        ? "You ($myAlias) can immediately spend: \n$totalSpendable sats"
        : "You ($myAlias) cannot spend any sats at the moment.";

    if (otherAliases.isNotEmpty) {
      int threshold = path['threshold'];
      int totalKeys = pathAliases.length;

      if (threshold == 1) {
        aliasText +=
            "\nYou can spend alone. \nThese other keys can also spend independently: \n${otherAliases.join(', ')}";
      } else if (threshold < totalKeys) {
        aliasText +=
            "\n\nA threshold of $threshold out of $totalKeys is required. \nYou must coordinate with these keys: \n${otherAliases.join(', ')}";
      } else {
        aliasText +=
            "\nYou must spend together with: \n${otherAliases.join(', ')}";
      }
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
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.vpn_key,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        showPathsDialog();
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
                    color: Colors.green.withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
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
                            color: Colors.green,
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
                        "Upcoming Funds - Tap ⋮ for details",
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
              color: Colors.green,
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

  void showPathsDialog() async {
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
              color: Colors.green,
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
                  final matchedAlias = pubKeysAlias.firstWhere(
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
                      blockHeight + timelock - 1 <= currentHeight ||
                          timelock == 0;
                  // print('Is transaction spendable? $isSpendable');

                  final remainingBlocks =
                      blockHeight + timelock - 1 - currentHeight;
                  // print(
                  //     'Remaining blocks until timelock expires: $remainingBlocks');

                  // Calculate time remaining if not spendable
                  if (!isSpendable) {
                    // print('Calculating time remaining...');
                    print('Average block time: $avgBlockTime seconds');
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
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Type: ${pathInfo['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK $timelock blocks' : 'MULTISIG'}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.green,
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
                      transactionDetails.isNotEmpty
                          ? Column(children: transactionDetails)
                          : const Text(
                              "No transactions available",
                              style: TextStyle(fontSize: 14, color: Colors.red),
                            ),
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
}
