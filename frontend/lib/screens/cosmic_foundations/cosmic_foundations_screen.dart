import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_assets.dart';
import '../../widgets/widgets.dart';
import '../../nav.dart';

/// Cosmic Foundations landing page — reachable from the top-bar button
/// (see AppTopBar/AppShell), not embedded in Home anymore. The 6-card grid
/// here is unchanged from Home's old inline section; only its home is new.
class CosmicFoundationsScreen extends StatelessWidget {
  const CosmicFoundationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Cosmic Foundations',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The building blocks of Vedic astrology — signs, planets, '
            'houses, elements, nakshatras, and yogas.',
            style: AppText.sans(size: 14, color: AppColors.textTan, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.section),
          for (int r = 0; r < _foundations.length; r += 2) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _card(context, _foundations[r])),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _card(context, _foundations[r + 1])),
                ],
              ),
            ),
            if (r + 2 < _foundations.length) const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, _FoundationItem f) => GlassCard(
        radius: AppRadius.lg,
        borderColor: AppColors.borderSoft,
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        onTap: () => f.onTap(context),
        child: Column(
          children: [
            IconChip(
              size: 64,
              circular: true,
              glow: true,
              child: SvgIcon(f.icon, size: f.iconSize, color: AppColors.gold),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(f.title, textAlign: TextAlign.center, style: AppText.headingSerif),
            const SizedBox(height: AppSpacing.sm),
            Text(f.subtitle,
                textAlign: TextAlign.center,
                style: AppText.microLabel.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
}

class _FoundationItem {
  const _FoundationItem(this.icon, this.title, this.subtitle, this.iconSize, this.onTap);
  final String icon;
  final String title;
  final String subtitle;
  final double iconSize;
  final void Function(BuildContext) onTap;
}

const _foundations = [
  _FoundationItem(Assets.iconZodiac, '12 Zodiac Signs', 'Discover your core identity.', 25, goToZodiacSigns),
  _FoundationItem(Assets.iconPlanets, '9 Planets', 'The celestial influencers.', 28, goToPlanets),
  _FoundationItem(Assets.iconHouses, '12 Houses', 'Areas of life experience.', 22, goToHouses),
  _FoundationItem(Assets.iconElements, '5 Elements', 'The energetic makeup.', 24, goToElements),
  _FoundationItem(Assets.iconNakshatras, '27 Nakshatras', 'The lunar mansions.', 27, goToNakshatras),
  _FoundationItem(Assets.iconYog, 'Yog in Astrology', 'Powerful cosmic pairings.', 22, goToYog),
];
