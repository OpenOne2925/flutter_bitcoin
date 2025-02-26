import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

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

  final ScrollController _scrollController = ScrollController();
  bool _isUserInteracting = false;
  bool _isScrollingForward = true;
  Timer? _scrollTimer;

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
  }) {
    _startAutoScroll(); // Start scrolling when the class is initialized
  }

  /// Start auto-scrolling back and forth until the user interacts
  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (_isUserInteracting) return;

        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double minScroll = _scrollController.position.minScrollExtent;
          double currentScroll = _scrollController.offset;

          if (_isScrollingForward) {
            if (currentScroll >= maxScroll) {
              _isScrollingForward = false;
            } else {
              _scrollController.animateTo(
                currentScroll + 25,
                duration: const Duration(milliseconds: 150),
                curve: Curves.bounceInOut,
              );
            }
          } else {
            if (currentScroll <= minScroll) {
              _isScrollingForward = true;
            } else {
              _scrollController.animateTo(
                currentScroll - 25,
                duration: const Duration(milliseconds: 150),
                curve: Curves.linear,
              );
            }
          }
        }
      },
    );
  }

  /// Stops auto-scroling when user taps
  void _stopAutoScroll() {
    _isUserInteracting = true;
    _scrollTimer?.cancel();
  }

  /// Dispose function to clean up resources
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
  }

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
              : Listener(
                  onPointerUp: (event) => _stopAutoScroll(),
                  onPointerDown: (event) => _stopAutoScroll(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _scrollController,
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
                  ),
                )
          : CircularProgressIndicator(color: AppColors.primary(context)),
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
      timeRemaining = walletService.formatTime(totalSeconds as int, context);

      if (i == 0) {
        waitingTransactions.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_clock,
                color: AppColors.icon(context),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  "$totalValue ${AppLocalizations.of(context)!.translate('sats_available')} $timeRemaining",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.text(context),
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
                "$futureTotal ${AppLocalizations.of(context)!.translate('future_sats')}",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.text(context),
                ),
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
          AppLocalizations.of(context)!
              .translate('total_unconfirmed')
              .replaceAll('{x}', totalUnconfirmed.toString()),
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
        ? "${AppLocalizations.of(context)!.translate('immediately_spend').replaceAll('{x}', myAlias.toString())} \n$totalSpendable sats"
        : AppLocalizations.of(context)!
            .translate('cannot_spend')
            .replaceAll('{x}', myAlias.toString());

    if (otherAliases.isNotEmpty) {
      int threshold = path['threshold'];
      int totalKeys = pathAliases.length;

      if (threshold == 1) {
        aliasText +=
            "${AppLocalizations.of(context)!.translate('spend_alone')} \n${otherAliases.join(', ')}";
      } else if (threshold < totalKeys) {
        aliasText +=
            "${AppLocalizations.of(context)!.translate('threshold_required').replaceAll('{x}', threshold.toString()).replaceAll('{y}', totalKeys.toString())} \n${otherAliases.join(', ')}";
      } else {
        aliasText +=
            "${AppLocalizations.of(context)!.translate('spend_together')} \n${otherAliases.join(', ')}";
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
          color: AppColors.gradient(context),
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
                          ? 'Timelock: $timelock ${AppLocalizations.of(context)!.translate('blocks')}'
                          : 'MULTISIG',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cardTitle(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.vpn_key,
                      color: AppColors.icon(context),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        showPathsDialog();
                      },
                      child: Icon(
                        Icons.more_vert,
                        color: AppColors.icon(context),
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
                    color:
                        AppColors.text(context).withAlpha((0.1 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.icon(context),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          aliasText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
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
                      Text(
                        AppLocalizations.of(context)!
                            .translate('upcoming_funds'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
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
              color: AppColors.cardTitle(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${index + 1} of $length',
              style: TextStyle(
                color: AppColors.gradient(context),
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
    final rootContext = context;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title: Text(
            AppLocalizations.of(rootContext)!
                .translate('spending_paths_available'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.cardTitle(context),
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
                    return RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: AppColors.text(context),
                        ),
                        children: [
                          TextSpan(
                            text:
                                "${AppLocalizations.of(rootContext)!.translate('value')}: ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text:
                                "$value sats - ${AppLocalizations.of(rootContext)!.translate('unconfirmed')}",
                            style: TextStyle(
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
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
                    timeRemaining =
                        walletService.formatTime(totalSeconds, rootContext);
                    // print('Formatted time remaining: $timeRemaining');
                  }

                  return RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text(context),
                      ),
                      children: [
                        if (isSpendable) ...[
                          TextSpan(
                            text: "$value sats ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: AppLocalizations.of(rootContext)!
                                .translate('can_be_spent'),
                          ),
                        ] else ...[
                          TextSpan(
                            text:
                                "${AppLocalizations.of(rootContext)!.translate('value')}: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardTitle(context)),
                          ),
                          TextSpan(
                            text: "$value sats\n",
                          ),
                          TextSpan(
                            text:
                                "${AppLocalizations.of(rootContext)!.translate('time_remaining_text')}: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardTitle(context)),
                          ),
                          TextSpan(
                            text: "$timeRemaining\n",
                          ),
                          TextSpan(
                            text:
                                "${AppLocalizations.of(rootContext)!.translate('blocks_remaining')}: ",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.cardTitle(context)),
                          ),
                          TextSpan(
                            text: "$remainingBlocks",
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList();

                // Display spending path details
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.container(context),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: AppColors.background(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${AppLocalizations.of(rootContext)!.translate('type')}: ${pathInfo['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK $timelock blocks' : 'MULTISIG'}",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.cardTitle(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      pathInfo['threshold'] != null
                          ? RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: AppColors.text(context),
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        "${AppLocalizations.of(rootContext)!.translate('threshold')}: ",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.cardTitle(context),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${pathInfo['threshold']}',
                                    style: TextStyle(
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                ],
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
                                  color: AppColors.text(context),
                                  fontWeight: pathAliases[i] == myAlias
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        "${AppLocalizations.of(rootContext)!.translate('transaction_info')}: ",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cardTitle(context),
                        ),
                      ),
                      transactionDetails.isNotEmpty
                          ? Column(children: transactionDetails)
                          : Text(
                              AppLocalizations.of(rootContext)!
                                  .translate('no_transactions_available'),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.error(context),
                              ),
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
                Navigator.of(context).pop();
              },
              label: AppLocalizations.of(rootContext)!.translate('close'),
              backgroundColor: AppColors.background(context),
              textColor: AppColors.text(context),
              icon: Icons.cancel_rounded,
              iconColor: AppColors.gradient(context),
            ),
          ],
        );
      },
    );
  }
}
