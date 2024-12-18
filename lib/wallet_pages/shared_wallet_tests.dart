// import 'dart:convert';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:bdk_flutter/bdk_flutter.dart';
// import 'package:flutter/services.dart';

// import 'package:flutter_wallet/utilities/base_scaffold.dart';
// import 'package:flutter_wallet/utilities/custom_button.dart';
// import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
// import 'package:flutter_wallet/services/wallet_service.dart';
// import 'package:hive/hive.dart';

// class SharedWalletTests extends StatefulWidget {
//   const SharedWalletTests({
//     super.key,
//   });

//   @override
//   SharedWalletTestsState createState() => SharedWalletTestsState();
// }

// class SharedWalletTestsState extends State<SharedWalletTests> {
//   late WalletService walletService;

//   String? _txToSend;
//   String? _error = 'No Errors, for now';

//   String? gatoAddress;
//   String? perroAddress;

//   int? gatoBalance;
//   int? perroBalance;

//   String? gatoDescriptorString;
//   String? perroDescriptorString;

//   Wallet? gatoWalletState;
//   Wallet? perroWalletState;

//   bool _isLoading = true;

//   final TextEditingController _recipientController = TextEditingController();
//   final TextEditingController _amountController = TextEditingController();
//   final TextEditingController _psbtController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();

//     walletService = WalletService();
//     createSharedWallet();
//   }

//   Future<(DescriptorSecretKey, DescriptorPublicKey)> deriveDescriptorKeys(
//     DerivationPath hardenedPath,
//     DerivationPath unHardenedPath,
//     Mnemonic mnemonic,
//   ) async {
//     // Create the root secret key from the mnemonic
//     final secretKey = await DescriptorSecretKey.create(
//       network: Network.testnet,
//       mnemonic: mnemonic,
//     );

//     // Derive the key at the hardened path
//     final derivedSecretKey = await secretKey.derive(hardenedPath);

//     // Extend the derived secret key further using the unhardened path
//     final derivedExtendedSecretKey =
//         await derivedSecretKey.extend(unHardenedPath);

//     // Convert the derived secret key to its public counterpart
//     final publicKey = derivedSecretKey.toPublic();

//     // Extend the public key using the same unhardened path
//     final derivedExtendedPublicKey =
//         await publicKey.extend(path: unHardenedPath);

//     return (derivedExtendedSecretKey, derivedExtendedPublicKey);
//   }

//   String createWalletDescriptor(
//     String primaryReceivingSecret,
//     String secondaryReceivingPublic,
//     int primaryTimelock,
//     int secondaryTimelock,
//     String primaryChangePublic,
//     String secondaryChangePublic,
//   ) {
//     // Define the multi-sig condition based on timelock priority
//     String multi = (primaryTimelock < secondaryTimelock)
//         ? 'multi(2,$primaryReceivingSecret,$secondaryReceivingPublic)'
//         : 'multi(2,$secondaryReceivingPublic,$primaryReceivingSecret)';

//     // Define the timelock conditions for Bob and Alice
//     String timelockPerro =
//         'and_v(v:older($secondaryTimelock),pk($secondaryChangePublic))';
//     String timelockGato =
//         'and_v(v:older($primaryTimelock),pk($primaryChangePublic))';

//     // Combine the timelock conditions
//     String timelockCondition = (primaryTimelock < secondaryTimelock)
//         ? 'or_i($timelockGato,$timelockPerro)'
//         : 'or_i($timelockPerro,$timelockGato)';

//     // Return the final walletDescriptor
//     return 'wsh(or_d($multi,$timelockCondition))';
//   }

//   Future<void> createSharedWallet() async {
//     try {
//       final gato = await Mnemonic.fromString(
//           'woman few rebuild shrug series rotate nut canvas pledge toilet climb insane');

//       final perro = await Mnemonic.fromString(
//           'put summer method beef move say shrug hurry olive distance harsh lake');

//       const gatoTimelock = 1;
//       const perroTimelock = 2;

//       final hardenedDerivationPath =
//           await DerivationPath.create(path: "m/84h/1h/0h");

//       final receivingDerivationPath = await DerivationPath.create(path: "m/0");
//       final changeDerivationPath = await DerivationPath.create(path: "m/1");

//       final (gatoReceivingSecretKey, gatoReceivingPublicKey) =
//           await deriveDescriptorKeys(
//         hardenedDerivationPath,
//         receivingDerivationPath,
//         gato,
//       );
//       final (gatoChangeSecretKey, gatoChangePublicKey) =
//           await deriveDescriptorKeys(
//         hardenedDerivationPath,
//         changeDerivationPath,
//         gato,
//       );

