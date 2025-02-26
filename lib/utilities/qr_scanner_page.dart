import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/snackbar_helper.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  QRScannerPageState createState() => QRScannerPageState();
}

class QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Method to handle QR code scanning and extraction
  void _onDetect(BarcodeCapture barcodeCapture) {
    final barcode =
        barcodeCapture.barcodes.first; // Handle the first detected barcode
    final String? code = barcode.rawValue;

    if (code != null) {
      final recipientAddressStr = extractBitcoinAddress(code);

      if (!mounted) return;

      if (recipientAddressStr != null) {
        controller.stop(); // Stop the scanner when a valid address is found
        Navigator.pop(context, recipientAddressStr); // Return the address
      } else {
        SnackBarHelper.show(
          context,
          message: AppLocalizations.of(context)!.translate('invalid_address'),
          color: AppColors.error(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect, // Update to match the new signature
      ),
    );
  }
}

// Helper function to extract the Bitcoin address from a QR code
String? extractBitcoinAddress(String scannedData) {
  // print('ScannedData: $scannedData');
  // Check if the scanned data is a Bitcoin URI (e.g., bitcoin:<address>)
  if (scannedData.startsWith('bitcoin:')) {
    // Extract the address by splitting the string on `:` and `?` (ignore any parameters like amount)
    final address = scannedData.split(':')[1].split('?')[0];
    return isValidBitcoinAddress(address) ? address : null;
  }

  // If it's not a Bitcoin URI, check if it's a plain address
  return isValidBitcoinAddress(scannedData) ? scannedData : null;
}

// Helper function to validate a Bitcoin address
bool isValidBitcoinAddress(String address) {
  // Updated regex to handle:
  // - Mainnet: Legacy (1), P2SH (3), Bech32 (bc1)
  // - Testnet: Legacy (m/n), P2SH (2), Bech32 (tb1)
  final btcAddressRegex = RegExp(
    r'^(bc1|tb1|[13]|[mn2])[a-zA-HJ-NP-Z0-9]{25,62}$',
  );
  return btcAddressRegex.hasMatch(address);
}
