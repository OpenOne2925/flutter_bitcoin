import 'package:breez_liquid/breez_liquid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/lightning/sdk_instance.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

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
              "Receive Bitcoin",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
            if (_minLimit != null && _maxLimit != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Min: $_minLimit, Max: $_maxLimit sats",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.unavailableColor,
                  ),
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
            if (_fees != null)
              Text(
                "Estimated Fees: $_fees sats",
                style: TextStyle(
                  color: AppColors.primary(context),
                ),
              ),
            if (_uri != null)
              SelectableText(
                "Payment URI_ \n$_uri",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _prepareReceiveBTC,
                    child: const Text("Generate Address"),
                  ),
          ],
        ),
      ),
    );
  }
}
