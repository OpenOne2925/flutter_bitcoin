import 'package:flutter/material.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  PinSetupPageState createState() => PinSetupPageState();
}

class PinSetupPageState extends State<PinSetupPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _status = '';

  final GlobalKey _pinFieldKey = GlobalKey();
  final GlobalKey _confirmPinFieldKey = GlobalKey();
  final GlobalKey _setPinButtonKey = GlobalKey();
  final GlobalKey _restartTutorialKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAndStartTutorial();
  }

  Future<void> _checkAndStartTutorial() async {
    var settingsBox = Hive.box('settingsBox');

    bool enableTutorial = settingsBox.get('enableTutorial') ?? false;

    if (enableTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ShowCaseWidget.of(context).startShowCase([
            _pinFieldKey,
            _confirmPinFieldKey,
            _setPinButtonKey,
            _restartTutorialKey
          ]);
        }
      });
    }
  }

  void _savePin(String pin) async {
    var walletBox = Hive.box('walletBox');
    await walletBox.put('userPin', pin);

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/ca_wallet_page');
  }

  void _validateAndSave() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _status = 'PIN successfully set!';
      });
      _savePin(_pinController.text);
    } else {
      setState(() {
        _status = 'Please correct the errors and try again.';
      });
    }
  }

  Widget _buildStatusBanner() {
    if (_status.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _status.contains('successfully') ? Colors.blue : Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set PIN"),
        backgroundColor: Colors.blue,
        actions: [
          Showcase(
            key: _restartTutorialKey,
            description: 'Tap here to restart the tutorial.',
            child: IconButton(
              icon: Icon(Icons.help_outline),
              onPressed: () {
                ShowCaseWidget.of(context).startShowCase([
                  _pinFieldKey,
                  _confirmPinFieldKey,
                  _setPinButtonKey,
                  _restartTutorialKey
                ]);
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Add an icon/illustration
                Center(
                  child: Icon(
                    Icons.lock,
                    size: 100,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                // Status Banner
                _buildStatusBanner(),
                // PIN Entry Field
                Showcase(
                  key: _pinFieldKey,
                  description:
                      'Enter a secure 6-digit PIN to protect your wallet',
                  child: TextFormField(
                    controller: _pinController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: 'Enter PIN',
                      hintText: 'Enter a 6-digit PIN',
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Confirm PIN Entry Field
                Showcase(
                  key: _confirmPinFieldKey,
                  description: 'Re-enter your PIN to confirm it matches',
                  child: TextFormField(
                    controller: _confirmPinController,
                    decoration: CustomTextFieldStyles.textFieldDecoration(
                      context: context,
                      labelText: 'Confirm PIN',
                      hintText: 'Re-enter your PIN',
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Set PIN Button
                Showcase(
                  key: _setPinButtonKey,
                  description:
                      'Press this button to save your PIN and continue.',
                  child: CustomButton(
                    onPressed: _validateAndSave,
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    icon: Icons.pin,
                    iconColor: Colors.white,
                    label: 'Set PIN',
                    padding: 16.0,
                    iconSize: 28.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