//       final (perroReceivingSecretKey, perroReceivingPublicKey) =
//           await deriveDescriptorKeys(
//         hardenedDerivationPath,
//         receivingDerivationPath,
//         perro,
//       );
//       final (perroChangeSecretKey, perroChangePublicKey) =
//           await deriveDescriptorKeys(
//         hardenedDerivationPath,
//         changeDerivationPath,
//         perro,
//       );

//       final gatoDescriptor = createWalletDescriptor(
//         gatoReceivingSecretKey.toString(),
//         perroReceivingPublicKey.toString(),
//         gatoTimelock,
//         perroTimelock,
//         gatoChangePublicKey.toString(),
//         perroChangePublicKey.toString(),
//       );

//       final perroDescriptor = createWalletDescriptor(
//         perroReceivingSecretKey.toString(),
//         gatoReceivingPublicKey.toString(),
//         perroTimelock,
//         gatoTimelock,
//         perroChangePublicKey.toString(),
//         gatoChangePublicKey.toString(),
//       );

//       // Debug print descriptors
//       debugPrint("Gato's descriptor: $gatoDescriptor");
//       debugPrint("Perro's descriptor: $perroDescriptor");

//       final gatoWallet = await Wallet.create(
//         descriptor: await Descriptor.create(
//           descriptor: gatoDescriptor,
//           network: Network.testnet,
//         ),
//         network: Network.testnet,
//         databaseConfig: const DatabaseConfig.memory(),
//       );

//       final perroWallet = await Wallet.create(
//         descriptor: await Descriptor.create(
//           descriptor: perroDescriptor,
//           network: Network.testnet,
//         ),
//         network: Network.testnet,
//         databaseConfig: const DatabaseConfig.memory(),
//       );

//       setState(() {
//         gatoBalance = gatoWallet.getBalance().total.toInt();
//         gatoAddress = gatoWallet
//             .getAddress(
//               addressIndex: const AddressIndex.peek(index: 0),
//             )
//             .address
//             .toString();
//         gatoDescriptorString = gatoDescriptor;
//         gatoWalletState = gatoWallet;

