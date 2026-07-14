import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Frosted translucent card — the app's signature surface.
/// Figma: backdrop-blur 6px, fill rgba(31,37,85,0.4), border white 8–10%,
/// radius 12–16. Optional gold top-border accent (Today's Panchang card).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    this.radius = AppRadius.md,
    this.borderColor = AppColors.borderFaint,
    this.fill = AppColors.surface,
    this.fillOpacity = 0.4,
    this.goldTopBorder = false,
    this.blur = 6,
    this.width,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final Color fill;
  final double fillOpacity;
  final bool goldTopBorder;
  final double blur;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = goldTopBorder
        ? Border(
            top: const BorderSide(color: AppColors.amber, width: 2),
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          )
        : Border.all(color: borderColor);

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: fill.withValues(alpha: fillOpacity),
            borderRadius: BorderRadius.circular(radius),
            border: border,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: card,
        ),
      );
    }
    return card;
  }
}
