import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/theme/app_assets.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// App launch / splash. Full-bleed cosmic backdrop with the logo in a soft
/// gold glow, the wordmark, a tagline, and a small progress indicator.
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 48,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(figmaAsset(Assets.logo), width: 72),
                ),
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
                const Spacer(),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
