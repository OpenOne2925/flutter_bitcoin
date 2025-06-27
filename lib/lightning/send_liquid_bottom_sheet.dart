import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/universal_payment_bottom_sheet.dart';
import 'package:flutter_wallet/lightning/payment_type.dart' as pt;

class SendLiquidBottomSheet extends StatefulWidget {
  const SendLiquidBottomSheet({super.key});

  @override
  State<StatefulWidget> createState() => SendLiquidBottomSheetState();
}

class SendLiquidBottomSheetState extends State<SendLiquidBottomSheet> {
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _error;
  bool _loading = false;
  String? _result;

  Future<void> _sendLiquid() async {
    final destination = _destController.text.trim();
    final inputAmount = _amountController.text.trim();
    final isRawAddress =
        destination.startsWith("ex") || destination.startsWith("CT");

    if (destination.isEmpty) {
      setState(() => _error = "Destination cannot be empty");
      return;
    }

    BigInt? amount;
    if (isRawAddress) {
      amount = BigInt.tryParse(inputAmount);
      if (amount == null || amount <= BigInt.zero) {
        setState(() => _error = "Amount required for raw Liquid addresses");
        return;
      }
    } else {
      amount = inputAmount.isNotEmpty ? BigInt.tryParse(inputAmount) : null;
    }

    setState(() {
      _error = null;
      _loading = true;
      _result = null;
    });

    try {
      final prepare = await breezSDKLiquid.instance!.prepareSendPayment(
        req: PrepareSendRequest(
          destination: destination,
          amount: amount != null
              ? PayAmount_Bitcoin(receiverAmountSat: amount)
              : null,
        ),
      );

      final send = await breezSDKLiquid.instance!.sendPayment(
        req: SendPaymentRequest(prepareResponse: prepare),
      );

      final payment = send.payment;
      setState(() {
        _result =
            "✅ Sent ${payment.amountSat} sats to ${payment.destination?.substring(0, 12)}...";
      });
    } catch (e) {
      setState(() => _error = "Send failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UniversalPaymentBottomSheet(
      type: pt.PaymentType.sendLiquid,
      amountController: _amountController,
      destController: _destController,
      onSubmit: _sendLiquid,
      result: _result,
      error: _error,
      fees: null, // Not displayed for send liquid
      addressOrUri: null, // Not applicable here
      loading: _loading,
    );
  }
}
