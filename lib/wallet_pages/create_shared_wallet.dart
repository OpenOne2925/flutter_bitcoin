import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateSharedWallet extends StatefulWidget {
  const CreateSharedWallet({super.key});

  @override
  CreateSharedWalletState createState() => CreateSharedWalletState();
}

class CreateSharedWalletState extends State<CreateSharedWallet> {
  final WalletService _walletService = WalletService();

  final TextEditingController _thresholdController = TextEditingController();
  List<TextEditingController> additionalPublicKeyControllers = [
    TextEditingController()
  ];
  final TextEditingController _descriptorNameController =
      TextEditingController();

  String? threshold;
  List<Map<String, String>> publicKeysWithAlias = [];
  List<Map<String, dynamic>> timelockConditions = [];

  // List<String> publicKeys = [];
  // List<String> timelocks = [];

  String? _mnemonic;
  String _finalDescriptor = "";
  String? _publicKey = "";
  String _descriptorName = "";
  bool isLoading = false;

  String? initialPubKey;

  // TODO: add animations and loading after creating descriptor or something like that idk
  bool _isDescriptorValid = true;
  String _status = 'Idle';

  bool _isDuplicateDescriptor = false;
  bool _isDescriptorNameMissing = false;
  bool _isThresholdMissing = false;
  bool _isYourPubKeyMissing = false;
  bool _arePublicKeysMissing = false;

  @override
  void initState() {
    super.initState();

    // // Add a listner to the TextEditingController
    // _descriptorController.addListener(() {
    //   if (_descriptorController.text.isNotEmpty) {
    //     _descriptor = _descriptorController.text;
    //     _validateDescriptor(_descriptor.toString());
    //   }
    // });

    _generatePublicKey(isGenerating: false);
  }

  void _validateInputs() {
    setState(() {
      // print(_publicKey);
      // print(publicKeysWithAlias);
      _isYourPubKeyMissing = !publicKeysWithAlias.any((entry) {
        return entry['publicKey'] == initialPubKey;
      });
      _isDescriptorNameMissing = _descriptorNameController.text.isEmpty;
      _isThresholdMissing = _thresholdController.text.isEmpty;
      _arePublicKeysMissing = publicKeysWithAlias.isEmpty;
    });
  }

