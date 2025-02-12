import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  TutorialPageState createState() => TutorialPageState();
}

class TutorialPageState extends State<TutorialPage> {
  @override
  void initState() {
    super.initState();
    _checkIfAlreadySelected();
  }

  Future<void> _checkIfAlreadySelected() async {
    var settingsBox = await Hive.openBox('settingsBox');
    bool? tutorialEnabled = settingsBox.get('enableTutorial');

    // If the user has already made a choice, navigate to the next page
    if (tutorialEnabled != null) {
      _navigateToNextPage();
    }
  }

  Future<void> _setTutorialPreference(bool enable) async {
    var settingsBox = Hive.box('settingsBox');

    // Save the user's choice
    await settingsBox.put('enableTutorial', enable);

    // Navigate to the next page
    _navigateToNextPage();
  }

  void _navigateToNextPage() {
    Navigator.pushReplacementNamed(
        context, '/pin_setup_page'); // Redirect to Home/Main Page
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Graphic
          Lottie.asset(
            'assets/animations/lock_unlock.json', // Replace with your animation
            height: 200,
            repeat: true,
          ),
          const SizedBox(height: 20),

          // Tutorial Question
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Would you like to enable the tutorial?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // "Yes" Button
          ElevatedButton(
            onPressed: () => _setTutorialPreference(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: const Text("Yes, Show the Tutorial"),
          ),
          const SizedBox(height: 20),

          // "No" Button
          OutlinedButton(
            onPressed: () => _setTutorialPreference(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: const Text("No, Skip Tutorial"),
          ),
        ],
      ),
    );
  }
}

// Future<bool> _askUserForTutorial() async {
//   if (!mounted) {
//     return false; // ✅ Ensure dialog is only shown if the widget is still active
//   }

//   return await showDialog(
//         context: context,
//         barrierDismissible:
//             false, // Prevent closing the dialog by tapping outside
//         builder: (BuildContext context) {
//           return AlertDialog(
//             title: const Text('Enable Tutorial?'),
//             content: const Text(
//                 'Is this your first time? Do you want to enable the tutorial?'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(false),
//                 child: const Text('No'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(true),
//                 child: const Text('Yes'),
//               ),
//             ],
//           );
//         },
//       ) ??
//       false;
// }

// Future<void> _checkTutorialStatus() async {
//   var settingsBox = await Hive.openBox('settingsBox');
//   bool? enableTutorial = settingsBox.get('enableTutorial');

//   // If the setting is not saved, ask the user
//   if (enableTutorial == null && !_dialogShown) {
//     _dialogShown = true; // Prevent multiple triggers
//     bool userWantsTutorial = await _askUserForTutorial();

//     // Save user preference
//     await settingsBox.put('enableTutorial', userWantsTutorial);

//     _checkAndStartTutorial();
//   }
// }
