import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/payment_type.dart' as pt;
import 'package:flutter_wallet/lightning/universal_payment_bottom_sheet.dart';

class ReceiveLiquidBottomSheet extends StatefulWidget {
  const ReceiveLiquidBottomSheet({super.key});

  @override
  State<StatefulWidget> createState() => ReceiveLiquidBottomSheetState();
}

class ReceiveLiquidBottomSheetState extends State<ReceiveLiquidBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  BigInt? _estimatedFees;
  String? _address;
  String? _error;
  bool _loading = false;

  Future<void> _receiveLiquid() async {
    final input = _amountController.text.trim();
    final amountSat = BigInt.tryParse(input);

    if (amountSat == null || amountSat <= BigInt.zero) {
      setState(() => _error = "Invalid amount");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _estimatedFees = null;
      _address = null;
    });

    try {
      final req = PrepareReceiveRequest(
        paymentMethod: PaymentMethod.liquidAddress,
        amount: ReceiveAmount_Bitcoin(payerAmountSat: amountSat),
      );

      final prepare =
          await breezSDKLiquid.instance!.prepareReceivePayment(req: req);

      final receive = await breezSDKLiquid.instance!.receivePayment(
        req: ReceivePaymentRequest(
          description: "Receive Liquid Payment",
          prepareResponse: prepare,
        ),
      );

      setState(() {
        _estimatedFees = prepare.feesSat;
        _address = receive.destination;
      });
    } catch (e) {
      setState(() => _error = "Swap failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UniversalPaymentBottomSheet(
      type: pt.PaymentType.receiveLiquid,
      amountController: _amountController,
      onSubmit: _receiveLiquid,
      result: null,
      error: _error,
      fees: _estimatedFees,
      addressOrUri: _address,
      loading: _loading,
    );
  }
}
