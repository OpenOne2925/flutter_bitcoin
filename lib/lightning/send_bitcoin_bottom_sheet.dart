import 'package:breez_liquid/breez_liquid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/universal_payment_bottom_sheet.dart';
import 'package:flutter_wallet/lightning/payment_type.dart' as pt;

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
      // print("❌ Send failed: $e");
    } finally {
      setState(() => _loading = false);
      // print("🔁 Send operation completed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return UniversalPaymentBottomSheet(
      type: pt.PaymentType.sendBitcoin,
      amountController: _amountController,
      destController: _destController,
      onSubmit: _sendBitcoin,
      result: _result,
      error: _error,
      fees: null, // Not used here
      addressOrUri: null, // Not used here
      loading: _loading,
    );
  }
}
