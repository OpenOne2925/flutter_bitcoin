import 'package:flutter/material.dart';

class InkwellButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? iconColor;
  final double borderRadius;

  const InkwellButton({
    super.key,
    required this.onTap,
    required this.label,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.iconColor,
    this.borderRadius = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Card(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 4.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  color: iconColor ?? textColor,
                  size: 24,
                ),
              if (icon != null) const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
