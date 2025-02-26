import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/qr_scanner_page.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_receive_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_security_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_sendtx_helpers.dart';
import 'package:flutter_wallet/wallet_helpers/wallet_spending_path_helpers.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class WalletButtonsHelper {
  final BuildContext context;
  final String address;
  final bool isSingleWallet;
  final WalletSecurityHelpers securityHelper;
  final WalletSendtxHelpers sendTxHelper;
  final WalletReceiveHelpers receiveHelper;
  final WalletSpendingPathHelpers? spendingPathHelpers;

  WalletButtonsHelper({
    required this.context,
    required this.address,
    required this.isSingleWallet,

    // Common Variables
    required TextEditingController recipientController,
    required TextEditingController amountController,
    required WalletService walletService,
    required bool mounted,
    required String mnemonic,
    required Wallet wallet,
    required int currentHeight,

    // SharedWallet Variables
    TextEditingController? psbtController,
    TextEditingController? signingAmountController,
    int? avgBlockTime,
    String? descriptor,
    String? descriptorName,
    List<Map<String, String>>? pubKeysAlias,
    Map<String, dynamic>? policy,
    String? myFingerPrint,
    List<dynamic>? utxos,
    List<Map<String, dynamic>>? mySpendingPaths,
    List<Map<String, dynamic>>? spendingPaths,
    List<String>? signersList,
    Function(String)? onTransactionCreated,
    String? myAlias,
  })  : securityHelper = WalletSecurityHelpers(
          context: context,
          descriptor: descriptor,
          descriptorName: descriptorName,
          pubKeysAlias: pubKeysAlias,
        ),
        sendTxHelper = WalletSendtxHelpers(
          isSingleWallet: isSingleWallet,
          context: context,
          recipientController: recipientController,
          psbtController: psbtController,
          signingAmountController: signingAmountController,
          amountController: amountController,
          walletService: walletService,
          policy: policy ?? {},
          myFingerPrint: myFingerPrint ?? '',
          currentHeight: currentHeight,
          utxos: utxos ?? [],
          spendingPaths: mySpendingPaths ?? [],
          descriptor: descriptor ?? '',
          mnemonic: mnemonic,
          mounted: mounted,
          signersList: signersList ?? [],
          address: address,
          pubKeysAlias: pubKeysAlias ?? [],
          wallet: wallet,
        ),
        receiveHelper = WalletReceiveHelpers(context: context),
        spendingPathHelpers = isSingleWallet
            ? null // Don't create spendingPathHelpers if it's a single wallet
            : WalletSpendingPathHelpers(
                pubKeysAlias: pubKeysAlias ?? [],
                mySpendingPaths: mySpendingPaths ?? [],
                spendingPaths: spendingPaths ?? [],
                utxos: utxos ?? [],
                currentHeight: currentHeight,
                avgBlockTime: avgBlockTime ?? 0,
                walletService: walletService,
                myAlias: myAlias ?? '',
                context: context,
                policy: policy ?? {},
              );

  Widget buildButtons() {
    return SafeArea(
      child: Column(
        children: [
          _buildTopButtons(),
          const SizedBox(height: 16),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildTopButtons() {
    return Wrap(
      alignment:
          isSingleWallet ? WrapAlignment.center : WrapAlignment.spaceBetween,
      spacing: 8, // Adjusts horizontal space between buttons
      runSpacing: 8, // Adjusts vertical space if buttons wrap to the next line
      children: [
        CustomButton(
          onPressed: () {
            securityHelper.showPinDialog('Your Private Data',
                isSingleWallet: isSingleWallet);
          },
          backgroundColor: AppColors.background(context),
          foregroundColor: AppColors.gradient(context),
          icon: Icons.remove_red_eye, // Icon for the new button
          iconColor: AppColors.gradient(context),
          label: AppLocalizations.of(context)!.translate('private_data'),
        ),
        // if (!isSingleWallet)
        //   CustomButton(
        //     onPressed: spendingPathHelpers!.showPathsDialog,
        //     backgroundColor: AppColors.background(context),
        //     foregroundColor: AppColors.gradient(context),
        //     icon: Icons.pattern,
        //     iconColor: AppColors.gradient(context),
        //     label: AppLocalizations.of(context)!.translate('spending_summary'),
        //   ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Send Button
        CustomButton(
          onPressed: () => sendTxHelper.sendTx(true),
          backgroundColor: AppColors.background(context),
          foregroundColor: AppColors.primary(context),
          icon: Icons.arrow_upward,
          iconColor: AppColors.gradient(context),
        ),
        const SizedBox(width: 8),
        CustomButton(
          onPressed: () => sendTxHelper.sendTx(false),
          backgroundColor: AppColors.background(context),
          foregroundColor: AppColors.primary(context),
          icon: Icons.draw,
          iconColor: AppColors.text(context),
        ),
        const SizedBox(width: 8),
        // Scan To Send Button
        CustomButton(
          onPressed: () async {
            // Handle scanning address functionality
            final recipientAddressStr = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerPage()),
            );

            // If a valid Bitcoin address was scanned, show the transaction dialog
            if (recipientAddressStr != null) {
              sendTxHelper.sendTx(
                true,
                recipientAddressQr: recipientAddressStr,
              );
            }
          },
          backgroundColor: AppColors.background(context),
          foregroundColor: AppColors.primary(context),
          icon: Icons.qr_code,
          iconColor: AppColors.gradient(context),
        ),
        const SizedBox(width: 8),
        // Receive Button
        CustomButton(
          onPressed: () => receiveHelper.showQRCodeDialog(address),
          backgroundColor: AppColors.background(context),
          foregroundColor: AppColors.primary(context),
          icon: Icons.arrow_downward,
          iconColor: AppColors.text(context),
        ),
      ],
    );
  }
}
