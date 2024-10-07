import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  PinSetupPageState createState() => PinSetupPageState();
}

class PinSetupPageState extends State<PinSetupPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _savePin(String pin) async {
    var walletBox = Hive.box('walletBox');
    await walletBox.put('userPin', pin);

    if (!mounted) return;

    Navigator.pushReplacementNamed(
        context, '/ca_wallet_page'); // Navigate to main app page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set PIN"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pinController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Enter PIN',
                  hintText: 'Enter PIN',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length != 6) {
                    return 'PIN must be 6 digits';
                  }
                  return null;
                },
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
              TextFormField(
                controller: _confirmPinController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText: 'Confirm PIN',
                  hintText: 'Confirm PIN',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value != _pinController.text) {
                    return 'PIN does not match';
                  }
                  return null;
                },
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface, // Dynamic text color
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _savePin(_pinController.text);
                  }
                },
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.orange, // Bitcoin orange color for text
                icon: Icons.pin, // Icon you want to use
                iconColor: Colors.black, // Color for the icon
                label: 'Set PIN',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
