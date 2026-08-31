import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-bleed indigo gradient backdrop used behind every screen body.
/// Matches the Figma "Html → Body" navy fill with a touch of vertical depth,
/// plus a faint top-center gold aura for ambient warmth — same palette,
/// just layered instead of flat.
class CosmicBackground extends StatelessWidget {
  const CosmicBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.scaffoldGradient),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            left: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.05),
                      AppColors.gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
