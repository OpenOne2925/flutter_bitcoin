import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart' as liquid_sdk;
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/universal_payment_bottom_sheet.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/wallet_pages/qr_scanner_page.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:flutter_wallet/lightning/payment_type.dart' as pt;

class SendLightningBottomSheet extends StatefulWidget {
  const SendLightningBottomSheet({super.key});

  @override
  State<StatefulWidget> createState() => _SendLightningBottomSheetState();
}

class _SendLightningBottomSheetState extends State<SendLightningBottomSheet> {
  final TextEditingController _destController = TextEditingController();
  String? _error;
  bool _loading = false;
  BigInt? _estimatedFees;

  Future<void> _payInvoice() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bolt11 = _destController.text.trim();
      if (bolt11.isEmpty) {
        setState(() => _error = "Invoice is empty.");
        return;
      }

      final prepare = await breezSDKLiquid.instance!.prepareSendPayment(
        req: liquid_sdk.PrepareSendRequest(destination: bolt11),
      );

      setState(() => _estimatedFees = prepare.feesSat);

      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.dialog(context),
          title: const Text("Confirm Payment"),
          content: Text("Pay invoice?\nEstimated fee: $_estimatedFees sats"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
            ),
            ElevatedButton(
              child: const Text("Send"),
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await breezSDKLiquid.instance!.sendPayment(
        req: liquid_sdk.SendPaymentRequest(prepareResponse: prepare),
      );

      SnackBarHelper.show(context, message: 'payment_sent');
      setState(() => _destController.clear());
    } catch (e) {
      setState(() => _error = "Payment failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _scanQrCode() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerPage(
          title: 'Scan Lightning Invoice',
          isValid: isValidBolt11,
          extractValue: (val) => val,
        ),
      ),
    );

    if (scanned != null && scanned.isNotEmpty) {
      setState(() {
        _destController.text = scanned;
        _error = null; // clear error if previously set
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return UniversalPaymentBottomSheet(
      type: pt.PaymentType.sendLightning,
      amountController: TextEditingController(), // Optional amount
      destController: _destController,
      onSubmit: _payInvoice,
      result: null,
      error: _error,
      fees: _estimatedFees,
      addressOrUri: null,
      loading: _loading,
      onScanQr: _scanQrCode,
    );
  }
}
