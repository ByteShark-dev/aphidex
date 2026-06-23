import 'package:flutter/material.dart';

class IconBadge extends StatelessWidget {
  final String assetName;
  final double size;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  const IconBadge.asset({
    super.key,
    required this.assetName,
    required this.size,
    this.padding = const EdgeInsets.all(5),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg =
        backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92)
            : const Color(0xFFE5E7EB));
    final border =
        borderColor ??
        (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12));

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border),
      ),
      child: Image.asset(
        assetName,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