  Future<void> _generatePublicKey({bool isGenerating = true}) async {
    setState(() => isLoading = true);
    try {
      final walletBox = Hive.box('walletBox');
      final savedMnemonic = walletBox.get('walletMnemonic');
      final mnemonic = await Mnemonic.fromString(savedMnemonic);

      // print('Mnemonic: $savedMnemonic');

      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      final (_, receivingPublicKey) = await _walletService.deriveDescriptorKeys(
        hardenedDerivationPath,
        receivingDerivationPath,
        mnemonic,
      );

      setState(() {
        if (isGenerating) {
          _publicKey = receivingPublicKey.toString();
        }
        initialPubKey = receivingPublicKey.toString();
        _mnemonic = savedMnemonic;
      });
    } catch (e) {
      print("Error generating public key: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Asynchronous method to validate the descriptor
  Future<bool> _validateDescriptor(String descriptor) async {
    try {
      ValidationResult result = await _walletService.isValidDescriptor(
          descriptor, initialPubKey.toString());

      // print(result.toString());

      setState(() {
        _isDescriptorValid = result.isValid;
        _status = result.isValid
            ? 'Descriptor is valid'
            : result.errorMessage ?? 'Invalid Descriptor';
      });
      return result.isValid;
    } catch (e) {
      setState(() {
        _isDescriptorValid = false;
        _status = 'Error validating Descriptor: $e';
      });
      return false;
    }
  }

  void _navigateToSharedWallet() async {
    bool isValid = await _validateDescriptor(_finalDescriptor);
    setState(() {
      _status = 'Loading';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (isValid) {
      setState(() {
        _status = 'Success';
      });

      await Future.delayed(const Duration(seconds: 1));

      // _walletService.printInChunks(_descriptor.toString());

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedWallet(
            descriptor: _finalDescriptor,
            mnemonic: _mnemonic!,
            pubKeysAlias: publicKeysWithAlias,
            descriptorName: _descriptorName,
          ),
        ),
      );
    } else {
      setState(() {
        _status = 'Cannot navigate: Invalid Descriptor';
      });
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

  bool _isDuplicateDescriptorName(String descriptorName) {
    final descriptorBox = Hive.box('descriptorBox');

    // Iterate through all keys and check if any key contains the same descriptor name
    for (var key in descriptorBox.keys) {
      print(key);
      if (key.toString().contains(descriptorName.trim())) {
        return true; // Duplicate found
      }
    }
    return false; // No duplicate found
  }

  String _generateSectionErrorMessage(List<Map<String, dynamic>> conditions) {
    List<String> errors = [];

    for (var condition in conditions) {
      if (condition['condition'] as bool) {
        errors.add(condition['message'] as String);
      }
    }

    return errors.join('. ') + (errors.isNotEmpty ? '.' : '');
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
            // Section: Descriptor Name
            Text(
              'Descriptor Name',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _isDescriptorNameMissing ? Colors.red : Colors.white,
              ),
            ),
            // Error Message
            if (_isDescriptorNameMissing || _isDuplicateDescriptor)
              Text(
                _generateSectionErrorMessage([
                  {
                    'condition': _isDescriptorNameMissing,
                    'message': 'Descriptor name is missing'
                  },
                  {
                    'condition': _isDuplicateDescriptor,
                    'message': 'Descriptor name already exists'
                  },
                ]),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptorNameController,
              onFieldSubmitted: (value) {
                setState(() {
                  _descriptorName = _descriptorNameController.text.trim();

                  _isDuplicateDescriptor =
                      _isDuplicateDescriptorName(_descriptorName);
                });
              },
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText: 'Enter Descriptor Name',
                hintText: 'E.g., MySharedWallet',
                borderColor:
                    _isDescriptorNameMissing ? Colors.red : Colors.green,
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
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
              iconColor: Colors.green,
              label: 'Generate Public Key',
              padding: 16.0,
              iconSize: 24.0,
            ),
            if (_publicKey != null) ...[
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
                    icon: const Icon(Icons.copy, color: Colors.green),
                    tooltip: 'Copy to Clipboard',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _publicKey!));
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title
                Text(
                  '2. Enter Public Keys for Multisig',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: (_isThresholdMissing ||
                            _arePublicKeysMissing ||
                            _isYourPubKeyMissing)
                        ? Colors.red
                        : Colors.white,
                  ),
                ),
                const SizedBox(
                    height:
                        8), // Add spacing between the title and the error message

                // Error Message
                if (_isThresholdMissing ||
                    _arePublicKeysMissing ||
                    _isYourPubKeyMissing)
                  Text(
                    _generateSectionErrorMessage([
                      {
                        'condition': _isThresholdMissing,
                        'message': 'Threshold is missing'
                      },
                      {
                        'condition': _arePublicKeysMissing,
                        'message': 'Public keys are missing'
                      },
                      {
                        'condition': _isYourPubKeyMissing,
                        'message': 'Your public key is not included'
                      },
                    ]),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add_alt_sharp,
                      size: 40, color: Colors.green),
                  onPressed: _showAddPublicKeyDialog,
                ),
                const SizedBox(width: 10),
                if (publicKeysWithAlias.isNotEmpty)
                  SizedBox(
                    width: 100, // Set your desired width
                    child: TextFormField(
                      onChanged: (value) {
                        setState(() {
                          if (int.tryParse(value) != null &&
                              int.parse(value) > publicKeysWithAlias.length) {
                            // If the entered value exceeds the max, reset it to the max
                            _thresholdController.text =
                                publicKeysWithAlias.length.toString();
                            _thresholdController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: _thresholdController.text.length),
                            );
                          } else {
                            threshold = _thresholdController.text;
                          }
                        });
                      },
                      controller: _thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: CustomTextFieldStyles.textFieldDecoration(
                        context: context,
                        labelText: 'Threshold',
                        hintText: 'Thresh',
                        borderColor:
                            _isThresholdMissing ? Colors.red : Colors.green,
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (publicKeysWithAlias.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: publicKeysWithAlias.map((key) {
                  return Dismissible(
                    key: ValueKey(key['publicKey']), // Unique key for each item
                    direction:
                        DismissDirection.horizontal, // Allow swipe to the left
                    onDismissed: (direction) {
                      setState(() {
                        print(key['publicKey']);

                        publicKeysWithAlias.remove(key); // Remove the key

                        for (var condition in timelockConditions) {
                          condition['pubkeys'].removeWhere((pubKeyEntry) {
                            return pubKeyEntry['publicKey'] == key['publicKey'];
                          });
                        }

                        // Remove the entire condition if no pubkeys remain in it
                        timelockConditions.removeWhere(
                            (condition) => condition['pubkeys'].isEmpty);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${key['alias']} removed'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(
                            (0.8 * 255).toInt()), // Red background for delete
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Icon(
                        Icons.delete, // Delete icon
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        _showAddPublicKeyDialog(key: key, isUpdating: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha((0.2 * 255).toInt()),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              key['alias']!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const Divider(height: 40),

            // Section 3: Enter Timelock Conditions
            if (publicKeysWithAlias.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. Enter Timelock Conditions',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: const Icon(Icons.lock_clock,
                        size: 40, color: Colors.green),
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
                        List<dynamic> aliases = (condition['pubkeys'] is String
                                ? jsonDecode(condition['pubkeys'])
                                : condition['pubkeys'])
                            .map((pubkeyEntry) {
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
                                entry['publicKey']!.trim().substring(
                                    0, entry['publicKey']!.length - 3) ==
                                publicKey
                                    .trim()
                                    .substring(0, publicKey.length - 3),
                            orElse: () => {'alias': 'Unknown'},
                          )['alias'];
                        }).toList();

                        // print('aliases: $aliases');

                        return Dismissible(
                          key: ValueKey(condition),
                          direction: DismissDirection.horizontal,
                          onDismissed: (direction) {
                            setState(() {
                              print(condition);
                              timelockConditions.remove(condition);
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Timelock condition (${condition['threshold']}) removed'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha((0.8 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha((0.8 * 255).toInt()),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _showAddTimelockDialog(
                                  condition: condition, isUpdating: true);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color:
                                    Colors.green.withAlpha((0.2 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: Colors.green),
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
                          ),
                        );
                      }).toList(),
                    ),
                  const Divider(height: 40),
                ],
              ),

            // Section 4: Create Descriptor
            if (publicKeysWithAlias.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    foregroundColor:
                        Colors.black, // Bitcoin green color for text
                    icon: Icons.create, // Icon you want to use
                    iconColor: Colors.green, // Color for the icon
                    label: 'Create Descriptor',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAddPublicKeyDialog({Map<String, String>? key, isUpdating = false}) {
    final TextEditingController publicKeyController = TextEditingController();
    final TextEditingController aliasController = TextEditingController();

    String? currentPublicKey;
    String? currentAlias;
    String? errorMessage;

    if (isUpdating && key != null) {
      currentPublicKey = key['publicKey'];
      currentAlias = key['alias'];
      publicKeyController.text = currentPublicKey ?? '';
      aliasController.text = currentAlias ?? '';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black, // Set the background color
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16.0), // Optional rounded corners
              ),
              title: Text(isUpdating ? 'Edit Public Key' : 'Add Public Key',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: publicKeyController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: 'Enter Public Key',
                      hintText: 'Enter Public Key',
                    ),
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
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final String newPublicKey = publicKeyController.text.trim();
                    final String newAlias = aliasController.text.trim();

                    if (newPublicKey.isEmpty || newAlias.isEmpty) {
                      setDialogState(() {
                        errorMessage = 'Both fields are required.';
                      });
                      return;
                    }

                    // Exclude the current key when checking for duplicates
                    bool publicKeyExists = publicKeysWithAlias.any((entry) =>
                        entry['publicKey']?.toLowerCase() ==
                            newPublicKey.toLowerCase() &&
                        entry['publicKey']?.toLowerCase() !=
                            currentPublicKey?.toLowerCase());

                    bool aliasExists = publicKeysWithAlias.any((entry) =>
                        entry['alias']?.toLowerCase() ==
                            newAlias.toLowerCase() &&
                        entry['alias']?.toLowerCase() !=
                            currentAlias?.toLowerCase());

                    if (publicKeyExists) {
                      setDialogState(() {
                        errorMessage = 'This public key already exists.';
                      });
                    } else if (aliasExists) {
                      setDialogState(() {
                        errorMessage = 'This alias already exists.';
                      });
                    } else {
                      if (isUpdating) {
                        setState(() {
                          key!['publicKey'] = newPublicKey;
                          key['alias'] = newAlias;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Multisig updated successfully'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      } else {
                        setState(() {
                          publicKeysWithAlias.add({
                            'publicKey': newPublicKey,
                            'alias': newAlias,
                          });
                        });
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                  child: Text(isUpdating ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTimelockDialog(
      {Map<String, dynamic>? condition, isUpdating = false}) {
    final TextEditingController thresholdController = TextEditingController();
    final TextEditingController olderController = TextEditingController();
    List<Map<String, dynamic>> selectedPubKeys =
        []; // Store both pubkey and alias

    String? currentThreshold;
    String? currentOlder;
    List<Map<String, dynamic>> updatedPubkeys = [];

    if (isUpdating && condition != null) {
      currentThreshold = condition['threshold']?.toString();
      currentOlder = condition['older']?.toString();
      thresholdController.text = currentThreshold ?? '';
      olderController.text = currentOlder ?? '';

      // Ensure pubkeys is correctly extracted as a list
      if (condition['pubkeys'] is String) {
        // Decode JSON string if needed
        updatedPubkeys =
            List<Map<String, dynamic>>.from(jsonDecode(condition['pubkeys']));
      } else if (condition['pubkeys'] is List) {
        updatedPubkeys =
            List<Map<String, dynamic>>.from(condition['pubkeys'] as List);
      }

      selectedPubKeys = updatedPubkeys.map((entry) {
        return {
          'publicKey': entry['publicKey']!,
          'alias': entry['alias']!,
        };
      }).toList();
    }

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
              title: Text(
                isUpdating
                    ? 'Edit Timelock Condition'
                    : 'Add Timelock Condition',
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                // print(selectedPubKeys);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.green
                                        .withAlpha((0.8 * 255).toInt())
                                    : Colors.green
                                        .withAlpha((0.2 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Text(
                                key['alias']!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 10),
                    if (selectedPubKeys.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: thresholdController,
                            onChanged: (value) {
                              setDialogState(() {
                                if (int.tryParse(value) != null &&
                                    int.parse(value) > selectedPubKeys.length) {
                                  // If the entered value exceeds the max, reset it to the max
                                  thresholdController.text =
                                      selectedPubKeys.length.toString();
                                  thresholdController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset:
                                            thresholdController.text.length),
                                  );
                                } else {
                                  thresholdController.text = value;
                                }
                              });
                            },
                            decoration:
                                CustomTextFieldStyles.textFieldDecoration(
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
                            decoration:
                                CustomTextFieldStyles.textFieldDecoration(
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
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (thresholdController.text.isNotEmpty &&
                        olderController.text.isNotEmpty &&
                        selectedPubKeys.isNotEmpty) {
                      // Convert input to integer for accurate comparison
                      int newOlder = int.tryParse(olderController.text) ?? -1;
                      final newPubkeys = selectedPubKeys;
                      final String newThreshold =
                          thresholdController.text.trim();

                      // Check if older value already exists in the list
                      bool isDuplicateOlder = timelockConditions.any(
                        (existingCondition) =>
                            int.tryParse(
                                    existingCondition['older'].toString()) ==
                                newOlder &&
                            existingCondition['older'].toString() !=
                                currentOlder,
                      );

                      if (isDuplicateOlder) {
                        // Show an error message instead of adding a duplicate
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Error: This Older value already exists!'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        if (isUpdating) {
                          setState(() {
                            // Update the condition with new values
                            condition!['threshold'] = newThreshold;
                            condition['older'] = newOlder.toString();
                            condition['pubkeys'] = jsonEncode(newPubkeys);
                          });

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Timelock condition updated successfully',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        } else {
                          setState(() {
                            // Add the new timelock condition to the list
                            timelockConditions.add({
                              'threshold': thresholdController.text,
                              'older': olderController.text,
                              'pubkeys': jsonEncode(newPubkeys),
                            });
                            print(timelockConditions);
                          });

                          // Close the dialog after adding the condition
                          Navigator.pop(context);
                        }
                      }
                    } else {
                      print('Validation Failed: One or more fields are empty');
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
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
            (condition['pubkeys'] is String
                    ? List<Map<String, dynamic>>.from(
                        jsonDecode(condition['pubkeys']))
                    : List<Map<String, dynamic>>.from(
                        condition['pubkeys'] as List<dynamic>))
                .map((key) {
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
    // Validate inputs
    _validateInputs();

    // If any section is missing, stop further processing
    if (_isDescriptorNameMissing ||
        _isThresholdMissing ||
        _arePublicKeysMissing ||
        _isYourPubKeyMissing) {
      return;
    }

    // Extract only the public keys from the list of public keys with alias
    List<String> extractedPublicKeys = publicKeysWithAlias
        .map((entry) => entry['publicKey']!)
        .toList()
      ..sort(); // Sort alphabetically

    // Format the public keys for the descriptor
    String formattedKeys =
        extractedPublicKeys.toString().replaceAll(RegExp(r'^\[|\]$'), '');

    String multi = 'multi($threshold,$formattedKeys)';
    String finalDescriptor;

    // Handle any potential duplicates in timelock public keys
    _handleTimelocks();

    if (timelockConditions.isNotEmpty) {
      timelockConditions.sort(
          (a, b) => int.parse(a['older']).compareTo(int.parse(b['older'])));
      // Build timelock condition string
      List<String> formattedTimelocks = timelockConditions.map((condition) {
        String threshold = condition['threshold'];
        String older = condition['older'];

        // Extract only the publicKey values from pubkeys
        List<String> pubkeys = (condition['pubkeys'] as List)
            .map((key) => key['publicKey'] as String)
            .toList()
          ..sort(); // Sort alphabetically

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

    _walletService.printInChunks(finalDescriptor);

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
                        icon: const Icon(Icons.copy, color: Colors.green),
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
                        border: Border.all(color: Colors.green),
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
                        border: Border.all(color: Colors.green),
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
                  'descriptorName': _descriptorName,
                });

                // Request storage permission (required for Android 11 and below)
                if (await Permission.storage.request().isGranted) {
                  // Get default Downloads directory
                  final directory = Directory('/storage/emulated/0/Download');
                  if (!await directory.exists()) {
                    await directory.create(recursive: true);
                  }

                  String fileName = '$_descriptorName.json';
                  String filePath = '${directory.path}/$fileName';
                  File file = File(filePath);

                  // Check if the file already exists
                  if (await file.exists()) {
                    final shouldProceed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Colors
                                .grey[900], // Dark background for the dialog
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  20.0), // Rounded corners
                            ),
                            title: const Text('File Already Exists'),
                            content: const Text(
                              ' A file with the same name already exists. Do you want to save it anyway?',
                            ),
                            actions: [
                              InkwellButton(
                                onTap: () {
                                  Navigator.of(context).pop(false);
                                },
                                label: 'Cancel',
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                icon: Icons.cancel_rounded,
                                iconColor: Colors.redAccent,
                              ),
                              InkwellButton(
                                onTap: () {
                                  Navigator.of(context).pop(true);
                                },
                                label: 'Yes',
                                backgroundColor: Colors.white,
                                textColor: Colors.black,
                                icon: Icons.check_circle,
                                iconColor: Colors.greenAccent,
                              ),
                            ],
                          );
                        });

                    // If the user chooses not to proceed, exit
                    if (!shouldProceed!) {
                      return;
                    }

                    // Increment the file name index until a unique file name is found
                    int index = 1;
                    while (await file.exists()) {
                      fileName = '$_descriptorName($index).json';
                      filePath = '${directory.path}/$fileName';
                      file = File(filePath);
                      index++;
                    }
                  }

                  // Write JSON data to the file
                  await file.writeAsString(data);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('File saved to ${directory.path}/$fileName'),
                    ),
                  );
                } else {
                  // Permission denied
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Storage permission is required to save the file'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Download Descriptor'),
            ),
            TextButton(
              onPressed: () {
                // print('_mnemonic: $_mnemonic');

                _navigateToSharedWallet();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Navigate to Wallet'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
