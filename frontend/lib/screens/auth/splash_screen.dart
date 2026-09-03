import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// App launch / splash. Full-bleed cosmic backdrop, everything centered as
/// one block: the orbiting moon-and-planet loader, the wordmark, a tagline.
/// The orbit animation itself is the loading indicator — no separate spinner.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // SizedBox.expand forces the body to fill (else the Column shrink-wraps
      // and the gradient only covers part of the screen).
      body: SizedBox.expand(
        child: CosmicBackground(
          child: SafeArea(
            // CosmicBackground's Stack uses the default StackFit.loose, so a
            // plain Center (or a bare Column) shrink-wraps to its content
            // instead of filling the available space, and Stack then
            // top/left-aligns that shrunk box — content ends up pinned near
            // the top-left rather than centered (this is what pinned the
            // title to the left edge). SizedBox.expand forces tight,
            // full-size constraints regardless of the Stack's loose fit —
            // same trick already used one level up for CosmicBackground
            // itself — so Center underneath it has real bounds to center
            // precisely within, both axes.
            child: SizedBox.expand(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const OrbitLoader(size: 140),
                    const SizedBox(height: AppSpacing.section),
                    Text(
                      'TRAFFIC JAM',
                      textAlign: TextAlign.center,
                      style: AppText.logoFont(
                        size: 28,
                        color: AppColors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your daily astro-signal',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
