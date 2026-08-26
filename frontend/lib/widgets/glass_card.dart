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
    this.onLongPress,
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
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // NOTE: a Border with a different color per side cannot be combined with
    // borderRadius (Flutter's box painter throws "borderRadius can only be
    // given on borders with uniform colors"). So the gold "top border" accent
    // is drawn as a separate 2px strip inside the ClipRRect instead of as a
    // non-uniform Border — visually identical, but actually renders.
    final content = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: fill.withValues(alpha: fillOpacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: goldTopBorder
            ? Stack(
                children: [
                  content,
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: AppColors.amber),
                  ),
                ],
              )
            : content,
      ),
    );

    if (onTap != null || onLongPress != null) {
      card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: card,
        ),
      );
    }
    return card;
  }
}
