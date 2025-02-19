import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';

class WalletSendtxHelpers {
  final bool isSingleWallet;
  final BuildContext context;
  final TextEditingController recipientController;

  final TextEditingController amountController;
  final WalletService walletService;
  final int currentHeight;
  final Wallet wallet;
  final String mnemonic;
  final bool mounted;
  final String address;

  TextEditingController? psbtController;
  TextEditingController? signingAmountController;
  Map<String, dynamic>? policy;
  String? myFingerPrint;
  List<dynamic>? utxos;
  List<Map<String, dynamic>>? spendingPaths;
  String? descriptor;
  List<String>? signersList;
  List<Map<String, String>>? pubKeysAlias;
  Function(String)? onTransactionCreated;

  WalletSendtxHelpers({
    required this.isSingleWallet,
    required this.context,
    required this.recipientController,
    required this.amountController,
    required this.walletService,
    required this.mnemonic,
    required this.wallet,
    required this.address,
    required this.currentHeight,
    required this.mounted,

    // SharedWallet Variables
    this.psbtController,
    this.signingAmountController,
    this.policy,
    this.myFingerPrint,
    this.utxos,
    this.spendingPaths,
    this.descriptor,
    this.signersList,
    this.pubKeysAlias,
    this.onTransactionCreated,
  });

