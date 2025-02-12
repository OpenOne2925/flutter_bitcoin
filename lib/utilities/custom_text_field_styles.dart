import 'package:flutter/material.dart';

class CustomTextFieldStyles {
  static InputDecoration textFieldDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
    Color? borderColor, // Optional custom border color
  }) {
    final defaultBorderColor = Colors.grey.withAlpha((0.6 * 255).toInt());
    final focusedBorderColor = borderColor ?? Colors.blue;

    return InputDecoration(
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.auto, // Auto-floating label
      labelStyle: TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 14.0,
        color: Colors.grey.withAlpha((0.8 * 255).toInt()),
      ),
      filled: true,
      fillColor: Colors.black,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: defaultBorderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: focusedBorderColor, // Use custom or default border color
          width: 2.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: borderColor ?? defaultBorderColor, // Use custom or default
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2.0,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18.0,
        horizontal: 16.0,
      ),
    );
  }
}
