import 'package:flutter/material.dart';
import 'package:flutter_wallet/lightning/payment_type.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UniversalPaymentBottomSheet extends StatelessWidget {
  final PaymentType type;
  final TextEditingController amountController;
  final TextEditingController? destController;
  final VoidCallback onSubmit;
  final String? result;
  final String? error;
  final BigInt? fees;
  final String? addressOrUri;
  final bool loading;
  final BigInt? minLimit;
  final BigInt? maxLimit;
  final VoidCallback? onScanQr;
  final VoidCallback? onCheckRefunds;

  const UniversalPaymentBottomSheet({
    super.key,
    required this.type,
    required this.amountController,
    this.destController,
    required this.onSubmit,
    required this.result,
    required this.error,
    required this.fees,
    required this.addressOrUri,
    required this.loading,
    this.minLimit,
    this.maxLimit,
    this.onScanQr,
    this.onCheckRefunds,
  });

  @override
  Widget build(BuildContext context) {
    final isReceive = type.isReceive;
    final network = type.displayNetwork;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dialog(context),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "${type.displayAction} $network",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary(context),
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 16),

            // Destination input
            if (!isReceive && destController != null)
              _customTextField(
                context: context,
                controller: destController!,
                label: "Destination ($network)",
                suffixIcon: onScanQr != null
                    ? IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Scan QR Code',
                        onPressed: onScanQr,
                      )
                    : null,
              ),

            // Amount input
            _customTextField(
              context: context,
              controller: amountController,
              label: "Amount in sats (optional)",
              keyboardType: TextInputType.number,
            ),

            // Limits display
            if (isReceive && minLimit != null && maxLimit != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Min: $minLimit, Max: $maxLimit sats",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.unavailableColor,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            if (error != null)
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.error(context),
                  fontSize: 14,
                ),
              ),

            // if (result != null)
            //   Text(
            //     result!,
            //     textAlign: TextAlign.center,
            //     style: TextStyle(
            //       color: AppColors.primary(context),
            //       fontSize: 14,
            //     ),
            //   ),

            if (addressOrUri != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: SelectableText(
                  "${isReceive ? 'Payment URI/Address:\n' : ''}$addressOrUri",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ),

            if (addressOrUri != null && isReceive)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: QrImageView(
                        data: addressOrUri!,
                        version: QrVersions.auto,
                      ),
                    ),
                  ),
                ),
              ),

            if (fees != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Estimated Fees: $fees sats",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.unconfirmedColor,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    onPressed: onSubmit,
                    child: Text(
                      isReceive ? "Generate Invoice" : "Send Payment",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

            if (onCheckRefunds != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Check refunds"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: loading ? null : onCheckRefunds,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: AppColors.text(context)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.accent(context)),
          filled: true,
          fillColor: AppColors.container(context),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.accent(context).opaque(0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.accent(context).opaque(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.accent(context)),
          ),
        ),
      ),
    );
  }
}
