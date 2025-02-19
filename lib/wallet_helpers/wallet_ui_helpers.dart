import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_wallet/services/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_transaction_helpers.dart';
import 'package:shimmer/shimmer.dart';

class WalletUiHelpers {
  static bool isPubKeyVisible = false;

  final String address;
  final int avBalance;
  final int ledBalance;
  final bool showInSatoshis;
  final double avCurrencyBalance;
  final double ledCurrencyBalance;
  final int currentHeight;
  String timeStamp;
  final bool isInitialized;
  final TextEditingController pubKeyController;
  final SettingsProvider settingsProvider;
  final DateTime lastRefreshed;
  final BuildContext context;
  final bool isLoading;
  final List<Map<String, dynamic>> transactions;
  final Wallet wallet;

  WalletService walletService = WalletService();

  WalletUiHelpers({
    required this.address,
    required this.avBalance,
    required this.ledBalance,
    required this.showInSatoshis,
    required this.avCurrencyBalance,
    required this.ledCurrencyBalance,
    required this.currentHeight,
    required this.timeStamp,
    required this.isInitialized,
    required this.pubKeyController,
    required this.settingsProvider,
    required this.lastRefreshed,
    required this.context,
    required this.isLoading,
    required this.transactions,
    required this.wallet,
  });

  // Box for displaying general wallet info with onTap functionality
  Widget buildWalletInfoBox(
    String title, {
    VoidCallback? onTap,
    bool showCopyButton = false,
    String? subtitle,
  }) {
    // Determine color and sign
    Color balanceColor = ledBalance > 0
        ? Colors.green
        : (ledBalance < 0 ? Colors.red : Colors.grey);

    bool isDataAvailable = address.isNotEmpty;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), // Rounded corners
          ),
          elevation: 4, // Subtle shadow for depth
          color: Colors.white, // Match button background
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: isDataAvailable
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _showPubKeyDialog();
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

                      // First Section: Address (with Copy Button)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showCopyButton) // Display copy button if true
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.green),
                              tooltip: 'Copy to clipboard',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: address));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("Address copied to clipboard"),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
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

                      // Second Section Balance
                      GestureDetector(
                        onTap: onTap,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Balance",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      settingsProvider.currency,
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
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: balanceColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                        text: settingsProvider
                                                            .currency),
                                                  ],
                                                ),
                                              )
                                        : Text(''),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(
                        height: 20,
                        thickness: 1,
                        color: Colors.grey,
                      ),

                      // BlockHeight and TimeStamp

                      Text(
                        'Current Block Height: $currentHeight \nTimestamp: $timeStamp',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),

                      // RefreshIndicator
                      if (DateTime.now().difference(lastRefreshed).inHours >=
                          2) ...[
                        const SizedBox(height: 8),
                        Text(
                          getTimeBasedMessage(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ).animate().shake(duration: 800.ms), // Shake effect
                      ]
                    ],
                  )
                : _buildShimmerEffect(),
          ),
        );
      },
    );
  }

  String getTimeBasedMessage() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "🌅 Good morning! It's time for a refresh!";
    } else if (hour >= 12 && hour < 18) {
      return "🌞 Afternoon check-in! Give it a refresh!";
    } else {
      return "🌙 Late night refresh? Why not!";
    }
  }

  // Box for displaying general wallet info with onTap functionality
  Widget buildInfoBoxMultisig(
    String title,
    String data, {
    VoidCallback? onTap,
    bool showCopyButton = false,
    String? subtitle,
  }) {
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
                  color: Colors.green, // Match button text color
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
                      icon: const Icon(Icons.copy, color: Colors.green),
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

  Widget buildTransactionsBox() {
    // print('timestamp: $timeStamp');

    final transactionHelpers = WalletTransactionHelpers(
      context: context,
      currentHeight: currentHeight,
      address: address,
    );

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
              '${transactions.length} Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green, // Match button text color
              ),
            ),
            const SizedBox(height: 8),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                    ? const Text('No transactions available')
                    : SizedBox(
                        height: 310, // Define the height of the scrollable area
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];

                            return KeyedSubtree(
                              key: ValueKey(tx['txid']),
                              child: GestureDetector(
                                onTap: () {
                                  transactionHelpers.showTransactionsDialog(
                                    transactions[index],
                                  );
                                },
                                child: transactionHelpers.buildTransactionItem(
                                  transactions[index],
                                ),
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

  void _showPubKeyDialog() {
    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Your Private Data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Here is your saved Public Key:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: Colors.green,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        pubKeyController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.green,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: pubKeyController.text));
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Public Key copied to clipboard!'),
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
                Navigator.of(context).pop();
              },
              label: 'Close',
              backgroundColor: Colors.green,
              textColor: Colors.white,
              icon: Icons.close,
            ),
          ],
        );
      },
    );
  }

  /// 🔹 Create a shimmer effect when data is loading
  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Future<void> handleRefresh(
    Future<void> Function() syncWallet,
    List<ConnectivityResult> connectivityResult,
    BuildContext context,
  ) async {
    // print('ConnectivityResult: $connectivityResult');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🚫 No internet! Connect and try again.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return; // Exit early if there's no internet
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "🔄 Syncing wallet… Please wait.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 1),
        ),
      );

      await walletService.syncWallet(wallet);
      final newHeight = await walletService.fetchCurrentBlockHeight();

      final walletTransactions = wallet.listTransactions(includeRaw: true);

      // Find new transactions
      List<String> newTransactions = walletService.findNewTransactions(
        transactions, // From API response
        walletTransactions, // From wallet.listTransactions()
      );

      // **Determine the message based on new block and transactions**
      bool newBlockDetected = currentHeight != newHeight;
      bool newTransactionDetected = newTransactions.isNotEmpty;

      String syncMessage = "⏳ No updates yet! Try again later. 🔄";

      if (newBlockDetected && newTransactionDetected) {
        syncMessage = "🚀 New block & transactions detected! Syncing now... 🔄";
      } else if (newBlockDetected) {
        syncMessage = "📦 New block detected! Syncing now... ⛓️";
      } else if (newTransactionDetected) {
        syncMessage = "₿ New transaction detected! Syncing now... 🔄";
      }

      if (newBlockDetected || newTransactionDetected) {
        // print('syncing');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncMessage,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            duration: Duration(seconds: 2),
          ),
        );
        await syncWallet();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Syncing Complete!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncMessage,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Sync error: $e');
      print('Stack trace: $stackTrace'); // Helps debug where the error occurs

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Oops! Something went wrong.\nError: ${e.toString()}",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
