import 'package:flutter/material.dart';

import '../theme/urban_theme.dart';

class UrbanBrand extends StatelessWidget {
  const UrbanBrand({super.key, this.fontSize = 18, this.showName = true});

  final double fontSize;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/img/logo-urban-studio.jpg',
            width: fontSize + 7,
            height: fontSize + 7,
            fit: BoxFit.cover,
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 8),
          Text(
            'urban studio',
            style: TextStyle(
              color: UrbanColors.gold,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class UrbanEyebrow extends StatelessWidget {
  const UrbanEyebrow(this.text, {super.key, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: UrbanColors.gold,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 3.4,
      ),
    );
  }
}

class UrbanGoldButton extends StatelessWidget {
  const UrbanGoldButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label.toUpperCase()),
      style: FilledButton.styleFrom(
        backgroundColor: UrbanColors.gold,
        foregroundColor: UrbanColors.background,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: child) : child;
  }
}
