import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

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
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Send Liquid Payment",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destController,
              decoration: const InputDecoration(
                labelText: "Destination (BIP21 or Liquid Address)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Amount in sats (optional)"),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: AppColors.error(context)),
              ),
            if (_result != null)
              Text(
                _result!,
                style: TextStyle(
                  color: AppColors.primary(context),
                ),
              ),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendLiquid,
                    child: const Text("Send Payment"),
                  ),
          ],
        ),
      ),
    );
  }
}
