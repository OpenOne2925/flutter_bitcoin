import 'package:flutter/material.dart';
import 'package:flutter_wallet/services/settings_provider.dart';
import 'package:flutter_wallet/utilities/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currencies = [
      'ARS',
      'AUD',
      'BRL',
      'CAD',
      'CHF',
      'CLP',
      'CNY',
      'CZK',
      'DKK',
      'EUR',
      'GBP',
      'HKD',
      'HRK',
      'HUF',
      'INR',
      'ISK',
      'JPY',
      'KRW',
      'NGN',
      'NZD',
      'PLN',
      'RON',
      'RUB',
      'SEK',
      'SGD',
      'THB',
      'TRY',
      'TWD',
      'USD',
    ];

    return BaseScaffold(
      title: const Text('Settings'),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header icon or illustration
                Center(
                  child: SizedBox(
                    height: 150,
                    width: 150,
                    child: Lottie.asset(
                      'assets/animations/bitcoin_city.json',
                      repeat: true,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Description
                Text(
                  'Customize your global settings to personalize your wallet experience.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                // Currency Selector
                const Text(
                  'Select Currency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: settingsProvider.currency,
                  items: currencies.map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      settingsProvider.setCurrency(value);
                    }
                  },
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
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
                  dropdownColor: Colors.black,
                  isExpanded: true, // Ensure dropdown spans the full width
                  menuMaxHeight:
                      250, // Limit the dropdown's height to fit 5 items
                ),
                const SizedBox(height: 40),
                // Save Button
                CustomButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings saved!'),
                      ),
                    );
                  },
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.save,
                  iconColor: Colors.white,
                  label: 'Save Settings',
                  padding: 16.0,
                  iconSize: 28.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
