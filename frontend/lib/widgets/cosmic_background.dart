import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-bleed indigo gradient backdrop used behind every screen body.
/// Matches the Figma "Html → Body" navy fill with a touch of vertical depth.
class CosmicBackground extends StatelessWidget {
  const CosmicBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.scaffoldGradient),
      child: child,
    );
  }
}
