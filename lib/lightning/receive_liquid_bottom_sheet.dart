import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

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
            Text(
              "Receive Liquid",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount in sats"),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.error(context),
                ),
              ),
            if (_estimatedFees != null)
              Text("Estimated Fees: $_estimatedFees sats"),
            if (_address != null)
              SelectableText(
                "Receive Address:\n$_address",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _receiveLiquid,
                    child: const Text("Prepare Swap"),
                  ),
          ],
        ),
      ),
    );
  }
}
