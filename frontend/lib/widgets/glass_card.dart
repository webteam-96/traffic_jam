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
    this.radius = AppRadius.lg,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fill.withValues(alpha: (fillOpacity + 0.06).clamp(0.0, 1.0)),
            fill.withValues(alpha: fillOpacity),
          ],
        ),
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

    // Soft floating shadow so cards read as raised above the backdrop
    // rather than flush with it — same navy/black already used elsewhere
    // (e.g. the Home FAB), just applied here too.
    card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgDeepest.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: card,
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
