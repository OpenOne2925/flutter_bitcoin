import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:hive/hive.dart';

class PinVerificationPage extends StatefulWidget {
  const PinVerificationPage({super.key});

  @override
  PinVerificationPageState createState() => PinVerificationPageState();
}

class PinVerificationPageState extends State<PinVerificationPage> {
  final TextEditingController _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _verifyPin() async {
    var walletBox = Hive.box('walletBox');
    String? savedPin = walletBox.get('userPin');

    if (savedPin == _pinController.text) {
      Navigator.popAndPushNamed(context, '/wallet_page',
          arguments: true); // Navigate to main app page
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enter PIN"),
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
              const SizedBox(height: 20),
              CustomButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _verifyPin();
                  }
                },
                backgroundColor: Colors.white, // White background
                foregroundColor: Colors.black, // Bitcoin orange color for text
                icon: Icons.pin, // Icon you want to use
                iconColor: Colors.orange, // Color for the icon
                label: 'Verify PIN',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
