import 'dart:convert';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/utilities/theme_provider.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BaseScaffold extends StatefulWidget {
  final Widget body;
  final Text title;
  final bool isTestnet; // Add a flag to indicate Testnet or Mainnet
  final Future<void> Function()? onRefresh;

  const BaseScaffold({
    super.key,
    required this.title,
    required this.body,
    this.isTestnet = true, // Default to Mainnet if not specified
    this.onRefresh,
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

  @override
  void initState() {
    super.initState();
    _descriptorBox = Hive.box<dynamic>('descriptorBox');
    // printDescriptorBoxContents();
    _getVersion();
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
  ) {
    // Create a map of alias controllers

    Map<String, TextEditingController> aliasControllers = {
      for (var entry in pubKeysAlias)
        entry['publicKey']!: TextEditingController(text: entry['alias']),
    };

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Edit Alias',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: pubKeysAlias.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Public Key: ${entry['publicKey']}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 10),
                      TextField(
                        controller: aliasControllers[entry['publicKey']],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Enter new alias",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[800],
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
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Save Button
                TextButton(
                  onPressed: () {
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

                        Navigator.of(context).pop(true);
                      } catch (e) {
                        print("Error updating Hive box: $e");
                      }
                    }
                  },
                  style: TextButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.black),
                  ),
                ),

                // Cancel Button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  style: TextButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.title,
            if (widget
                .isTestnet) // Show the Testnet banner if `isTestnet` is true
              const Text(
                'You are on Testnet!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: isDarkMode ? Colors.deepPurple : Colors.green,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              setState(() {});
            },
          ),
        ],
      ),
      drawer: Drawer(
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
            const Divider(),
            _buildSettingsTile(context),
          ],
        ),
      ),
      body: widget.onRefresh != null
          ? RefreshIndicator(
              onRefresh: widget.onRefresh!, // Call onRefresh if provided
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.greenAccent, Colors.white],
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.greenAccent, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: widget.body,
              ),
            ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.greenAccent],
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
            child: const Text(
              'Welcome to ShareHaven',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Text(
              'Version: $_version',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Flexible(
            flex: 1,
            child: Text(
              'Your Bitcoin wallet companion.',
              style: TextStyle(
                color: Colors.white.withAlpha((0.8 * 255).toInt()),
                fontSize: 14,
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
      shadowColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.wallet, color: Colors.green),
        title: const Text(
          'Personal Wallet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  shadowColor: Colors.greenAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet,
                        color: Colors.black),
                    title: Text(
                      '${descriptorName}_$displayAlias',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    subtitle: Text(
                      descriptor,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
      shadowColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.add_circle,
          color: Colors.green,
        ),
        title: const Text(
          'Create Shared Wallet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
      shadowColor: Colors.greenAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.settings,
          color: Colors.green,
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.of(context).pushNamed('/settings');
        },
      ),
    );
  }
}
