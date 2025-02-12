import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_wallet/services/settings_provider.dart';
import 'package:flutter_wallet/utilities/splash_screen.dart';
import 'package:flutter_wallet/wallet_pages/ca_wallet_page.dart';
import 'package:flutter_wallet/wallet_pages/create_shared_wallet.dart';
import 'package:flutter_wallet/wallet_pages/import_shared_wallet.dart';
import 'package:flutter_wallet/utilities/pin_setup_page.dart';
import 'package:flutter_wallet/utilities/pin_verification_page.dart';
import 'package:flutter_wallet/wallet_pages/settings_page.dart';
import 'package:flutter_wallet/wallet_pages/shared_wallet_page.dart';
import 'package:flutter_wallet/utilities/theme_provider.dart';
import 'package:flutter_wallet/hive/wallet_data.dart';
import 'package:flutter_wallet/wallet_pages/tutorial_page.dart';
import 'package:flutter_wallet/wallet_pages/wallet_page.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

void main() async {
  // Ensure all Flutter bindings are initialized before running Hive
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter(); // Initialize Hive

  // Register the generated Hive adapter for WalletData
  Hive.registerAdapter(WalletDataAdapter());

  // Retrieve or generate encryption key
  final encryptionKey = await _getEncryptionKey();

  // Open the encrypted boxes
  await Hive.openBox(
    'walletBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  await Hive.openBox(
    'descriptorBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  await Hive.openBox<WalletData>(
    'walletDataBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  await Hive.openBox(
    'settingsBox',
    encryptionCipher: HiveAesCipher(Uint8List.fromList(encryptionKey)),
  );

  runApp(
    ShowCaseWidget(
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ThemeProvider(darkTheme)),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SplashScreenWrapper(),
        ),
      ),
    ),
  );
}

// FlutterSecureStorage for encryption key management
final secureStorage = FlutterSecureStorage();

Future<List<int>> _getEncryptionKey() async {
  String? encodedKey = await secureStorage.read(key: 'encryptionKey');

  if (encodedKey != null) {
    return base64Url.decode(encodedKey);
  } else {
    var key = Hive.generateSecureKey();
    await secureStorage.write(
        key: 'encryptionKey', value: base64UrlEncode(key));
    return key;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider(darkTheme)),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Wallet',
            theme: themeProvider.themeData,
            initialRoute: _determineInitialRoute(),
            routes: {
              '/wallet_page': (context) => const WalletPage(),
              '/ca_wallet_page': (context) => const CAWalletPage(),
              '/pin_setup_page': (context) => const PinSetupPage(),
              '/pin_verification_page': (context) =>
                  const PinVerificationPage(),
              '/shared_wallet': (context) => const SharedWalletPage(),
              '/create_shared': (context) => const CreateSharedWallet(),
              '/import_shared': (context) => const ImportSharedWallet(),
              '/settings': (context) => const SettingsPage(),
              '/tutorial': (context) => const TutorialPage(),
            },
          );
        },
      ),
    );
  }

  String _determineInitialRoute() {
    var walletBox = Hive.box('walletBox');

    if (!walletBox.containsKey('userPin')) {
      // If the user hasn't set a PIN yet
      return '/tutorial';
    } else if (walletBox.containsKey('walletMnemonic')) {
      // If the wallet mnemonic exists, navigate to PIN verification
      return '/pin_verification_page';
    } else {
      // If no wallet mnemonic, navigate to wallet creation
      return '/ca_wallet_page';
    }
  }
}

class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  SplashScreenWrapperState createState() => SplashScreenWrapperState();
}

class SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();

    // Use addPostFrameCallback to navigate AFTER the build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          // Check if widget is still active before navigating
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyApp()),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Wrap with MaterialApp
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
