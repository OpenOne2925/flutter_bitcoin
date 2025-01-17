import 'dart:convert';
import 'dart:typed_data';

import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/services/wallet_service.dart';

class PolicyTest extends StatefulWidget {
  const PolicyTest({super.key});

  @override
  PolicyTestState createState() => PolicyTestState();
}

class PolicyTestState extends State<PolicyTest> {
  final WalletService _walletService = WalletService();

  final TextEditingController _pubKeyController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();

  String? threshold;

  List<String> publicKeys = [];
  List<String> timelocks = [];
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      String input = _textController.text;
      // Handle the input (e.g., print, send to API, or process it)
      // print("Input: $input");

      const String targetFingerprint = "fb94d032";

      final Map<String, dynamic> policy = jsonDecode(input);

      // print(policy);

      final path = _walletService.extractAllPathsToFingerprint(
          policy, targetFingerprint);

      print(path);

      // First Path: Direct MULTISIG
      final Map<String, Uint32List> multisigPath = {
        for (int i = 0; i < path[0]["ids"].length - 1; i++)
          path[0]["ids"][i]: Uint32List.fromList([path[0]["indexes"][i]])
      };

      // Second Path: Nested THRESH with timelock and MULTISIG
      final Map<String, Uint32List> timeLockPath = {
        for (int i = 0; i < path[1]["ids"].length - 1; i++)
          path[1]["ids"][i]: Uint32List.fromList([path[1]["indexes"][i]])
      };

      print(multisigPath);
      print(timeLockPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Input Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: 'Enter some text',
                  border: OutlineInputBorder(),
                  hintText: 'Type something...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSubmit,
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
