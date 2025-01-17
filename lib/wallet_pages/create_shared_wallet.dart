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

  String? threshold;

  List<String> publicKeys = [];
  List<String> timelocks = [];

  String? receiving1Key;
  String? change1Key;
  String? privateKey;

  bool isLoading = false; // For loading state during wallet creation
  bool walletCreated = false; // To avoid multiple wallet creations

  String? _mnemonic;

  String _finalDescriptor = "";
  bool _descriptorVisible = false; // Toggle descriptor visibility

  String _publicKey = ''; // To store the generated public key

  Future<void> _generatePublicKey() async {
    setState(() {
      isLoading = true;
    });
    try {
      final walletBox = Hive.box('walletBox');
      final savedMnemonic = walletBox.get('walletMnemonic');
      final mnemonic = await Mnemonic.fromString(savedMnemonic);

      // print(mnemonic);

      final hardenedDerivationPath =
          await DerivationPath.create(path: "m/84h/1h/0h");
      final receivingDerivationPath = await DerivationPath.create(path: "m/0");

      final (receivingSecretKey, receivingPublicKey) =
          await _walletService.deriveDescriptorKeys(
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
      setState(() {
        isLoading = false;
      });
    }
  }

  String buildTimelockCondition(List<String> formattedTimelocks) {
    // Recursive function to combine conditions into valid or_i pairs
    String combineConditions(List<String> conditions) {
      while (conditions.length > 1) {
        List<String> combined = [];
        for (int i = 0; i < conditions.length; i += 2) {
          if (i + 1 < conditions.length) {
            combined.add('or_i(${conditions[i]},${conditions[i + 1]})');
          } else {
            // Carry forward the last condition if odd number of items
            combined.add(conditions[i]);
          }
        }
        conditions = combined;
      }
      return conditions.first;
    }

    // Combine formatted timelocks into valid or_i conditions
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomButton(
              onPressed: _generatePublicKey,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              icon: Icons.vpn_key,
              iconColor: Colors.white,
              label: 'Generate Public Key',
              padding: 16.0,
              iconSize: 24.0,
            ),
            const SizedBox(height: 20),
            if (_publicKey.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Public Key: $_publicKey',
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
                              content: Text('Public Key copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showPublicKeyDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Enter Public Keys',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showTimelockDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Enter Timelock Conditions',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Remove square brackets from each item
                String formattedKeys =
                    publicKeys.toString().replaceAll(RegExp(r'^\[|\]$'), '');

                String multi = 'multi($threshold,$formattedKeys)';

                print('Descriptor: $multi');

                print(timelocks);
                String timelockCondition = buildTimelockCondition(timelocks);

                String finalDescriptor = 'wsh(or_d($multi,$timelockCondition))';
                finalDescriptor = finalDescriptor.replaceAll(' ', '');

                setState(() {
                  _finalDescriptor = finalDescriptor;
                });

                _walletService
                    .printInChunks('FinalDescriptor: $_finalDescriptor');

                setState(() {
                  _finalDescriptor = finalDescriptor; // Example
                  _descriptorVisible = true; // Show descriptor field
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Create Descriptor',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            if (_descriptorVisible)
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
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
                              content: Text('Descriptor copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SharedWallet(
                      descriptor: _finalDescriptor,
                      mnemonic: _mnemonic!,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Navigate to Shared Wallet',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublicKeyDialog(BuildContext context) {
    List<TextEditingController> listController = [TextEditingController()];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Enter Public Keys'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _thresholdController,
                      decoration: CustomTextFieldStyles.textFieldDecoration(
                        context: context,
                        labelText: 'Enter Threshold',
                        hintText: 'Enter Threshold',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _pubKeyController,
                      decoration: CustomTextFieldStyles.textFieldDecoration(
                        context: context,
                        labelText: 'Enter First Public Key',
                        hintText: 'Enter First Public Key',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Column(
                      children: List.generate(listController.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  height: 60,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E384E),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TextFormField(
                                    controller: listController[index],
                                    autofocus: false,
                                    decoration: CustomTextFieldStyles
                                        .textFieldDecoration(
                                      context: context,
                                      labelText: 'Enter Public Key',
                                      hintText: 'Enter Public Key',
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (index != 0)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      listController[index].clear();
                                      listController[index].dispose();
                                      listController.removeAt(index);
                                    });
                                  },
                                  child: const Icon(
                                    Icons.delete,
                                    color: Color(0xFF6B74D6),
                                    size: 35,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          listController.add(TextEditingController());
                        });
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF444C60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Add More",
                            style: TextStyle(color: const Color(0xFFF8F8FF)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      threshold = _thresholdController.text;

                      // Start with the value from `_pubKeyController`
                      publicKeys = [_pubKeyController.text];

                      // Add the values from `listController`
                      publicKeys.addAll(
                          listController.map((controller) => controller.text));
                    });

                    print(publicKeys);

                    Navigator.pop(context);
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTimelockDialog(BuildContext context) {
    List<Map<String, dynamic>> listController = [
      {
        "pubkeys": [TextEditingController()],
        "timelock": TextEditingController(),
        "threshold": TextEditingController(),
      }
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Enter Timelock Conditions'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      children: List.generate(listController.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E384E),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: TextFormField(
                                        controller: listController[index]
                                            ["timelock"],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Timelock',
                                          hintText: 'Enter Timelock',
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(
                                            color: Color.fromARGB(
                                                255, 132, 140, 155),
                                          ),
                                        ),
                                        style: const TextStyle(
                                            color: Color(0xFFF8F8FF)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E384E),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: TextFormField(
                                        controller: listController[index]
                                            ["threshold"],
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Threshold',
                                          hintText: 'Enter Threshold',
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(
                                            color: Color.fromARGB(
                                                255, 132, 140, 155),
                                          ),
                                        ),
                                        style: const TextStyle(
                                            color: Color(0xFFF8F8FF)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (index != 0)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          // Dispose controllers
                                          listController[index]["timelock"]
                                              .dispose();
                                          listController[index]["threshold"]
                                              .dispose();
                                          for (var pubkeyController
                                              in listController[index]
                                                  ["pubkeys"]) {
                                            pubkeyController.dispose();
                                          }
                                          listController.removeAt(index);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.delete,
                                        color: Color(0xFF6B74D6),
                                        size: 35,
                                      ),
                                    ),
                                ],
                              ),
                              Column(
                                children: List.generate(
                                    listController[index]["pubkeys"].length,
                                    (pubkeyIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            height: 60,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2E384E),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: TextFormField(
                                              controller: listController[index]
                                                  ["pubkeys"][pubkeyIndex],
                                              decoration: InputDecoration(
                                                labelText: 'Public Key',
                                                hintText: 'Enter Public Key',
                                                border: InputBorder.none,
                                                hintStyle: TextStyle(
                                                  color: Color.fromARGB(
                                                      255, 132, 140, 155),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                  color: Color(0xFFF8F8FF)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        if (pubkeyIndex != 0)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                listController[index]["pubkeys"]
                                                        [pubkeyIndex]
                                                    .dispose();
                                                listController[index]["pubkeys"]
                                                    .removeAt(pubkeyIndex);
                                              });
                                            },
                                            child: const Icon(
                                              Icons.delete,
                                              color: Color(0xFF6B74D6),
                                              size: 35,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    listController[index]["pubkeys"]
                                        .add(TextEditingController());
                                  });
                                },
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF444C60),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "Add Public Key",
                                      style: TextStyle(
                                          color: const Color(0xFFF8F8FF)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          listController.add({
                            "pubkeys": [TextEditingController()],
                            "timelock": TextEditingController(),
                            "threshold": TextEditingController(),
                          });
                        });
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFF444C60),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Add Timelock Condition",
                            style: TextStyle(color: const Color(0xFFF8F8FF)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final regex = RegExp(
                        r'\/(\d+)(?=\/\*)'); // Matches the last number in the derivation path before '/*'

                    setState(() {
                      Set<String> seenPubKeys =
                          {}; // Track already-seen public keys

                      seenPubKeys.addAll(publicKeys);
                      timelocks = listController.map((controllers) {
                        List<TextEditingController> pubkeyControllers =
                            controllers["pubkeys"]
                                as List<TextEditingController>;

                        // Process public keys and resolve duplicates
                        List<String> publicKeys =
                            pubkeyControllers.map((pubkeyController) {
                          String originalKey = pubkeyController.text;

                          // Check if the public key already exists in the set
                          while (seenPubKeys.contains(originalKey)) {
                            // Modify the key by incrementing the last number in the derivation path
                            originalKey =
                                originalKey.replaceFirstMapped(regex, (match) {
                              int currentValue = int.parse(match.group(1)!);
                              return '/${currentValue + 1}';
                            });
                          }

                          // Add the (possibly modified) key to the set of seen keys
                          seenPubKeys.add(originalKey);
                          return originalKey;
                        }).toList();

                        String timelock = controllers["timelock"].text;
                        String threshold = controllers["threshold"].text;

                        // Use multi if there are multiple public keys
                        String keyCondition = publicKeys.length > 1
                            ? 'multi($threshold,${publicKeys.join(",")})'
                            : 'pk(${publicKeys.first})';

                        // Build the and_v clause with the timelock
                        return 'and_v(v:older($timelock),$keyCondition)';
                      }).toList();
                    });

                    print(timelocks);
                    Navigator.pop(context);
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
