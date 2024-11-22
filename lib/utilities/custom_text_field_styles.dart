import 'package:flutter/material.dart';

class CustomTextFieldStyles {
  static InputDecoration textFieldDecoration({
    required BuildContext context,
    required String labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface, // Dynamic label color
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(), // Dynamic hint color
      ),
      filled: true,
      fillColor:
          Theme.of(context).colorScheme.surface, // Dynamic background color
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
        borderSide: const BorderSide(
          color: Colors.orange, // Border color when not focused
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
        borderSide: const BorderSide(
          color: Colors.orange, // Orange border when focused
          width: 2.0, // Thicker border when focused
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0), // Rounded corners
        borderSide: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(), // Grey border when not focused
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16.0,
        horizontal: 16.0,
      ),
    );
  }
}
