import 'package:flutter/material.dart';

class CustomTextFieldStyles {
  static InputDecoration textFieldDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior:
          FloatingLabelBehavior.auto, // Label floats only when focused
      labelStyle: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: Colors.orange, // Blackish color for better visibility
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.bold,
        color: Colors.orange, // Orange floating label when focused
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 14.0,
        color: Colors.grey.withAlpha(
            (0.8 * 255).toInt()), // Subtle grey hint for better contrast
      ),
      filled: true,
      fillColor: Colors.black, // Neutral white background for better contrast
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0), // Smooth rounded corners
        borderSide: BorderSide(
          color:
              Colors.grey.withAlpha((0.6 * 255).toInt()), // Neutral grey border
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Colors.orange, // Orange border when focused
          width: 2.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: Colors.grey.withAlpha(
              (0.6 * 255).toInt()), // Neutral border for better readability
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Colors.red, // Red border for errors
          width: 2.0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18.0, // Balanced padding for text and labels
        horizontal: 16.0,
      ),
    );
  }
}
