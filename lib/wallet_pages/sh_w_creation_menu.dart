import 'package:flutter/material.dart';
import 'package:flutter_wallet/languages/app_localizations.dart';
import 'package:flutter_wallet/widget_helpers/base_scaffold.dart';
import 'package:flutter_wallet/utilities/custom_button.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class ShWCreationMenu extends StatefulWidget {
  const ShWCreationMenu({super.key});

  @override
  ShWCreationMenuState createState() => ShWCreationMenuState();
}

class ShWCreationMenuState extends State<ShWCreationMenu> {
  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: Text(
        AppLocalizations.of(context)!.translate('shared_wallet'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Add a header icon or illustration
                Center(
                    child: SizedBox(
                  height: 150,
                  width: 150,
                  child: Lottie.asset(
                    'assets/animations/bitcoin_city.json',
                    repeat: true,
                  ),
                )),
                const SizedBox(height: 20),
                // Add a description
                Text(
                  AppLocalizations.of(context)!
                      .translate('create_import_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                // Buttons
                CustomButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/create_shared');
                  },
                  backgroundColor: AppColors.background(context),
                  foregroundColor: AppColors.gradient(context),
                  icon: Icons.add_circle,
                  iconColor: AppColors.text(context),
                  label: AppLocalizations.of(context)!
                      .translate('create_shared_wallet'),
                  padding: 16.0,
                  iconSize: 28.0,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/import_shared');
                  },
                  backgroundColor: AppColors.background(context),
                  foregroundColor: AppColors.text(context),
                  icon: Icons.download,
                  iconColor: AppColors.gradient(context),
                  label:
                      AppLocalizations.of(context)!.translate('import_wallet'),
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
