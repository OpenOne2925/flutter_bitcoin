import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

class CreateSharedWallet extends StatefulWidget {
  const CreateSharedWallet({super.key});

  @override
  CreateSharedWalletState createState() => CreateSharedWalletState();
}

class CreateSharedWalletState extends State<CreateSharedWallet> {
  final WalletService _walletService = WalletService();

  final TextEditingController _pubKeyController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();
  List<TextEditingController> additionalPublicKeyControllers = [
    TextEditingController()
  ];

  String? threshold;
  List<Map<String, String>> publicKeysWithAlias = [];
  List<Map<String, dynamic>> timelockConditions = [];

  // List<String> publicKeys = [];
  // List<String> timelocks = [];

  String? _mnemonic;
  String _finalDescriptor = "";
  String _publicKey = "";
  bool isLoading = false;

  Future<void> _generatePublicKey() async {
    setState(() => isLoading = true);
    try {
      final walletBox = Hive.box('walletBox');
      final savedMnemonic = walletBox.get('walletMnemonic');
      final mnemonic = await Mnemonic.fromString(savedMnemonic);

      print('Mnemonic: $savedMnemonic');

      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      final (_, receivingPublicKey) = await _walletService.deriveDescriptorKeys(
        hardenedDerivationPath,
        receivingDerivationPath,
        mnemonic,
      );

      setState(() {
        _publicKey = receivingPublicKey.toString();
        _mnemonic = savedMnemonic;
        _pubKeyController.text = receivingPublicKey.toString();
      });
    } catch (e) {
      print("Error generating public key: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  String buildTimelockCondition(List<String> formattedTimelocks) {
    String combineConditions(List<String> conditions) {
      while (conditions.length > 1) {
        List<String> combined = [];
        for (int i = 0; i < conditions.length; i += 2) {
          if (i + 1 < conditions.length) {
            combined.add('or_i(${conditions[i]},${conditions[i + 1]})');
          } else {
            combined.add(conditions[i]);
          }
        }
        conditions = combined;
      }
      return conditions.first;
    }

    return combineConditions(formattedTimelocks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Shared Wallet',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Generate Public Key
            Text(
              '1. Generate Public Key',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            CustomButton(
              onPressed: _generatePublicKey,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              icon: Icons.vpn_key,
              iconColor: Colors.orange,
              label: 'Generate Public Key',
              padding: 16.0,
              iconSize: 24.0,
            ),
            if (_publicKey.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Generated Public Key: $_publicKey',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.orange),
                    tooltip: 'Copy to Clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _publicKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Public Key copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              // Text('Generated Public Key: $_publicKey'),
            ],

            const Divider(height: 40),

            // Section 2: Enter Public Keys for Multisig
            Text(
              '2. Enter Public Keys for Multisig',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 100, // Set your desired width
                  child: TextFormField(
                    onFieldSubmitted: (value) {
                      setState(() {
                        threshold = _thresholdController.text;
                      });
                    },
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: 'Threshold',
                      hintText: 'Thresh',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_sharp,
                      size: 40, color: Colors.orange),
                  onPressed: _showAddPublicKeyDialog,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (publicKeysWithAlias.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: publicKeysWithAlias.map((key) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor:
                                Colors.black, // Set the background color
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  16.0), // Optional rounded corners
                            ),
                            title: Text('Public Key Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  initialValue:
                                      'Public Key: ${key['publicKey']}',
                                  readOnly: true,
                                  decoration:
                                      CustomTextFieldStyles.textFieldDecoration(
                                    context: context,
                                    labelText: 'Public Key',
                                  ),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  initialValue: 'Alias: ${key['alias']}',
                                  readOnly: true,
                                  decoration:
                                      CustomTextFieldStyles.textFieldDecoration(
                                    context: context,
                                    labelText: 'Alias',
                                  ),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        key['alias']!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const Divider(height: 40),

            // Section 3: Enter Timelock Conditions
            Text(
              '3. Enter Timelock Conditions',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            IconButton(
              icon:
                  const Icon(Icons.lock_clock, size: 40, color: Colors.orange),
              onPressed: _showAddTimelockDialog,
            ),
            const SizedBox(height: 10),
            if (timelockConditions.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: timelockConditions.map((condition) {
                  // print('condition: $condition');

                  // Retrieve aliases for the selected public keys
                  List<dynamic> aliases =
                      condition['pubkeys'].map((pubkeyEntry) {
                    // Extract the publicKey from the current entry
                    String publicKey = pubkeyEntry['publicKey'];

                    // print('Searching for publicKey: $publicKey');

                    // Debugging: Log all available public keys
                    // publicKeysWithAlias.forEach((entry) {
                    //   print('Available publicKey: ${entry['publicKey']}');
                    // });

                    // Find the alias for the publicKey in publicKeysWithAlias
                    return publicKeysWithAlias.firstWhere(
                      (entry) =>
                          entry['publicKey']!
                              .trim()
                              .substring(0, entry['publicKey']!.length - 3) ==
                          publicKey.trim().substring(0, publicKey.length - 3),
                      orElse: () => {'alias': 'Unknown'},
                    )['alias'];
                  }).toList();

                  // print('aliases: $aliases');

                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor:
                                Colors.black, // Set the background color
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  16.0), // Optional rounded corners
                            ),
                            title: Text(
                              'Timelock Condition Details',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    initialValue: condition['threshold'],
                                    readOnly: true,
                                    decoration: CustomTextFieldStyles
                                        .textFieldDecoration(
                                      context: context,
                                      labelText: 'Threshold',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    initialValue: condition['older'],
                                    readOnly: true,
                                    decoration: CustomTextFieldStyles
                                        .textFieldDecoration(
                                      context: context,
                                      labelText: 'Older',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: condition['pubkeys']
                                        .map<Widget>((pubkeyData) {
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10.0),
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          border:
                                              Border.all(color: Colors.orange),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Public Key:',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              pubkeyData['publicKey'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Alias:',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pubkeyData['alias'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 10),
                                  // TextFormField(
                                  //   initialValue: aliases.join(', '),
                                  //   readOnly: true,
                                  //   decoration: CustomTextFieldStyles
                                  //       .textFieldDecoration(
                                  //     context: context,
                                  //     labelText: 'Aliases',
                                  //   ),
                                  //   style: TextStyle(
                                  //     color: Theme.of(context)
                                  //         .colorScheme
                                  //         .onSurface,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Threshold: ${condition['threshold']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Older: ${condition['older']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'PubKeys: ${aliases.join(', ')}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const Divider(height: 40),

            // Section 4: Create Descriptor
            Text(
              '4. Create Descriptor',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            CustomButton(
              onPressed: () => _createDescriptor(),
              backgroundColor: Colors.white, // White background
              foregroundColor: Colors.black, // Bitcoin orange color for text
              icon: Icons.create, // Icon you want to use
              iconColor: Colors.orange, // Color for the icon
              label: 'Create Descriptor',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPublicKeyDialog() {
    final TextEditingController publicKeyController = TextEditingController();
    final TextEditingController aliasController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Set the background color
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16.0), // Optional rounded corners
          ),
          title: const Text('Add Public Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: publicKeyController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                    context: context,
                    labelText: 'Enter Public Key',
                    hintText: 'Enter Public Key'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: aliasController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter Alias',
                  hintText: 'Enter Alias Name',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (publicKeyController.text.isNotEmpty &&
                      aliasController.text.isNotEmpty) {
                    publicKeysWithAlias.add({
                      'publicKey': publicKeyController.text,
                      'alias': aliasController.text,
                    });
                  }
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showAddTimelockDialog() {
    final TextEditingController thresholdController = TextEditingController();
    final TextEditingController olderController = TextEditingController();
    List<Map<String, String>> selectedPubKeys =
        []; // Store both pubkey and alias

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // If the StateSetter variable is called setState it will cause rebuilding problems
          // Give another name like setDialogState
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black, // Set the background color
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16.0), // Optional rounded corners
              ),
              title: const Text('Add Timelock Condition'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: thresholdController,
                      decoration: CustomTextFieldStyles.textFieldDecoration(
                        context: context,
                        labelText: 'Enter Threshold',
                        hintText: 'Threshold',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: olderController,
                      decoration: CustomTextFieldStyles.textFieldDecoration(
                        context: context,
                        labelText: 'Enter Older Value',
                        hintText: 'Older (timelock)',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    if (publicKeysWithAlias.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        children: publicKeysWithAlias.map((key) {
                          bool isSelected = selectedPubKeys.any((selectedKey) =>
                              selectedKey['publicKey'] == key['publicKey']);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedPubKeys.removeWhere((selectedKey) =>
                                      selectedKey['publicKey'] ==
                                      key['publicKey']);
                                } else {
                                  selectedPubKeys.add({
                                    'publicKey': key['publicKey']!,
                                    'alias': key['alias']!
                                  });
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange
                                        .withAlpha((0.8 * 255).toInt())
                                    : Colors.orange
                                        .withAlpha((0.2 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Text(
                                key['alias']!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (thresholdController.text.isNotEmpty &&
                        olderController.text.isNotEmpty &&
                        selectedPubKeys.isNotEmpty) {
                      setState(() {
                        // Add the new timelock condition to the list
                        timelockConditions.add({
                          'threshold': thresholdController.text,
                          'older': olderController.text,
                          'pubkeys': selectedPubKeys.map((pubKey) {
                            return {
                              'publicKey': pubKey['publicKey']!,
                              'alias': pubKey['alias']!,
                            };
                          }).toList(),
                        });
                      });
                    } else {
                      print('Validation Failed: One or more fields are empty');
                    }
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleTimelocks() {
    final regex = RegExp(
        r'\/(\d+)(?=\/\*)'); // Matches the last number in the derivation path before '/*'

    setState(() {
      Set<String> seenPubKeys = {}; // Track already-seen public keys

      // Add already-used public keys to the set
      seenPubKeys
          .addAll(publicKeysWithAlias.map((entry) => entry['publicKey']!));

      // Process each timelock condition
      timelockConditions = timelockConditions.map((condition) {
        // print('ConditionHandling: ${condition['pubkeys']}');

        // Extract and process pubkeys while preserving aliases
        List<Map<String, String>> updatedPubKeys =
            (condition['pubkeys'] as List).map((key) {
          // Extract the original key and alias
          String originalKey = key['publicKey'] as String;
          String alias = key['alias'] as String;

          // Resolve duplicate public keys
          while (seenPubKeys.contains(originalKey)) {
            // Modify the key by incrementing the last number in the derivation path
            originalKey = originalKey.replaceFirstMapped(regex, (match) {
              int currentValue = int.parse(match.group(1)!);
              return '/${currentValue + 1}';
            });
          }

          // Add the (possibly modified) key to the set of seen keys
          seenPubKeys.add(originalKey);

          // Return the updated key with its alias
          return {
            'publicKey': originalKey,
            'alias': alias,
          };
        }).toList();

        // Update the condition with the resolved pubkeys
        return {
          ...condition,
          'pubkeys': updatedPubKeys,
        };
      }).toList();
    });

    // print('Updated Timelock Conditions: $timelockConditions');
  }

  void _createDescriptor() {
    // Extract only the public keys from the list of public keys with alias
    List<String> extractedPublicKeys =
        publicKeysWithAlias.map((entry) => entry['publicKey']!).toList();

    // Format the public keys for the descriptor
    String formattedKeys =
        extractedPublicKeys.toString().replaceAll(RegExp(r'^\[|\]$'), '');

    String multi = 'multi($threshold,$formattedKeys)';
    String finalDescriptor;

    // Handle any potential duplicates in timelock public keys
    _handleTimelocks();

    if (timelockConditions.isNotEmpty) {
      // Build timelock condition string
      List<String> formattedTimelocks = timelockConditions.map((condition) {
        String threshold = condition['threshold'];
        String older = condition['older'];

        // Extract only the publicKey values from pubkeys
        List<String> pubkeys = (condition['pubkeys'] as List)
            .map((key) => key['publicKey'] as String)
            .toList();

        // Construct multi condition for the current timelock
        String pubkeysString = pubkeys.join(',');
        String multiCondition = pubkeys.length > 1
            ? 'multi($threshold,$pubkeysString)'
            : 'pk(${pubkeys.first})';

        // Combine with the older value
        return 'and_v(v:older($older),$multiCondition)';
      }).toList();

      // Combine all timelock conditions into a single valid condition
      String timelockCondition = buildTimelockCondition(formattedTimelocks);
      finalDescriptor = 'wsh(or_d($multi,$timelockCondition))';
    } else {
      finalDescriptor = 'wsh($multi)';
    }

    setState(() {
      _finalDescriptor = finalDescriptor.replaceAll(' ', '');
    });

    _createDescriptorDialog(context);
  }

  void _createDescriptorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Set the background color
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16.0), // Optional rounded corners
          ),
          title: Text(
            'Descriptor Created',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display descriptor
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha((0.6 * 255).toInt()),
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Descriptor: $_finalDescriptor',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.orange),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: _finalDescriptor));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Descriptor copied to clipboard'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Display conditions
                Text(
                  'Conditions:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  children: timelockConditions.map((condition) {
                    // Retrieve aliases for the selected public keys
                    List<String> aliases =
                        (condition['pubkeys'] as List<Map<String, String>>)
                            .map((key) => key['alias']!)
                            .toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Threshold: ${condition['threshold']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Older: ${condition['older']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Aliases: ${aliases.join(', ')}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // Display public keys with aliases
                Text(
                  'Public Keys:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  children: publicKeysWithAlias.map((key) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Public Key: ${key['publicKey']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Alias: ${key['alias']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Serialize data to JSON
                final data = jsonEncode({
                  'descriptor': _finalDescriptor,
                  'publicKeysWithAlias': publicKeysWithAlias,
                });

                // // Request storage permission (required for Android 11 and below)
                // if (await Permission.storage.request().isGranted) {
                // Get default Downloads directory
                final directory = Directory('/storage/emulated/0/Download');
                if (!await directory.exists()) {
                  await directory.create(recursive: true);
                }

                final filePath = '${directory.path}/shared_wallet.json';
                final file = File(filePath);

                // Write JSON data to the file
                await file.writeAsString(data);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'File saved to ${directory.path}/shared_wallet.json'),
                  ),
                );
                // } else {
                //   // Permission denied
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     const SnackBar(
                //       content: Text(
                //           'Storage permission is required to save the file'),
                //     ),
                //   );
                // }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Download Descriptor'),
            ),
            TextButton(
              onPressed: () {
                print('_mnemonic: $_mnemonic');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SharedWallet(
                      descriptor: _finalDescriptor,
                      mnemonic: _mnemonic!,
                      pubKeysAlias: publicKeysWithAlias,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Navigate to Wallet'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
