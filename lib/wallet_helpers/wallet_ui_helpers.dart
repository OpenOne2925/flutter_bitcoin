import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/utilities/snackbar_helper.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_security_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_transaction_helpers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

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
  final DateTime? lastRefreshed;
  final BuildContext context;
  final bool isLoading;
  final List<Map<String, dynamic>> transactions;
  final Wallet wallet;

  final bool isSingleWallet;
  final WalletSecurityHelpers securityHelper;

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
    required this.isSingleWallet,
    String? descriptor,
    String? descriptorName,
    List<Map<String, String>>? pubKeysAlias,
  }) : securityHelper = WalletSecurityHelpers(
          context: context,
          descriptor: descriptor,
          descriptorName: descriptorName,
          pubKeysAlias: pubKeysAlias,
        );

  // Box for displaying general wallet info with onTap functionality
  Widget buildWalletInfoBox(
    String title, {
    VoidCallback? onTap,
    bool showCopyButton = false,
    String? subtitle,
  }) {
    // Determine color and sign
    Color balanceColor = ledBalance > 0
        ? AppColors.primary(context)
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
          color: AppColors.gradient(context), // Match button background
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          Row(
                            // Wrap the two icons inside another Row
                            children: [
                              GestureDetector(
                                onTap: () {
                                  securityHelper.showPinDialog(
                                    'Your Private Data',
                                    isSingleWallet: isSingleWallet,
                                  );
                                },
                                child: Icon(
                                  Icons.remove_red_eye,
                                  color: AppColors.cardTitle(context),
                                  size: 22,
                                ),
                              ),
                              SizedBox(
                                  width: 10), // Add spacing between the icons
                              GestureDetector(
                                onTap: () {
                                  _showPubKeyDialog();
                                },
                                child: Icon(
                                  Icons.more_vert,
                                  color: AppColors.cardTitle(context),
                                  size: 22,
                                ),
                              ),
                            ],
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
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.text(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (showCopyButton) // Display copy button if true
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppColors.cardTitle(context),
                              ),
                              tooltip: 'Copy to clipboard',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: address));
                                SnackBarHelper.show(
                                  context,
                                  message: AppLocalizations.of(context)!
                                      .translate('address_clipboard'),
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
                              AppLocalizations.of(context)!
                                  .translate('balance'),
                              style: TextStyle(
                                color: AppColors.cardTitle(context),
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
                                              color: AppColors.text(context),
                                              fontSize: 16,
                                            ),
                                          )
                                        : Text.rich(
                                            TextSpan(
                                              text:
                                                  '${avCurrencyBalance.toStringAsFixed(2)} ',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: AppColors.text(context),
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
                        '${AppLocalizations.of(context)!.translate('current_height')}: $currentHeight \n${AppLocalizations.of(context)!.translate('timestamp')}: $timeStamp',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.text(context),
                        ),
                      ),

                      // RefreshIndicator
                      if (DateTime.now().difference(lastRefreshed!).inHours >=
                          2) ...[
                        const SizedBox(height: 8),
                        Text(
                          getTimeBasedMessage(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error(context),
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
      return AppLocalizations.of(context)!.translate('morning_check');
    } else if (hour >= 12 && hour < 18) {
      return AppLocalizations.of(context)!.translate('afternoon_check');
    } else {
      return AppLocalizations.of(context)!.translate('night_check');
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
        color: AppColors.gradient(context), // Match button background
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      AppColors.cardTitle(context), // Match button text color
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.text(
                            context), // Black text to match theme
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showCopyButton) // Display copy button if true
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: AppColors.cardTitle(context),
                      ),
                      tooltip: 'Copy to clipboard',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: data));
                        SnackBarHelper.show(
                          context,
                          message: AppLocalizations.of(context)!
                              .translate('psbt_clipboard'),
                        );
                      },
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error(context),
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
      color: AppColors.gradient(context), // Match button background
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transactions.length} ${AppLocalizations.of(context)!.translate('transactions')}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.cardTitle(context), // Match button text color
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
          backgroundColor: AppColors.dialog(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Text(
            AppLocalizations.of(rootContext)!.translate('pub_key'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.cardTitle(context),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(rootContext)!.translate('saved_pub_key'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.container(context),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppColors.background(context),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        pubKeyController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.text(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        color: AppColors.icon(context),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: pubKeyController.text));
                        SnackBarHelper.show(
                          rootContext,
                          message: AppLocalizations.of(rootContext)!
                              .translate('pub_key_clipboard'),
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
              label: AppLocalizations.of(rootContext)!.translate('close'),
              backgroundColor: AppColors.primary(context),
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
      SnackBarHelper.show(
        context,
        message: AppLocalizations.of(context)!.translate('no_internet'),
        color: AppColors.error(context),
      );

      return; // Exit early if there's no internet
    }

    try {
      SnackBarHelper.show(
        context,
        message: AppLocalizations.of(context)!.translate('syncing_wallet'),
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

      String syncMessage =
          AppLocalizations.of(context)!.translate('no_updates_yet');

      if (newBlockDetected && newTransactionDetected) {
        syncMessage = AppLocalizations.of(context)!
            .translate('new_block_transactions_detected');
      } else if (newBlockDetected) {
        syncMessage =
            AppLocalizations.of(context)!.translate('new_block_detected');
      } else if (newTransactionDetected) {
        syncMessage =
            AppLocalizations.of(context)!.translate('new_transaction_detected');
      }

      if (newBlockDetected || newTransactionDetected) {
        // print('syncing');
        SnackBarHelper.show(context, message: syncMessage);

        await syncWallet();
        SnackBarHelper.show(
          context,
          message: AppLocalizations.of(context)!.translate('syncing_complete'),
        );
      } else {
        SnackBarHelper.show(context, message: syncMessage);
      }
    } catch (e, stackTrace) {
      print('Sync error: $e');
      print('Stack trace: $stackTrace'); // Helps debug where the error occurs

      SnackBarHelper.show(context,
          message:
              "${AppLocalizations.of(context)!.translate('syncing_error')} ${e.toString()}",
          color: AppColors.error(context));
    }
  }
}
