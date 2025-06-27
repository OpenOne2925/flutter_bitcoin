import 'package:flutter/material.dart';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart' as liquid_sdk;
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/lightning/universal_payment_bottom_sheet.dart';
import 'package:flutter_wallet/lightning/payment_type.dart' as pt;
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';

class ReceiveLightningBottomSheet extends StatefulWidget {
  const ReceiveLightningBottomSheet({super.key});

  @override
  State<StatefulWidget> createState() => ReceiveLightningBottomSheetState();
}

class ReceiveLightningBottomSheetState
    extends State<ReceiveLightningBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _invoice;
  String? _error;
  bool _loading = false;
  BigInt? _minLimit;
  BigInt? _maxLimit;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _createInvoice() async {
    setState(() {
      _loading = true;
      _error = null;
      _invoice = null;
    });

    try {
      final limits = await breezSDKLiquid.instance!.fetchLightningLimits();
      _minLimit = limits.receive.minSat;
      _maxLimit = limits.receive.maxSat;

      final amountText = _amountController.text.trim();
      final amountSat = BigInt.tryParse(amountText);

      if (amountSat == null ||
          amountSat < limits.receive.minSat ||
          amountSat > limits.receive.maxSat) {
        setState(() {
          _error =
              "Invalid amount. Min: ${limits.receive.minSat} sats, Max: ${limits.receive.maxSat} sats";
          _loading = false;
        });
        return;
      }

      final receiveAmount = liquid_sdk.ReceiveAmount_Bitcoin(
        payerAmountSat: amountSat,
      );
      final prepareResponse =
          await breezSDKLiquid.instance!.prepareReceivePayment(
        req: liquid_sdk.PrepareReceiveRequest(
          paymentMethod: liquid_sdk.PaymentMethod.bolt11Invoice,
          amount: receiveAmount,
        ),
      );

      final res = await breezSDKLiquid.instance!.receivePayment(
        req: liquid_sdk.ReceivePaymentRequest(
          description: "Invoice via ReceiveLightningBottomSheet",
          prepareResponse: prepareResponse,
        ),
      );

      setState(() => _invoice = res.destination);
    } catch (e) {
      setState(() => _error = "Invoice creation failed: $e");
      SnackBarHelper.showError(
        context,
        message: AppLocalizations.of(context)!.translate('invoice_error'),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UniversalPaymentBottomSheet(
      type: pt.PaymentType.receiveLightning,
      amountController: _amountController,
      onSubmit: _createInvoice,
      result: _invoice,
      error: _error,
      fees: null,
      addressOrUri: _invoice,
      loading: _loading,
      minLimit: _minLimit,
      maxLimit: _maxLimit,
    );
  }
}
