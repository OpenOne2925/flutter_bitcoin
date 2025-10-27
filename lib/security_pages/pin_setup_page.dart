import 'package:bdk_flutter/bdk_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/services/wallet_service.dart';
import 'package:flutter_wallet/settings/settings_provider.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:flutter_wallet/utilities/custom_text_field_styles.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  PinSetupPageState createState() => PinSetupPageState();
}

class PinSetupPageState extends State<PinSetupPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _networkFieldKey = GlobalKey<FormFieldState<Network>>();

  String _status = '';

  @override
  void initState() {
    super.initState();

    // Wait until the first frame is rendered before showing the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialInstructionsDialog();
    });
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
        _status = 'Please correct the errors and try again';
      });
    }
  }

  void _showInitialInstructionsDialog() {
    final rootContext = context;

    final rawText =
        AppLocalizations.of(rootContext)!.translate('initial_instructions');

// Split the text around the {x} placeholder
    final parts = rawText.split('{x}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(rootContext)!
              .translate('initial_instructions_title'),
        ),
        content: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              color: AppColors.text(context),
              fontSize: 16,
              height: 1.5,
            ),
            children: [
              TextSpan(text: parts[0]), // before the URL
              TextSpan(
                text: 'https://github.com/cortezhanny124/shared_haven',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () async {
                    final url = Uri.parse(
                        'https://github.com/cortezhanny124/shared_haven');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
              ),
              if (parts.length > 1) TextSpan(text: parts[1]), // after the URL
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(rootContext)!.translate('got_it'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    String statusText;

    if (_status.isEmpty) return const SizedBox.shrink();

    if (_status == 'Please correct the errors and try again') {
      statusText = AppLocalizations.of(context)!.translate('correct_errors');
    } else {
      statusText = AppLocalizations.of(context)!.translate('pin_set_success');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _status.contains('successfully')
            ? AppColors.primary(context)
            : AppColors.error(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: AppColors.text(context),
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final rootContext = context;

    return BaseScaffold(
      title: Text(AppLocalizations.of(context)!.translate('set_pin')),
      showDrawer: false,
      body: Padding(
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
                  color: AppColors.icon(context),
                ),
              ),
              const SizedBox(height: 20),
              // Status Banner
              _buildStatusBanner(),
              // PIN Entry Field
              TextFormField(
                controller: _pinController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText:
                      AppLocalizations.of(context)!.translate('enter_pin'),
                  hintText: AppLocalizations.of(context)!
                      .translate('enter_6_digits_pin'),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length != 6) {
                    return AppLocalizations.of(context)!
                        .translate('pin_must_be_six');
                  }
                  return null;
                },
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 16),
              // Confirm PIN Entry Field
              TextFormField(
                controller: _confirmPinController,
                decoration: CustomTextFieldStyles.textFieldDecoration(
                  context: context,
                  labelText:
                      AppLocalizations.of(context)!.translate('confirm_pin'),
                  hintText:
                      AppLocalizations.of(context)!.translate('re_enter_pin'),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value != _pinController.text) {
                    return AppLocalizations.of(context)!
                        .translate('pin_mismatch');
                  }
                  return null;
                },
                style: TextStyle(
                  color: AppColors.text(context),
                ),
              ),

              const SizedBox(height: 20),
              // Set PIN Button
              CustomButton(
                onPressed: _validateAndSave,
                backgroundColor: AppColors.background(context),
                foregroundColor: AppColors.gradient(context),
                icon: Icons.pin,
                iconColor: AppColors.text(context),
                label: AppLocalizations.of(context)!.translate('set_pin'),
                padding: 16.0,
                iconSize: 28.0,
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<Network>(
                key: _networkFieldKey,
                value: settingsProvider.network,
                items: Network.values.where((network) {
                  return network == Network.bitcoin ||
                      network == Network.testnet;
                }).map((network) {
                  final displayName = network == Network.bitcoin
                      ? 'Mainnet'
                      : network.name.capitalize();

                  return DropdownMenuItem(
                    value: network,
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;

                  if (value == Network.bitcoin) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          AppLocalizations.of(rootContext)!
                              .translate('mainnet_switch'),
                        ),
                        content: Text(
                          AppLocalizations.of(rootContext)!
                              .translate('mainnet_switch_text'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              AppLocalizations.of(rootContext)!
                                  .translate('cancel'),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              AppLocalizations.of(rootContext)!
                                  .translate('continue'),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      settingsProvider.setNetwork(value);
                    } else {
                      // Visually revert the dropdown to the provider's current value
                      _networkFieldKey.currentState
                          ?.didChange(settingsProvider.network);
                    }
                  } else {
                    settingsProvider.setNetwork(value);
                  }
                },
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.background(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                ),
                dropdownColor: AppColors.gradient(context),
                isExpanded: true,
                menuMaxHeight: 250,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
