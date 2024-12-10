// import 'package:flutter/material.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart';

// class QRScannerPage extends StatefulWidget {
//   const QRScannerPage({super.key});

//   @override
//   QRScannerPageState createState() => QRScannerPageState();
// }

// class QRScannerPageState extends State<QRScannerPage> {
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//   QRViewController? controller;

//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }

//   // Method to handle QR code scanning and extraction
//   void _onQRViewCreated(QRViewController controller) {
//     this.controller = controller;
//     controller.scannedDataStream.listen((scanData) {
//       // print('Scanned Data: ${scanData.code}');

//       final recipientAddressStr = extractBitcoinAddress(scanData.code ?? '');

//       if (!mounted) return;

//       if (recipientAddressStr != null) {
//         controller
//             .pauseCamera(); // Pause the camera when a valid address is scanned
//         Navigator.pop(context, recipientAddressStr); // Return the address
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Invalid Bitcoin address')),
//         );
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Scan QR Code'),
//       ),
//       body: QRView(
//         key: qrKey,
//         onQRViewCreated: _onQRViewCreated,
//       ),
//     );
//   }
// }

// // Helper function to extract the Bitcoin address from a QR code
// String? extractBitcoinAddress(String scannedData) {
//   // Check if the scanned data is a Bitcoin URI (e.g., bitcoin:<address>)
//   if (scannedData.startsWith('bitcoin:')) {
//     // Extract the address by splitting the string on `:` and `?` (ignore any parameters like amount)
//     final address = scannedData.split(':')[1].split('?')[0];
//     return isValidBitcoinAddress(address) ? address : null;
//   }

//   // If it's not a Bitcoin URI, check if it's a plain address
//   return isValidBitcoinAddress(scannedData) ? scannedData : null;
// }

// // Helper function to validate a Bitcoin address
// bool isValidBitcoinAddress(String address) {
//   // Regular expression to match:
//   // - Mainnet Legacy (1), P2SH (3), and Bech32 (bc1)
//   // - Testnet Legacy (m/n), P2SH (2), and Bech32 (tb1)
//   final btcAddressRegex =
//       RegExp(r'^(1|3|bc1|m|n|2|tb1)[a-zA-HJ-NP-Z0-9]{25,49}$');
//   return btcAddressRegex.hasMatch(address);
// }
