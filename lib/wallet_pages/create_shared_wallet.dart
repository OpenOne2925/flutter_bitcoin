import 'dart:convert';
import 'dart:io';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/exceptions/validation_result.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/utilities_service.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:provider/provider.dart';

class CreateSharedWallet extends StatefulWidget {
  const CreateSharedWallet({super.key});

  @override
  CreateSharedWalletState createState() => CreateSharedWalletState();
}

class CreateSharedWalletState extends State<CreateSharedWallet> {
  late final WalletService _walletService;

  final TextEditingController _thresholdController = TextEditingController();
  List<TextEditingController> additionalPublicKeyControllers = [
    TextEditingController()
  ];
  final TextEditingController _descriptorNameController =
      TextEditingController();

  String? threshold;
  List<Map<String, String>> publicKeysWithAlias = [];
  List<Map<String, String>> publicKeysWithAliasMultisig = [];

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

  final GlobalKey<BaseScaffoldState> baseScaffoldKey =
      GlobalKey<BaseScaffoldState>();

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

    _walletService =
        WalletService(Provider.of<SettingsProvider>(context, listen: false));

    _generatePublicKey(isGenerating: false);
  }

  @override
  void dispose() {
    super.dispose();
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

      // TODO: "m/84h/1h/0h/0"

      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      final (_, receivingPublicKey) = await _walletService.deriveDescriptorKeys(
        hardenedDerivationPath,
        receivingDerivationPath,
        mnemonic,
      );

      print(receivingPublicKey
          .toString()
          .substring(0, receivingPublicKey.toString().length - 2));

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
        descriptor,
        initialPubKey.toString(),
        context,
      );

      print(result.toString());

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
    print(isValid);
    setState(() {
      _status = 'Loading';
    });

    if (isValid) {
      setState(() {
        _status = 'Success';
      });

      _walletService.printInChunks(_finalDescriptor.toString());

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
      // print('Key: $key');
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
    List<Map<String, String>> selectedPubKeys = [];

    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.translate('create_shared_wallet'),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      key: baseScaffoldKey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section: Descriptor Name
            Text(
              AppLocalizations.of(context)!.translate('descriptor_name'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _isDescriptorNameMissing
                    ? AppColors.error(context)
                    : AppColors.text(context),
              ),
            ),
            // Error Message
            if (_isDescriptorNameMissing || _isDuplicateDescriptor)
              Text(
                _generateSectionErrorMessage([
                  {
                    'condition': _isDescriptorNameMissing,
                    'message': AppLocalizations.of(context)!
                        .translate('descriptor_name_missing')
                  },
                  {
                    'condition': _isDuplicateDescriptor,
                    'message': AppLocalizations.of(context)!
                        .translate('descriptor_name_exists')
                  },
                ]),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: AppColors.error(context),
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptorNameController,
              onChanged: (value) {
                setState(() {
                  _descriptorName = _descriptorNameController.text.trim();

                  _isDuplicateDescriptor =
                      _isDuplicateDescriptorName(_descriptorName);
                });
              },
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText: AppLocalizations.of(context)!
                    .translate('enter_descriptor_name'),
                hintText: 'E.g., MySharedWallet',
                borderColor: _isDescriptorNameMissing
                    ? AppColors.error(context)
                    : AppColors.text(context),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            // Section 1: Generate Public Key
            Text(
              '1. ${AppLocalizations.of(context)!.translate('generate_public_key')}',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.text(context)),
            ),
            const SizedBox(height: 10),

            GestureDetector(
              onLongPress: () {
                final BaseScaffoldState? baseScaffoldState =
                    baseScaffoldKey.currentState;

                if (baseScaffoldState != null) {
                  baseScaffoldState.updateAssistantMessage(
                      context, 'assistant_generate_pub_key');
                }
              },
              child: CustomButton(
                onPressed: _generatePublicKey,
                backgroundColor: AppColors.background(context),
                foregroundColor: AppColors.gradient(context),
                icon: Icons.vpn_key,
                iconColor: AppColors.text(context),
                label: AppLocalizations.of(context)!
                    .translate('generate_public_key'),
                padding: 16.0,
                iconSize: 24.0,
              ),
            ),
            if (_publicKey != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${AppLocalizations.of(context)!.translate('pub_key')}: $_publicKey',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.text(context),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      color: AppColors.icon(context),
                    ),
                    tooltip: AppLocalizations.of(context)!
                        .translate('copy_to_clipboard'),
                    onPressed: () {
                      UtilitiesService.copyToClipboard(
                        context: context,
                        text: _publicKey.toString(),
                        messageKey: 'pub_key_clipboard',
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
                  '2. ${AppLocalizations.of(context)!.translate('enter_public_keys_multisig')}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: (_isThresholdMissing ||
                            _arePublicKeysMissing ||
                            _isYourPubKeyMissing)
                        ? AppColors.error(context)
                        : AppColors.text(context),
                  ),
                ),

                const SizedBox(height: 8),

                // Error Message
                if (_isThresholdMissing ||
                    _arePublicKeysMissing ||
                    _isYourPubKeyMissing)
                  Text(
                    _generateSectionErrorMessage([
                      {
                        'condition': _isThresholdMissing,
                        'message': AppLocalizations.of(context)!
                            .translate('threshold_missing')
                      },
                      {
                        'condition': _arePublicKeysMissing,
                        'message': AppLocalizations.of(context)!
                            .translate('public_keys_missing')
                      },
                      {
                        'condition': _isYourPubKeyMissing,
                        'message': AppLocalizations.of(context)!
                            .translate('your_public_key_missing')
                      },
                    ]),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: AppColors.error(context),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.person_add_alt_sharp,
                    size: 40,
                    color: AppColors.icon(context),
                  ),
                  onPressed: _showAddPublicKeyDialog,
                ),
                const SizedBox(width: 10),
                if (publicKeysWithAlias.isNotEmpty)
                  Row(
                    children: [
                      SizedBox(
                        width: 100, // Set your desired width
                        child: TextFormField(
                          onChanged: (value) {
                            setState(() {
                              if (int.tryParse(value) != null &&
                                  int.parse(value) >
                                      publicKeysWithAliasMultisig.length) {
                                // If the entered value exceeds the max, reset it to the max
                                _thresholdController.text =
                                    publicKeysWithAliasMultisig.length
                                        .toString();
                                _thresholdController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _thresholdController.text.length),
                                );
                                threshold = _thresholdController.text;
                              } else {
                                threshold = _thresholdController.text;
                              }
                            });
                          },
                          controller: _thresholdController,
                          keyboardType: TextInputType.number,
                          decoration: CustomTextFieldStyles.textFieldDecoration(
                            context: context,
                            labelText: AppLocalizations.of(context)!
                                .translate('threshold'),
                            hintText: AppLocalizations.of(context)!
                                .translate('threshold'),
                            borderColor: _isThresholdMissing
                                ? AppColors.error(context)
                                : AppColors.background(context),
                          ),
                          style: TextStyle(
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final BaseScaffoldState? baseScaffoldState =
                              baseScaffoldKey.currentState;

                          if (baseScaffoldState != null) {
                            baseScaffoldState.updateAssistantMessage(
                                context, 'assistant_threshold');
                          }
                        },
                        icon: Icon(
                          Icons.help,
                          color: AppColors.icon(context),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (publicKeysWithAlias.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: publicKeysWithAlias.map((key) {
                  selectedPubKeys = publicKeysWithAliasMultisig;

                  bool isSelected = selectedPubKeys.any((selectedKey) =>
                      selectedKey['publicKey'] == key['publicKey']);

                  return Dismissible(
                    key: ValueKey(key['publicKey']), // Unique key for each item
                    direction: DismissDirection
                        .horizontal, // Allow swipe to the left and righty
                    onDismissed: (direction) {
                      setState(() {
                        // print(key['publicKey']);

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

                      SnackBarHelper.showError(
                        context,
                        message:
                            "${key['alias']} ${AppLocalizations.of(context)!.translate('alias_removed')}",
                      );
                    },
                    background: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.error(context),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(
                        Icons.delete,
                        color: AppColors.text(context),
                        size: 24,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedPubKeys.removeWhere((selectedKey) =>
                                selectedKey['publicKey'] == key['publicKey']);

                            // Also remove from the multisig list
                            publicKeysWithAliasMultisig.removeWhere((item) =>
                                item['publicKey'] == key['publicKey']);
                          } else {
                            if (!selectedPubKeys.any((selectedKey) =>
                                selectedKey['publicKey'] == key['publicKey'])) {
                              selectedPubKeys.add({
                                'publicKey': key['publicKey']!,
                                'alias': key['alias']!,
                              });
                            }

                            if (!publicKeysWithAliasMultisig.any((item) =>
                                item['publicKey'] == key['publicKey'])) {
                              publicKeysWithAliasMultisig.add({
                                'publicKey': key['publicKey']!,
                                'alias': key['alias']!,
                              });
                            }
                          }
                        });
                        // print(isSelected);

                        print('publicKeysWithAlias: $publicKeysWithAlias');

                        print(
                            'publicKeysWithAliasMultisig: $publicKeysWithAliasMultisig');
                        print('selectedPubKeys: $selectedPubKeys');
                      },
                      onLongPress: () {
                        _showAddPublicKeyDialog(key: key, isUpdating: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.background(context)
                                  .withAlpha((0.8 * 255).toInt())
                              : AppColors.background(context)
                                  .withAlpha((0.2 * 255).toInt()),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: AppColors.primary(context)),
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
                    '3. ${AppLocalizations.of(context)!.translate('enter_timelock_conditions')}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.text(context)),
                  ),
                  const SizedBox(height: 10),
                  IconButton(
                    icon: Icon(
                      Icons.lock_clock,
                      size: 40,
                      color: AppColors.icon(context),
                    ),
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
                              // print(condition);
                              timelockConditions.remove(condition);
                            });

                            SnackBarHelper.show(
                              context,
                              message: AppLocalizations.of(context)!
                                  .translate('timelock_condition_removed')
                                  .replaceAll('{x}', condition['threshold']),
                              color: AppColors.error(context),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16.0),
                            decoration: BoxDecoration(
                              color: AppColors.error(context),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: AppColors.text(context),
                              size: 24,
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16.0),
                            decoration: BoxDecoration(
                              color: AppColors.error(context),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Icon(
                              Icons.delete,
                              color: AppColors.text(context),
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
                                color: AppColors.primary(context)
                                    .withAlpha((0.2 * 255).toInt()),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                    color: AppColors.primary(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('threshold')}: ${condition['threshold']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('older')}: ${condition['older']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    '${AppLocalizations.of(context)!.translate('pub_keys')}: ${aliases.join(', ')}',
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
                  Row(
                    children: [
                      Text(
                        '4. ${AppLocalizations.of(context)!.translate('create_descriptor')}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.text(context)),
                      ),
                      IconButton(
                        onPressed: () {
                          final BaseScaffoldState? baseScaffoldState =
                              baseScaffoldKey.currentState;

                          if (baseScaffoldState != null) {
                            baseScaffoldState.updateAssistantMessage(
                                context, 'assistant_create_descriptor');
                          }
                        },
                        icon: Icon(
                          Icons.help,
                          color: AppColors.icon(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    onPressed: () => _createDescriptor(),
                    backgroundColor: AppColors.background(context),
                    foregroundColor: AppColors.text(context),
                    icon: Icons.create,
                    iconColor: AppColors.gradient(context),
                    label: AppLocalizations.of(context)!
                        .translate('create_descriptor'),
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

    final rootContext = context;

    DialogHelper.buildCustomStatefulDialog(
      context: rootContext,
      titleKey: isUpdating ? 'edit_public_key' : 'add_public_key',
      showAssistant: true,
      assistantMessages: [
        'assistant_add_pub_key_tip1',
        'assistant_add_pub_key_tip2',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: publicKeyController,
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText: AppLocalizations.of(rootContext)!
                    .translate('enter_pub_key'),
                hintText: AppLocalizations.of(rootContext)!
                    .translate('enter_pub_key'),
                borderColor: AppColors.background(context),
              ),
              style: TextStyle(
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: aliasController,
              decoration: CustomTextFieldStyles.textFieldDecoration(
                context: context,
                labelText:
                    AppLocalizations.of(rootContext)!.translate('enter_alias'),
                hintText:
                    AppLocalizations.of(rootContext)!.translate('enter_alias'),
                borderColor: AppColors.background(context),
              ),
              style: TextStyle(
                color: AppColors.text(context),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                style: TextStyle(
                  color: AppColors.error(context),
                ),
              ),
            ],
          ],
        );
      },
      actionsBuilder: (setDialogState) {
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkwellButton(
                onTap: () {
                  final String newPublicKey = publicKeyController.text.trim();
                  final String newAlias = aliasController.text.trim();

                  if (newPublicKey.isEmpty || newAlias.isEmpty) {
                    setDialogState(() {
                      errorMessage = AppLocalizations.of(rootContext)!
                          .translate('both_fields_required');
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
                      entry['alias']?.toLowerCase() == newAlias.toLowerCase() &&
                      entry['alias']?.toLowerCase() !=
                          currentAlias?.toLowerCase());

                  if (publicKeyExists) {
                    setDialogState(() {
                      errorMessage = AppLocalizations.of(rootContext)!
                          .translate('pub_key_exists');
                    });
                  } else if (aliasExists) {
                    setDialogState(() {
                      errorMessage = AppLocalizations.of(rootContext)!
                          .translate('alias_exists');
                    });
                  } else {
                    if (isUpdating) {
                      setState(() {
                        key!['publicKey'] = newPublicKey;
                        key['alias'] = newAlias;
                      });
                      Navigator.of(context, rootNavigator: true).pop();

                      SnackBarHelper.show(
                        rootContext,
                        message: AppLocalizations.of(rootContext)!
                            .translate('multisig_updated'),
                      );
                    } else {
                      setState(() {
                        publicKeysWithAlias.add({
                          'publicKey': newPublicKey,
                          'alias': newAlias,
                        });
                      });
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  }
                },
                label: AppLocalizations.of(rootContext)!
                    .translate(isUpdating ? 'save' : 'add'),
                backgroundColor: AppColors.background(context),
                textColor: AppColors.text(context),
                icon: isUpdating ? Icons.save : Icons.add_task,
                iconColor: AppColors.gradient(context),
              ),
            ],
          ),
        ];
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

    final rootContext = context;

    DialogHelper.buildCustomStatefulDialog(
      context: rootContext,
      titleKey: isUpdating ? 'edit_timelock' : 'add_timelock',
      showAssistant: true,
      assistantMessages: [
        'assistant_add_timelock_tip1',
        'assistant_add_timelock_tip2',
        'assistant_add_timelock_tip3',
      ],
      contentBuilder: (setDialogState, updateAssistantMessage) {
        return Column(
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
                              selectedKey['publicKey'] == key['publicKey']);
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
                            ? AppColors.background(context)
                                .withAlpha((0.8 * 255).toInt())
                            : AppColors.background(context)
                                .withAlpha((0.2 * 255).toInt()),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: AppColors.primary(context),
                        ),
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
                              offset: thresholdController.text.length,
                            ),
                          );
                        } else {
                          thresholdController.text = value;
                        }
                      });
                    },
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('threshold'),
                      hintText: AppLocalizations.of(rootContext)!
                          .translate('threshold'),
                      borderColor: AppColors.background(context),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: olderController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: AppLocalizations.of(rootContext)!
                          .translate('enter_older'),
                      hintText:
                          AppLocalizations.of(rootContext)!.translate('older'),
                      borderColor: AppColors.background(context),
                    ),
                    style: TextStyle(
                      color: AppColors.text(context),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
          ],
        );
      },
      actionsBuilder: (setDialogState) {
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkwellButton(
                onTap: () {
                  if (thresholdController.text.isNotEmpty &&
                      olderController.text.isNotEmpty &&
                      selectedPubKeys.isNotEmpty) {
                    // Convert input to integer for accurate comparison
                    int newOlder = int.tryParse(olderController.text) ?? -1;
                    final newPubkeys = selectedPubKeys;
                    final String newThreshold = thresholdController.text.trim();

                    // Check if older value already exists in the list
                    bool isDuplicateOlder = timelockConditions.any(
                      (existingCondition) =>
                          int.tryParse(existingCondition['older'].toString()) ==
                              newOlder &&
                          existingCondition['older'].toString() != currentOlder,
                    );

                    if (isDuplicateOlder) {
                      SnackBarHelper.show(
                        rootContext,
                        message: AppLocalizations.of(rootContext)!
                            .translate('error_older'),
                        color: AppColors.error(rootContext),
                      );
                    } else {
                      if (isUpdating) {
                        setState(() {
                          // Update the condition with new values
                          condition!['threshold'] = newThreshold;
                          condition['older'] = newOlder.toString();
                          condition['pubkeys'] = jsonEncode(newPubkeys);
                        });

                        Navigator.of(context, rootNavigator: true).pop();

                        SnackBarHelper.show(
                          rootContext,
                          message: AppLocalizations.of(rootContext)!
                              .translate('timelock_updated'),
                        );
                      } else {
                        setState(() {
                          // Add the new timelock condition to the list
                          timelockConditions.add({
                            'threshold': thresholdController.text,
                            'older': olderController.text,
                            'pubkeys': jsonEncode(newPubkeys),
                          });
                          // print(timelockConditions);
                        });

                        // Close the dialog after adding the condition
                        Navigator.of(context, rootNavigator: true).pop();
                      }
                    }
                  } else {
                    // print('Validation Failed: One or more fields are empty');
                    throw ('Validation Failed: One or more fields are empty');
                  }
                },
                label: AppLocalizations.of(rootContext)!
                    .translate(isUpdating ? 'save' : 'add'),
                backgroundColor: AppColors.background(context),
                textColor: AppColors.text(context),
                icon: isUpdating ? Icons.save : Icons.add_task,
                iconColor: AppColors.gradient(context),
              ),
            ],
          ),
        ];
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
    List<String> extractedPublicKeys = publicKeysWithAliasMultisig
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

    // _walletService.printInChunks(finalDescriptor);

    setState(() {
      _finalDescriptor = finalDescriptor.replaceAll(' ', '');
    });

    _createDescriptorDialog(context);
  }

  void _createDescriptorDialog(BuildContext context) {
    final rootContext = context;

    DialogHelper.buildCustomDialog(
      context: context,
      titleKey: 'descriptor_created',
      titleParams: {'x': _descriptorName},
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display descriptor
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.container(context),
              border: Border.all(
                color: AppColors.background(context),
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _finalDescriptor,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: AppColors.primary(context)),
                  tooltip: AppLocalizations.of(rootContext)!
                      .translate('copy_to_clipboard'),
                  onPressed: () {
                    UtilitiesService.copyToClipboard(
                      context: rootContext,
                      text: _finalDescriptor,
                      messageKey: 'descriptor_clipboard',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Display conditions
          Text(
            AppLocalizations.of(rootContext)!.translate('conditions'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.cardTitle(context),
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
                  border: Border.all(color: AppColors.primary(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context),
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('threshold')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${condition['threshold']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text(context),
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('older')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${condition['older']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('aliases')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: aliases.join(', '),
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
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
            AppLocalizations.of(rootContext)!.translate('pub_keys'),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.cardTitle(context),
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
                  border: Border.all(color: AppColors.primary(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('pub_key')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${key['publicKey']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${AppLocalizations.of(rootContext)!.translate('alias')}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.cardTitle(context),
                            ),
                          ),
                          TextSpan(
                            text: '${key['alias']}',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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
                final shouldProceed =
                    (await DialogHelper.buildCustomDialog<bool>(
                          context: rootContext,
                          showCloseButton: false,
                          titleKey: 'file_already_exists',
                          content: Text(
                            AppLocalizations.of(rootContext)!
                                .translate('file_save_prompt'),
                            style: TextStyle(
                              color: AppColors.text(context),
                            ),
                          ),
                          actions: [
                            InkwellButton(
                              onTap: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop(false);
                              },
                              label: AppLocalizations.of(rootContext)!
                                  .translate('no'),
                              backgroundColor: Colors.white,
                              textColor: Colors.black,
                              icon: Icons.cancel_rounded,
                              iconColor: Colors.redAccent,
                            ),
                            InkwellButton(
                              onTap: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop(true);
                              },
                              label: AppLocalizations.of(rootContext)!
                                  .translate('yes'),
                              backgroundColor: Colors.white,
                              textColor: Colors.black,
                              icon: Icons.check_circle,
                              iconColor: AppColors.accent(context),
                            ),
                          ],
                        )) ??
                        false;

                // If the user chooses not to proceed, exit
                if (!shouldProceed) {
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

              SnackBarHelper.show(
                rootContext,
                message:
                    '${AppLocalizations.of(rootContext)!.translate('file_saved')} ${directory.path}/$fileName',
              );
            } else {
              SnackBarHelper.showError(
                rootContext,
                message: AppLocalizations.of(rootContext)!
                    .translate('storage_permission_needed'),
              );
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary(context),
          ),
          child: Text(
            AppLocalizations.of(rootContext)!.translate('download_descriptor'),
            style: TextStyle(
              color: AppColors.background(context),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            // print('_mnemonic: $_mnemonic');
            Navigator.of(context, rootNavigator: true).pop();

            _navigateToSharedWallet();
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary(context),
          ),
          child: Text(
            AppLocalizations.of(rootContext)!.translate('navigate_wallet'),
            style: TextStyle(
              color: AppColors.background(context),
            ),
          ),
        ),
      ],
      actionsLayout: Axis.vertical,
    );
  }
}
