import 'package:breez_liquid/breez_liquid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class SendBitcoinBottomSheet extends StatefulWidget {
  const SendBitcoinBottomSheet({super.key});

  @override
  State<StatefulWidget> createState() => SendBitcoinBottomSheetState();
}

class SendBitcoinBottomSheetState extends State<SendBitcoinBottomSheet> {
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _error;
  bool _loading = false;
  String? _result;

  bool _isBip21Uri(String input) {
    return input.startsWith("bitcoin:") ||
        input.startsWith("testnet:") ||
        input.startsWith("regtest:");
  }

  Future<void> _sendBitcoin() async {
    final destination = _destController.text.trim();
    final inputAmount = _amountController.text.trim();

    // print("🔍 Destination input: $destination");
    // print("🔍 Input amount: $inputAmount");

    if (destination.isEmpty) {
      setState(() => _error = "Destination cannot be empty");
      // print("❌ Error: Destination is empty");
      return;
    }

    final isBip21 = _isBip21Uri(destination);
    // print("🔍 Is BIP21 URI: $isBip21");

    BigInt? amount;
    if (!isBip21) {
      amount = BigInt.tryParse(inputAmount);
      if (amount == null || amount <= BigInt.zero) {
        setState(() => _error = "Amount required for raw BTC addresses");
        // print("❌ Error: Invalid or missing amount for raw address");
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
      // print("📦 Preparing send payment request...");
      final prepare = await breezSDKLiquid.instance!.preparePayOnchain(
        req: PreparePayOnchainRequest(
          amount: PayAmount_Bitcoin(receiverAmountSat: amount!),
        ),
      );

      // print("✅ Payment prepared. Proceeding to send...");

      final send = await breezSDKLiquid.instance!.payOnchain(
        req: PayOnchainRequest(
          address: destination,
          prepareResponse: prepare,
        ),
      );

      final payment = send.payment;
      // print("🎉 Payment sent!");
      // print("Amount: ${payment.amountSat}");
      // print("Destination: ${payment.destination}");

      setState(() {
        _result =
            "✅ Sent ${payment.amountSat} sats to ${payment.destination?.substring(0, 12)}...";
      });
    } catch (e) {
      setState(() => _error = "Send failed: $e");
      print("❌ Send failed: $e");
    } finally {
      setState(() => _loading = false);
      // print("🔁 Send operation completed");
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
              "Send Bitcoin",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destController,
              decoration: const InputDecoration(
                labelText: "Destination (BIP21 or BTC Address)",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount in sats (optional)",
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.error(context),
                ),
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
                    onPressed: _sendBitcoin,
                    child: const Text("Send BTC"),
                  ),
          ],
        ),
      ),
    );
  }
}