  void sendTx(bool isCreating, {String? recipientAddressQr}) async {
    if (recipientAddressQr != null) {
      recipientController.text = recipientAddressQr;
    }

    Map<String, dynamic>? selectedPath; // Variable to store the selected path
    int? selectedIndex; // Variable to store the selected path

    if (!mounted) return;

    final extractedData =
        walletService.extractDataByFingerprint(policy!, myFingerPrint!);

    if (extractedData.isNotEmpty) {
      selectedPath = extractedData[0]; // Default to the first path
    }

    // print('extractedData: $extractedData');

    List<String>? signers;

    PartiallySignedTransaction psbt;

    bool isSelectable = true;

    final rootContext = context;

    showDialog(
      context: rootContext,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], // Dark background color for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // Rounded corners
          ),
          title:
              Text(isCreating ? 'Sending Menu' : 'Sign MultiSig Transaction'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Adjust the size of the dialog
                      children: [
                        TextFormField(
                          readOnly: !isCreating,
                          controller: recipientController,
                          decoration: CustomTextFieldStyles.textFieldDecoration(
                            context: context,
                            labelText: 'Recipient Address',
                            hintText: 'Enter Recipient\'s Address',
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Visibility(
                          visible: !isCreating,
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: psbtController,
                                onFieldSubmitted: (event) async {
                                  try {
                                    psbt = await PartiallySignedTransaction
                                        .fromString(psbtController!.text);

                                    Transaction result = psbt.extractTx();

                                    final outputs = result.output();

                                    signers =
                                        walletService.getSignersFromPsbt(psbt);

                                    final signersAliases =
                                        walletService.getAliasesFromFingerprint(
                                            pubKeysAlias!, signers!);

                                    bool isInternalTransaction = false;

                                    int totalSpent = 0;

                                    isInternalTransaction = await walletService
                                        .areEqualAddresses(outputs);

                                    Address? receiverAddress;

                                    for (final output in outputs) {
                                      receiverAddress = await walletService
                                          .getAddressFromScriptOutput(output);

                                      // TODO: Do not add change address

                                      print(
                                          'receiverAddress: $receiverAddress');

                                      if (isInternalTransaction) {
                                        totalSpent += output.value.toInt();
                                      } else if (receiverAddress.asString() !=
                                          address) {
                                        totalSpent += output.value.toInt();
                                      }
                                    }

                                    setState(() {
                                      signingAmountController!.text =
                                          totalSpent.toString();
                                      signersList = signersAliases;
                                      recipientController.text =
                                          receiverAddress.toString();
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invalid PSBT: $e',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }

                                  // print("Total spent: $totalSpent");

                                  // walletService.printInChunks(psbt.asString());
                                },
                                decoration:
                                    CustomTextFieldStyles.textFieldDecoration(
                                  context: context,
                                  labelText: 'Psbt',
                                  hintText: 'Enter psbt',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (signersList!.isNotEmpty)
                          Visibility(
                            visible: signersList!.isNotEmpty,
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 6.0,
                                  children: signersList!.map((signer) {
                                    return Chip(
                                      label: Text(
                                        signer,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.green,
                                      avatar: Icon(Icons.verified,
                                          color: Colors.white),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        isCreating
                            ? TextFormField(
                                controller: amountController,
                                onChanged: (value) {
                                  setState(() {
                                    // print('Editing');
                                  });
                                },
                                decoration:
                                    CustomTextFieldStyles.textFieldDecoration(
                                  context: context,
                                  labelText: 'Amount (Sats)',
                                  hintText: 'Enter Amount',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                keyboardType: TextInputType.number,
                              )
                            : TextFormField(
                                controller: signingAmountController,
                                readOnly: true,
                                onChanged: (value) {
                                  setState(() {
                                    // print('Editing');
                                  });
                                },
                                decoration:
                                    CustomTextFieldStyles.textFieldDecoration(
                                  context: context,
                                  labelText: 'Amount (Sats)',
                                  hintText: 'Enter Amount',
                                ),
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                        if (!isSingleWallet) ...[
                          const SizedBox(height: 16),
                          // Dropdown for selecting the spending path
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: selectedPath,
                            items: extractedData.map((data) {
                              // Check if the item meets the condition
                              isSelectable = walletService.checkCondition(
                                data,
                                utxos!,
                                isCreating
                                    ? amountController.text
                                    : signingAmountController!.text,
                                currentHeight,
                              );

                              // print(isSelectable);

                              // Replace fingerprints with aliases
                              List<String> aliases =
                                  (data['fingerprints'] as List<dynamic>)
                                      .map<String>((fingerprint) {
                                final matchedAlias = pubKeysAlias!.firstWhere(
                                  (pubKeyAlias) => pubKeyAlias['publicKey']!
                                      .contains(fingerprint),
                                  orElse: () => {
                                    'alias': fingerprint
                                  }, // Fallback to fingerprint
                                );

                                return matchedAlias['alias'] ?? fingerprint;
                              }).toList();

                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: data,
                                enabled:
                                    isSelectable, // Disable interaction for unselectable items
                                child: Text(
                                  "Type: ${data['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK: ${data['timelock']} blocks' : 'MULTISIG'}, "
                                  "${data['threshold'] != null ? '${data['threshold']} of ${aliases.length}, ' : ''} Keys: ${aliases.join(', ')}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelectable
                                        ? Colors.white
                                        : Colors
                                            .grey, // Use gray for unselectable
                                  ),
                                ),
                              );
                            }).toList(),
                            onTap: () {
                              setState(() {
                                // print('Rebuilding');
                              });
                            },
                            onChanged: (Map<String, dynamic>? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  selectedPath =
                                      newValue; // Update the selected path
                                  selectedIndex = extractedData
                                      .indexOf(newValue); // Update the index
                                });
                                print(selectedPath);
                                print(selectedIndex);
                              } else {
                                // Optionally handle the selection of unselectable items
                                print("This item is unavailable.");
                              }
                            },
                            selectedItemBuilder: (BuildContext context) {
                              return extractedData.map((data) {
                                isSelectable = walletService.checkCondition(
                                  data,
                                  utxos!,
                                  isCreating
                                      ? amountController.text
                                      : signingAmountController!.text,
                                  currentHeight,
                                );

                                // print(isSelectable);

                                return Text(
                                  "Type: ${data['type'].contains('RELATIVETIMELOCK') ? 'TIMELOCK ${data['timelock']} blocks' : 'MULTISIG'}, ...",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelectable
                                        ? Colors.white
                                        : Colors.grey,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            decoration: InputDecoration(
                              labelText: 'Select Spending Path',
                              labelStyle: const TextStyle(color: Colors.white),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    const BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    const BorderSide(color: Colors.green),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            dropdownColor: Colors.grey[850],
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (isCreating)
                          InkwellButton(
                            onTap: () async {
                              try {
                                // Validate recipient address
                                if (recipientController.text.isEmpty) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        backgroundColor: Colors
                                            .grey[900], // Dark background color
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                        ),
                                        title: Row(
                                          children: [
                                            Icon(Icons.error,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Error',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ],
                                        ),
                                        content: Text(
                                          'Please enter a recipient address.',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('OK',
                                                style: TextStyle(
                                                    color: Colors.green)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  return; // Exit the function early if validation fails
                                }

                                try {
                                  walletService.validateAddress(
                                      recipientController.text);
                                } catch (e) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Row(
                                          children: [
                                            Icon(Icons.error,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Invalid Address'),
                                          ],
                                        ),
                                        content: Text(e.toString()),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  return; // Exit the function early if address is invalid
                                }
                                if (!isSingleWallet) {
                                  // Validate spending path
                                  if (selectedPath == null) {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          backgroundColor: Colors.grey[
                                              900], // Dark background color
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                          ),
                                          title: Row(
                                            children: [
                                              Icon(Icons.error,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Error',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ],
                                          ),
                                          content: Text(
                                            'Please select a spending path.',
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: Text('OK',
                                                  style: TextStyle(
                                                      color: Colors.green)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    return; // Exit the function early if validation fails
                                  }
                                }

                                await walletService.syncWallet(wallet);

                                final availableBalance =
                                    wallet.getBalance().spendable;

                                final String recipientAddress =
                                    recipientController.text.toString();
                                print('Selected Index: $selectedIndex');

                                int sendAllBalance = 0;

                                if (isSingleWallet) {
                                  sendAllBalance = await walletService
                                      .calculateSendAllBalance(
                                    recipientAddress: recipientAddress,
                                    wallet: wallet,
                                    availableBalance: availableBalance.toInt(),
                                    walletService: walletService,
                                  );
                                } else {
                                  sendAllBalance = int.parse(
                                      (await walletService.createPartialTx(
                                    descriptor.toString(),
                                    mnemonic,
                                    recipientAddress,
                                    availableBalance,
                                    selectedIndex,
                                    isSendAllBalance: true,
                                    spendingPaths: spendingPaths,
                                  ))!);
                                }

                                amountController.text =
                                    sendAllBalance.toString();
                              } catch (e) {
                                print('Error: $e');
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: Colors
                                          .grey[900], // Dark background color
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(Icons.error, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Error',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                      content: Text(
                                        'An error occurred: ${e.toString()}',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text('OK',
                                              style: TextStyle(
                                                  color: Colors.green)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            },
                            label: 'Use Available Balance',
                            icon: Icons.account_balance_wallet_rounded,
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                            iconColor: Colors.white,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            InkwellButton(
              onTap: () {
                Navigator.of(context).pop(); // Close dialog
              },
              label: 'Cancel',
              backgroundColor: Colors.white,
              textColor: Colors.black,
            ),
            InkwellButton(
              onTap: () async {
                try {
                  String recipientAddressStr = "";
                  int amount = 0;

                  String psbtString;
                  String? result;
                  await walletService.syncWallet(wallet);

                  if (isCreating) {
                    recipientAddressStr = recipientController.text;
                    amount = int.parse(amountController.text);

                    if (isSingleWallet) {
                      await walletService.sendSingleTx(
                        recipientAddressStr,
                        BigInt.from(amount),
                        wallet,
                        address,
                      );
                    } else {
                      result = await walletService.createPartialTx(
                          descriptor.toString(),
                          mnemonic,
                          recipientAddressStr,
                          BigInt.from(amount),
                          selectedIndex, // Use the selected path
                          spendingPaths: spendingPaths);
                    }
                  } else {
                    psbtString = psbtController!.text;

                    result = await walletService.signBroadcastTx(
                      psbtString,
                      descriptor.toString(),
                      mnemonic,
                      selectedIndex,
                    );
                  }

                  if (result != null) {
                    onTransactionCreated!(result);
                  }

                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(isCreating
                          ? 'Transaction Created Successfully.'
                          : 'Transaction Signed Successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString(),
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }

                Navigator.of(context).pop();
              },
              label: 'Submit',
              backgroundColor: Colors.green,
              textColor: Colors.white,
            ),
          ],
        );
      },
    ).then((_) {
      recipientController.clear();
      if (!isSingleWallet) {
        psbtController!.clear();
        signingAmountController!.clear();
      }
      amountController.clear();

      signersList = [];

      selectedPath = null; // Reset the dropdown selection
      selectedIndex = null; // Reset the selected index
    });
  }
}
