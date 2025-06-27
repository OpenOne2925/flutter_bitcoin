import 'dart:async';

import 'package:breez_liquid/breez_liquid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/payment_type.dart' as pt;
import 'package:flutter_wallet/lightning/universal_payment_bottom_sheet.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';

class ReceiveBitcoinBottomSheet extends StatefulWidget {
  const ReceiveBitcoinBottomSheet({super.key});

  @override
  State<StatefulWidget> createState() => ReceiveBitcoinBottomSheetState();
}

class ReceiveBitcoinBottomSheetState extends State<ReceiveBitcoinBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _uri;
  String? _error;
  bool _loading = false;
  BigInt? _fees;
  BigInt? _minLimit;
  BigInt? _maxLimit;

  @override
  void initState() {
    super.initState();

    _loadLimits();
  }

  Future<void> _loadLimits() async {
    try {
      final limits = await breezSDKLiquid.instance!.fetchOnchainLimits();

      setState(() {
        _minLimit = limits.receive.minSat;
        _maxLimit = limits.receive.maxSat;
      });
    } catch (e) {
      // Not critical - just skip if it fails
    }
  }

  Future<void> _prepareReceiveBTC() async {
    final input = _amountController.text.trim();
    final amount = input.isNotEmpty ? BigInt.tryParse(input) : null;

    if (amount != null && (_minLimit != null && amount < _minLimit!)) {
      setState(() => _error = "Amount is below minimum: $_minLimit sats");
      return;
    }

    if (amount != null && (_maxLimit != null && amount < _maxLimit!)) {
      setState(() => _error = "Amount exceeds minimum: $_maxLimit sats");
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
      _fees = null;
      _uri = null;
    });

    try {
      final prepare = await breezSDKLiquid.instance!.prepareReceivePayment(
        req: PrepareReceiveRequest(
          paymentMethod: PaymentMethod.bitcoinAddress,
          amount: amount != null
              ? ReceiveAmount_Bitcoin(payerAmountSat: amount)
              : null,
        ),
      );

      final receive = await breezSDKLiquid.instance!.receivePayment(
        req: ReceivePaymentRequest(
          description: "Receive BTC via Breez",
          prepareResponse: prepare,
        ),
      );

      setState(() {
        _fees = prepare.feesSat;
        _uri = receive.destination;
      });

      final waiting = await breezSDKLiquid.instance!.listPayments(
        req: ListPaymentsRequest(
          states: [PaymentState.waitingFeeAcceptance],
        ),
      );

      for (final payment in waiting) {
        if (payment.details is! PaymentDetails_Bitcoin) {
          continue;
        }

        final bitcoinDetails = payment.details as PaymentDetails_Bitcoin;

        final fetchFeesResponse =
            await breezSDKLiquid.instance!.fetchPaymentProposedFees(
          req: FetchPaymentProposedFeesRequest(
            swapId: bitcoinDetails.swapId,
          ),
        );

        await breezSDKLiquid.instance!.acceptPaymentProposedFees(
          req: AcceptPaymentProposedFeesRequest(
            response: fetchFeesResponse,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = "Failed to prepare BTC receive");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleRefundables() async {
    try {
      // List maps eligible for refund
      List<RefundableSwap> refundables =
          await breezSDKLiquid.instance!.listRefundables();

      if (refundables.isEmpty) {
        // print("No refundable swaps found.");
        SnackBarHelper.show(context, message: "No refunds pending.");
        return;
      }

      String? destinationAddress = await _promptForRefundAddress();
      if (destinationAddress == null || destinationAddress.isEmpty) {
        // print("Refund canceld by user");
        return;
      }

      // Get recommended fees from Breez
      RecommendedFees fees = await breezSDKLiquid.instance!.recommendedFees();
      int feeRateSatPerVbyte = int.parse(fees.halfHourFee.toString());

      for (var refundable in refundables) {
        try {
          RefundRequest req = RefundRequest(
            swapAddress: refundable.swapAddress,
            refundAddress: destinationAddress,
            feeRateSatPerVbyte: feeRateSatPerVbyte,
          );

          RefundResponse resp = await breezSDKLiquid.instance!.refund(req: req);
          // print("Refund Transaction sent: ${resp.refundTxId}");

          SnackBarHelper.show(context,
              message: "Refund Sent, TXID: ${resp.refundTxId}");
        } catch (e) {
          // print("Refund failed for swap ${refundable.swapAddress}: $e");
          SnackBarHelper.showError(context, message: "Refund failed: $e");
        }
      }

      setState(() => _error = null);
    } catch (e) {
      // print("Refund failed: $e");
      setState(() => _error = "Refund failed: $e");
    }
  }

  Future<String?> _promptForRefundAddress() async {
    String? input = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();

        return AlertDialog(
          backgroundColor: AppColors.dialog(context),
          title: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter BTC Address"),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context, null),
            ),
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.of(context, rootNavigator: true)
                  .pop(controller.text.trim()),
            ),
          ],
        );
      },
    );

    return input;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UniversalPaymentBottomSheet(
          type: pt.PaymentType.receiveBitcoin,
          amountController: _amountController,
          onSubmit: _prepareReceiveBTC,
          result: null,
          error: _error,
          fees: _fees,
          addressOrUri: _uri,
          loading: _loading,
          minLimit: _minLimit,
          maxLimit: _maxLimit,
          onCheckRefunds: _handleRefundables,
        ),
      ],
    );
  }
}
