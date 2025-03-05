import 'dart:convert';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/inkwell_button.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:flutter_wallet/widget_helpers/assistant_widget.dart';
import 'package:flutter_wallet/widget_helpers/dialog_helper.dart';
import 'package:flutter_wallet/widget_helpers/snackbar_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class BaseScaffold extends StatefulWidget {
  final Widget body;
  final Text title;
  final bool isTestnet; // Add a flag to indicate Testnet or Mainnet
  final Future<void> Function()? onRefresh;
  final bool showAssistantButton;
  final bool showDrawer;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.isTestnet = true, // Default to Mainnet if not specified
    this.onRefresh,
    this.showAssistantButton = true,
    this.showDrawer = true,
  });

  @override
  BaseScaffoldState createState() => BaseScaffoldState();
}

class BaseScaffoldState extends State<BaseScaffold> {
  Box<dynamic>? _descriptorBox;
  Map<String, Future<DescriptorPublicKey?>> pubKeyFutures = {};

  String _version = '';

  final walletService = WalletService();
  DescriptorPublicKey? pubKey;

  bool _showAssistant = false;

  String _assistantMessage = "";
  List<String> _assistantMessages = [];

  int _assistantMessageIndex = 0;

  Offset _assistantPosition = Offset(50, 500);

  final GlobalKey<AssistantWidgetState> _assistantKey =
      GlobalKey(); // Track assistant widget state

  @override
  void initState() {
    super.initState();

    _descriptorBox = Hive.box<dynamic>('descriptorBox');
    // printDescriptorBoxContents();
    _getVersion();
    // _updateAssistantMessages();
  }