//         perroBalance = perroWallet.getBalance().total.toInt();
//         perroAddress = perroWallet
//             .getAddress(
//               addressIndex: const AddressIndex.peek(index: 0),
//             )
//             .address
//             .toString();
//         perroDescriptorString = perroDescriptor;
//         perroWalletState = perroWallet;
//       });
//     } catch (e) {
//       // print("Error creating or fetching balance for wallet: $e");
//       throw ("Error creating or fetching balance for wallet: $e");
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _sendTx() async {
//     if (!mounted) return;

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Sending Menu'),
//           content: StatefulBuilder(
//             builder: (BuildContext context, StateSetter setState) {
//               return Column(
//                 mainAxisSize: MainAxisSize.min, // Adjust the size of the dialog
//                 children: [
//                   TextFormField(
//                     controller: _recipientController,
//                     decoration: CustomTextFieldStyles.textFieldDecoration(
//                       context: context,
//                       labelText: 'Recipient Address',
//                       hintText: 'Enter Recipient\'s Address',
//                     ),
//                     style: TextStyle(
//                       color: Theme.of(context).colorScheme.onSurface,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     controller: _amountController,
//                     decoration: CustomTextFieldStyles.textFieldDecoration(
//                       context: context,
//                       labelText: 'Amount (Sats)',
//                       hintText: 'Enter Amount',
//                     ),
//                     style: TextStyle(
//                       color: Theme.of(context).colorScheme.onSurface,
//                     ),
//                     keyboardType: TextInputType.number,
//                   ),
//                   const SizedBox(height: 16),
//                   CustomButton(
//                     onPressed: () async {},
//                     backgroundColor: Colors.white,
//                     foregroundColor: Colors.orange,
//                     icon: Icons.send_rounded,
//                     iconColor: Colors.black,
//                     label: 'Send All',
//                   ),
//                 ],
//               );
//             },
//           ),
//           actions: [
//             TextButton(
//               style: TextButton.styleFrom(
//                 backgroundColor: Colors.white,
//               ),
//               onPressed: () {
//                 Navigator.of(context).pop(); // Close dialog
//               },
//               child: const Text('Cancel'),
//             ),
//             TextButton(
//               style: TextButton.styleFrom(
//                 backgroundColor: Colors.orange,
//               ),
//               onPressed: () async {
//                 final amount = int.parse(_amountController.text);

//                 final multiSigTransaction =
//                     await walletService.createPartialTxTest(
//                   _recipientController.text,
//                   BigInt.from(amount),
//                   gatoWalletState!,
//                   // 1,
//                   // false,
//                 );

//                 setState(() {
//                   _txToSend = multiSigTransaction;
//                 });

//                 try {
//                   // Show a success message
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('Transaction created successfully.'),
//                       backgroundColor: Colors.green,
//                     ),
//                   );
//                 } catch (e) {
//                   // Show error message in a snackbar
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         e.toString(),
//                         style: TextStyle(color: Colors.white),
//                       ),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }

//                 Navigator.of(context).pop();
//               },
//               child: const Text('Submit'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _signTransaction() async {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Sign MultiSig Transaction'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min, // Adjust the size of the dialog
//             children: [
//               // TextField for Recipient Address
//               TextField(
//                 controller: _psbtController,
//                 decoration: CustomTextFieldStyles.textFieldDecoration(
//                   context: context,
//                   labelText: 'Psbt',
//                   hintText: 'Enter psbt',
//                 ),
//                 style: TextStyle(
//                   color: Theme.of(context).colorScheme.onSurface,
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               style: TextButton.styleFrom(
//                 backgroundColor: Colors.orange,
//               ),
//               onPressed: () async {
//                 try {
//                   log("PSBT Raw: ${_psbtController.text}");

//                   final psbtString = _psbtController.text;

//                   // print("Decoded Transaction: $decoded");
//                   // print("Mnemonic: " + widget.mnemonic);

//                   // await walletService.signBroadcastTx(
//                   //     psbtString, perroWalletState!);

//                   // Show a success message
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('Transaction created successfully.'),
//                       backgroundColor: Colors.green,
//                     ),
//                   );
//                 } catch (e) {
//                   // Assuming `e` is the exception
//                   final errorMessage = e.toString();

//                   // Using a regular expression to extract the parts
//                   final regex = RegExp(r'Error:\s(.+?)\spsbt:\s(.+)');
//                   final match = regex.firstMatch(errorMessage);

//                   if (match != null) {
//                     _error = match.group(1) ??
//                         "Unknown error"; // Extract the error part
//                     _txToSend = match.group(2) ?? ""; // Extract the PSBT part
//                   } else {
//                     // Handle cases where the format doesn't match
//                     _error = "Unexpected error format";
//                     _txToSend = "";
//                   }
//                   // Show error message in a snackbar
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         _error.toString(),
//                         style: TextStyle(color: Colors.white),
//                       ),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }

//                 Navigator.of(context).pop();
//               },
//               child: const Text('Submit'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<int> extractOlderWithPrivateKey(String descriptor) async {
//     // Adjusted regex to match only "older" values followed by "pk(...tprv...)"
//     final regExp =
//         RegExp(r'older\((\d+)\).*?pk\(\[.*?](tp(?:rv|ub)[a-zA-Z0-9]+)');
//     final matches = regExp.allMatches(descriptor);

//     int older = 0;

//     for (var match in matches) {
//       String olderValue = match.group(1)!; // Extract the older value
//       String keyType = match.group(2)!; // Capture whether it's tprv or tpub

//       // Only process the match if it's a private key (tprv)
//       if (keyType.startsWith("tprv")) {
//         debugPrint(
//             'Found older value associated with private key: $olderValue');
//         older = int.parse(olderValue);
//       }
//     }

//     return older;
//   }

//   void debugPrintPrettyJson(String jsonString) {
//     final jsonObject = json.decode(jsonString);
//     const encoder = JsonEncoder.withIndent('  ');
//     debugPrintInChunks(encoder.convert(jsonObject));
//   }

//   void debugPrintInChunks(String text, {int chunkSize = 800}) {
//     for (int i = 0; i < text.length; i += chunkSize) {
//       debugPrint(text.substring(
//           i, i + chunkSize > text.length ? text.length : i + chunkSize));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BaseScaffold(
//       title: const Text('Shared Wallet Page'),
//       body:
//           //  RefreshIndicator(
//           //   key: _refreshIndicatorKey, // Assign the GlobalKey to RefreshIndicator
//           //   onRefresh:
//           //       _syncWallet, // Call this method when the user pulls to refresh
//           //   child:
//           Column(
//         children: [
//           Expanded(
//             child: ListView(
//               padding: const EdgeInsets.all(8.0),
//               children: [
//                 // Display wallet address
//                 _buildInfoBox(
//                   'GatoAddress',
//                   gatoAddress.toString(),
//                   () {
//                     // Handle tap events for Address
//                   },
//                   showCopyButton: true,
//                 ),
//                 _buildInfoBox(
//                   'PerroAddress',
//                   perroAddress.toString(),
//                   () {
//                     // Handle tap events for Address
//                   },
//                   showCopyButton: true,
//                 ),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _buildInfoBox(
//                         'Gato Balance',
//                         '$gatoBalance sats',
//                         () async {
//                           await walletService.syncWallet(gatoWalletState!);

//                           setState(() {
//                             gatoBalance =
//                                 gatoWalletState!.getBalance().total.toInt();
//                           });
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 8), // Add space between the boxes
//                     Expanded(
//                       child: _buildInfoBox(
//                         'Perro Balance',
//                         '$perroBalance sats',
//                         () async {
//                           await walletService.syncWallet(perroWalletState!);

//                           setState(() {
//                             perroBalance =
//                                 perroWalletState!.getBalance().total.toInt();
//                           });
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//                 _buildInfoBox(
//                   'Gato Descriptor',
//                   gatoDescriptorString.toString(),
//                   () {},
//                   showCopyButton: true,
//                 ),
//                 _buildInfoBox(
//                   'Perro Descriptor',
//                   perroDescriptorString.toString(),
//                   () {},
//                   showCopyButton: true,
//                 ),
//                 _buildInfoBox(
//                   'MultiSig Transactions',
//                   _txToSend != null
//                       ? _txToSend.toString()
//                       : 'No transactions to sign',
//                   () {
//                     // Handle tap events for the transaction content if needed
//                     _signTransaction();
//                   },
//                   showCopyButton: true,
//                 ),
//               ],
//             ),
//           ),
//           // Buttons section pinned at the bottom
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 children: [
//                   CustomButton(
//                     onPressed: () {},
//                     backgroundColor: Colors.white,
//                     foregroundColor: Colors.black,
//                     icon: Icons.remove_red_eye, // Icon for the new button
//                     iconColor: Colors.orange,
//                     label: 'Mnemonic',
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       // Send Button
//                       CustomButton(
//                         onPressed: () {
//                           _sendTx();
//                         },
//                         backgroundColor: Colors.white, // White background
//                         foregroundColor:
//                             Colors.orange, // Bitcoin orange color for text
//                         icon: Icons.arrow_upward, // Icon you want to use
//                         iconColor: Colors.orange, // Color for the icon
//                       ),
//                       const SizedBox(width: 8),
//                       // Scan To Send Button
//                       CustomButton(
//                         onPressed: () async {},
//                         backgroundColor: Colors.white, // White background
//                         foregroundColor:
//                             Colors.orange, // Bitcoin orange color for text
//                         icon: Icons.qr_code, // Icon you want to use
//                         iconColor: Colors.black, // Color for the icon
//                       ),
//                       const SizedBox(width: 8),
//                       // Receive Button
//                       CustomButton(
//                         onPressed: () {
//                           // Handle receive functionality
//                         },
//                         backgroundColor: Colors.white, // White background
//                         foregroundColor:
//                             Colors.orange, // Bitcoin orange color for text
//                         icon: Icons.arrow_downward, // Icon you want to use
//                         iconColor: Colors.orange, // Color for the icon
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Box for displaying general wallet info with onTap functionality
//   Widget _buildInfoBox(String title, String data, VoidCallback onTap,
//       {bool showCopyButton = false}) {
//     return GestureDetector(
//       onTap: onTap, // Detects tap and calls the passed function
//       child: Card(
//         margin: const EdgeInsets.symmetric(vertical: 8),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8.0), // Rounded corners
//         ),
//         elevation: 4, // Subtle shadow for depth
//         color: Colors.white, // Match button background
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.orange, // Match button text color
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       data,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Colors.black, // Black text to match theme
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   if (showCopyButton) // Display copy button if true
//                     IconButton(
//                       icon: const Icon(Icons.copy, color: Colors.orange),
//                       tooltip: 'Copy to clipboard',
//                       onPressed: () {
//                         Clipboard.setData(ClipboardData(text: data));
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text("Copied to clipboard"),
//                             duration: Duration(seconds: 1),
//                           ),
//                         );
//                       },
//                     ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
