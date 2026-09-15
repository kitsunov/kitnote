import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isSelected;
  final Color? color;
  final Color? selectedColor;
  final double size;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isSelected = false,
    this.color,
    this.selectedColor,
    this.size = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBg = selectedColor != null
        ? selectedColor!.withValues(alpha: 0.15)
        : theme.colorScheme.primary.withValues(alpha: 0.12);
    final activeIconColor = selectedColor ?? theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: size,
              color: isSelected ? activeIconColor : (color ?? theme.iconTheme.color),
            ),
          ),
        ),
      ),
    );
  }
}