  void _toggleAssistant() {
    setState(() {
      _showAssistant = !_showAssistant;
    });
    String initialMessage = _getAssistantMessageForRoute();
    _assistantMessages = _getAssistantMessagesForRoute();

    // Show initial message when turning on
    if (_showAssistant) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_assistantKey.currentState != null) {
          _assistantKey.currentState!.updateMessage(initialMessage);
        }
      });
    }
  }

  void _nextAssistantMessage() {
    setState(() {
      _assistantMessageIndex =
          (_assistantMessageIndex + 1) % _assistantMessages.length;
    });

    if (_assistantKey.currentState != null) {
      _assistantKey.currentState!
          .updateMessage(_assistantMessages[_assistantMessageIndex]);
    }
  }

  String _getAssistantMessageForRoute() {
    String? currentRoute = ModalRoute.of(context)?.settings.name;
    final localization = AppLocalizations.of(context)!;

    switch (currentRoute) {
      case '/wallet_page':
        return localization.translate("assistant_welcome");
      case '/ca_wallet_page':
        return localization.translate("assistant_ca_wallet_page");
      case '/pin_setup_page':
        return localization.translate("assistant_pin_setup_page");
      case '/pin_verification_page':
        return localization.translate("assistant_pin_verification_page");
      case '/shared_wallet':
        return localization.translate("assistant_shared_page");
      case '/create_shared':
        return localization.translate("assistant_create_shared");
      case '/import_shared':
        return localization.translate("assistant_import_shared");
      case '/settings':
        return localization.translate("assistant_settings");

      // Default will be used for the ShareWalletPages since they have multiple parameters required and because of that, don't have a route
      default:
        return localization.translate(
            "assistant_shared_wallet"); // "How can I assist you today?"
    }
  }

  List<String> _getAssistantMessagesForRoute() {
    String? currentRoute = ModalRoute.of(context)?.settings.name;
    final localization = AppLocalizations.of(context)!;

    switch (currentRoute) {
      case '/wallet_page':
        return [
          localization.translate("assistant_wallet_page_tip1"),
          localization.translate("assistant_wallet_page_tip2"),
          localization.translate("assistant_wallet_page_tip3"),
        ];
      case '/ca_wallet_page':
        return [
          localization.translate("assistant_ca_wallet_page_tip1"),
          localization.translate("assistant_ca_wallet_page_tip2"),
        ];
      case '/pin_setup_page':
        return [
          localization.translate("assistant_pin_setup_page_tip1"),
          localization.translate("assistant_pin_setup_page_tip2"),
        ];
      case '/pin_verification_page':
        return [
          localization.translate("assistant_pin_verify_page_tip1"),
          // localization.translate("assistant_pin_verify_page_tip2"),
        ];
      case '/create_shared':
        return [
          localization.translate("assistant_create_shared_tip1"),
          // localization.translate("assistant_create_shared_tip2"),
          // localization.translate("assistant_create_shared_tip3"),
        ];
      case '/import_shared':
        return [
          localization.translate("assistant_import_shared_tip1"),
          localization.translate("assistant_import_shared_tip2"),
          localization.translate("assistant_import_shared_tip3"),
        ];
      // Default will be used for the ShareWalletPages,
      // since they have multiple parameters required and because of that, don't have a route
      default:
        return [
          localization.translate("assistant_default_tip1"),
          localization.translate("assistant_default_tip2"),
        ];
    }
  }

  void updateAssistantMessage(BuildContext context, String message) {
    setState(() {
      _assistantMessage = message;
    });

    // Directly update AssistantWidget state using the GlobalKey
    if (_assistantKey.currentState != null) {
      _assistantKey.currentState!.updateMessage(message);
    }
  }

  void updateAssistantPosition(Offset newPosition) {
    setState(() {
      _assistantPosition = newPosition;
    });
  }

  Future<void> _getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  // void printDescriptorBoxContents() {
  //   if (_descriptorBox != null) {
  //     print('--- Descriptor Box Contents ---');
  //     for (var i = 0; i < _descriptorBox!.length; i++) {
  //       final key = _descriptorBox!.keyAt(i); // Get the key
  //       final value = _descriptorBox!.getAt(i); // Get the value
  //       print('Key: $key');
  //       walletService.printInChunks('Value: $value');
  //     }
  //     print('--- End of Descriptor Box ---');
  //   } else {
  //     print('Descriptor Box is null or not initialized.');
  //   }
  // }

  Future<DescriptorPublicKey?> getpubkey(String mnemonic) {
    if (!pubKeyFutures.containsKey(mnemonic)) {
      pubKeyFutures[mnemonic] = _fetchPubKey(mnemonic);
    }
    return pubKeyFutures[mnemonic]!;
  }

  Future<DescriptorPublicKey?> _fetchPubKey(String mnemonic) async {
    final trueMnemonic = await Mnemonic.fromString(mnemonic);

    final hardenedDerivationPath =
        await DerivationPath.create(path: "m/84h/1h/0h");

    final receivingDerivationPath = await DerivationPath.create(path: "m/0");

    final (receivingSecretKey, receivingPublicKey) =
        await walletService.deriveDescriptorKeys(
      hardenedDerivationPath,
      receivingDerivationPath,
      trueMnemonic,
    );

    return receivingPublicKey;
  }

  Future<bool?> showEditAliasDialog(
    BuildContext context,
    List<Map<String, dynamic>> pubKeysAlias,
    Box<dynamic> box,
    String compositeKey,
  ) async {
    // Create a map of alias controllers

    Map<String, TextEditingController> aliasControllers = {
      for (var entry in pubKeysAlias)
        entry['publicKey']!: TextEditingController(text: entry['alias']),
    };

    final localizationContext = Navigator.of(context).context;

    return (await DialogHelper.buildCustomDialog<bool>(
          context: context,
          titleKey: 'edit_alias',
          showCloseButton: false,
          content: Column(
            children: pubKeysAlias.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppColors.gradient(context),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: AppColors.primary(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${AppLocalizations.of(localizationContext)!.translate('pub_key')}: ${entry['publicKey']}",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 10),
                    TextField(
                      controller: aliasControllers[entry['publicKey']],
                      style: TextStyle(
                        color: AppColors.text(context),
                      ),
                      decoration: InputDecoration(
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppColors.container(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkwellButton(
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pop(false);
                  },
                  label: AppLocalizations.of(localizationContext)!
                      .translate('cancel'),
                  backgroundColor: AppColors.gradient(context),
                  textColor: AppColors.text(context),
                  icon: Icons.cancel_rounded,
                  iconColor: AppColors.error(context),
                ),
                InkwellButton(
                  onTap: () {
                    // Update all aliases in pubKeysAlias
                    for (var entry in pubKeysAlias) {
                      entry['alias'] =
                          aliasControllers[entry['publicKey']]!.text;
                    }

                    // Save the updated data back into the Hive Box
                    var rawValue = box.get(compositeKey);
                    if (rawValue != null) {
                      try {
                        Map<String, dynamic> parsedValue = jsonDecode(rawValue);
                        parsedValue['pubKeysAlias'] = pubKeysAlias;

                        // Store the updated data in Hive
                        box.put(compositeKey, jsonEncode(parsedValue));

                        Navigator.of(context, rootNavigator: true).pop(true);

                        SnackBarHelper.show(context, message: 'alias_updated');
                      } catch (e) {
                        print("Error updating Hive box: $e");
                      }
                    }
                  },
                  label: AppLocalizations.of(localizationContext)!
                      .translate('save'),
                  backgroundColor: AppColors.gradient(context),
                  textColor: AppColors.text(context),
                  icon: Icons.cancel_rounded,
                  iconColor: AppColors.icon(context),
                ),
              ],
            ),
          ],
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.title,
            if (isTestnet) // Show the Testnet banner if `isTestnet` is true
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.container(context)
                      .withAlpha((0.8 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.redAccent,
                    width: 1,
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate('network_banner'),
                  style: TextStyle(
                    fontSize: 16, // Bigger font
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent, // High contrast color
                  ),
                ),
              ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.accent(context),
                AppColors.gradient(context),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (widget.showAssistantButton)
            IconButton(
              icon: Icon(Icons.help_outline, color: AppColors.icon(context)),
              onPressed: _toggleAssistant,
            ),
          IconButton(
            icon: Icon(
              settingsProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: AppColors.icon(context),
            ),
            onPressed: () {
              Provider.of<SettingsProvider>(context, listen: false)
                  .toggleTheme();
              setState(() {});
            },
          ),
        ],
      ),
      drawer: widget.showDrawer
          ? Drawer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent(context),
                      AppColors.gradient(context),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDrawerHeader(context),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildPersonalWalletTile(context),
                          const SizedBox(height: 10),
                          _buildSharedWalletTiles(context),
                          const SizedBox(height: 10),
                          _buildCreateSharedWalletTile(context),
                        ],
                      ),
                    ),
                    _buildSettingsTile(context),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          widget.onRefresh != null
              ? RefreshIndicator(
                  onRefresh: widget.onRefresh!, // Call onRefresh if provided
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent(context),
                            AppColors.gradient(context)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: widget.body,
                      ),
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent(context),
                        AppColors.gradient(context)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: widget.body,
                  ),
                ),

          // ✅ Assistant is properly positioned inside Stack
          if (_showAssistant)
            Positioned(
              left: _assistantPosition.dx,
              top: _assistantPosition.dy,
              child: StatefulBuilder(
                // ✅ Allow dynamic updates
                builder: (context, setState) {
                  return AssistantWidget(
                    key:
                        _assistantKey, // Assign GlobalKey to track widget state
                    initialMessage: _assistantMessage,
                    context: context,
                    onClose: _toggleAssistant,
                    onNextMessage: _nextAssistantMessage,
                    onDragEnd: updateAssistantPosition,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent(context),
            AppColors.gradient(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 2,
            child: SizedBox(
              height: 60,
              width: 60,
              child: Lottie.asset(
                'assets/animations/bitcoin_city.json',
                repeat: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            flex: 1,
            child: Text(
              AppLocalizations.of(context)!.translate('welcome'),
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Text(
              AppLocalizations.of(context)!.translate('welcoming_description'),
              style: TextStyle(
                color: AppColors.text(context).withAlpha((0.8 * 255).toInt()),
                fontSize: 14,
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Text(
              '${AppLocalizations.of(context)!.translate('version')}: $_version',
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalWalletTile(BuildContext context) {
    return Card(
      elevation: 6,
      color: AppColors.gradient(context),
      shadowColor: AppColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.wallet,
          color: AppColors.cardTitle(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('personal_wallet'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text(context),
          ),
        ),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/wallet_page', (Route<dynamic> route) => false);
        },
      ),
    );
  }

  Widget _buildSharedWalletTiles(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable:
          _descriptorBox!.listenable(), // Listen for changes in the box
      builder: (context, Box<dynamic> box, _) {
        List<Widget> sharedWalletCards = [];

        for (int i = 0; i < box.length; i++) {
          final compositeKey = box.keyAt(i) ?? 'Unknown Composite Key';
          final rawValue = box.getAt(i);

          // Split the composite key into mnemonic and descriptor name
          final keyParts = compositeKey.split('_descriptor');
          final mnemonic =
              keyParts.isNotEmpty ? keyParts[0] : 'Unknown Mnemonic';
          final descriptorName = keyParts.length > 1
              ? keyParts[1].replaceFirst('_', '')
              : 'Unnamed Descriptor';

          // Parse the raw value (JSON) into a Map
          Map<String, dynamic>? parsedValue;
          if (rawValue != null) {
            try {
              parsedValue = jsonDecode(rawValue);
            } catch (e) {
              // print('Error parsing descriptor JSON: $e');
              throw ('Error parsing descriptor JSON: $e');
            }
          }

          final descriptor =
              parsedValue?['descriptor'] ?? 'No descriptor available';
          final pubKeysAlias = (parsedValue?['pubKeysAlias'] as List<dynamic>)
              .map((item) => Map<String, String>.from(item))
              .toList();

          sharedWalletCards.add(
            FutureBuilder<DescriptorPublicKey?>(
              future: getpubkey(mnemonic),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // Show a loader while waiting
                } else if (snapshot.hasError) {
                  return const Text('Error fetching public key');
                }

                final pubKey = snapshot.data;
                if (pubKey == null) {
                  return const Text('Public key not found');
                }

                // Extract the content inside square brackets
                final RegExp regex = RegExp(r'\[([^\]]+)\]');
                final Match? match = regex.firstMatch(pubKey.asString());

                final String targetFingerprint = match!.group(1)!.split('/')[0];

                final matchingAliasEntry = pubKeysAlias.firstWhere(
                  (entry) => entry['publicKey']!.contains(targetFingerprint),
                  orElse: () => {
                    'alias': 'Unknown Alias'
                  }, // Fallback if no match is found
                );

                final displayAlias = matchingAliasEntry['alias'] ?? 'No Alias';

                return Card(
                  elevation: 6,
                  color: AppColors.gradient(context),
                  shadowColor: AppColors.background(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.cardTitle(context),
                    ),
                    title: Text(
                      '${descriptorName}_$displayAlias',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text(context),
                      ),
                    ),
                    subtitle: Text(
                      descriptor,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onLongPress: () async {
                      final bool? aliasUpdated = await showEditAliasDialog(
                        context,
                        pubKeysAlias,
                        box,
                        compositeKey,
                      );

                      // Wait until the user dismisses the dialog
                      if (aliasUpdated == true) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SharedWallet(
                              descriptor: descriptor,
                              mnemonic: mnemonic,
                              pubKeysAlias: pubKeysAlias,
                              descriptorName: descriptorName,
                            ),
                          ),
                        );
                      }
                    },
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SharedWallet(
                            descriptor: descriptor,
                            mnemonic: mnemonic,
                            pubKeysAlias: pubKeysAlias,
                            descriptorName: descriptorName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        }

        return Column(children: sharedWalletCards);
      },
    );
  }

  Widget _buildCreateSharedWalletTile(BuildContext context) {
    return Card(
      elevation: 6,
      color: AppColors.gradient(context),
      shadowColor: AppColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.add_circle,
          color: AppColors.cardTitle(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('create_shared_wallet'),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context)),
        ),
        onTap: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/shared_wallet', (Route<dynamic> route) => false);
        },
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context) {
    return Card(
      elevation: 6,
      color: AppColors.gradient(context),
      shadowColor: AppColors.background(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.settings,
          color: AppColors.cardTitle(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('settings'),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context)),
        ),
        onTap: () {
          Navigator.of(context).pushNamed('/settings');
        },
      ),
    );
  }
}
