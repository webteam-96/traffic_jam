import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';

/// "Color & Energy of the Day" — a pushed (non-tab) detail screen.
/// A hero swatch, the ruling planet, a serif reading, and the reasoning card.
/// All data mocked inline; nothing is interactive → StatelessWidget.
/// (ponytail: no state = no StatefulWidget.)
class ColorOfDayScreen extends StatelessWidget {
  const ColorOfDayScreen({super.key});

  static const Color _skyBlue = Color(0xFF87CEEB);
  static const String _colorName = 'Sky Blue';
  static const String _hex = '#87CEEB';
  static const String _planet = 'Mercury';
  static const String _reading =
      'Improves clarity and communication today.';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Color of the Day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SectionLabel("TODAY'S COLOUR & ENERGY")),
          const SizedBox(height: AppSpacing.xxl),
          _swatch(),
          const SizedBox(height: AppSpacing.xl),
          Center(child: _planetChip()),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _reading,
            textAlign: TextAlign.center,
            style: AppText.serif(
              size: 22,
              color: AppColors.textCream,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          _whyCard(),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'Share',
            outlined: true,
            icon: Icons.share,
            onPressed: () => toast(context, 'Shared to your story'),
          ),
        ],
      ),
    );
  }

  // ── Hero swatch ──────────────────────────────────────────────────────────
  Widget _swatch() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _skyBlue,
            _skyBlue.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(color: AppColors.goldBorderSoft),
        boxShadow: [
          BoxShadow(
            color: _skyBlue.withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _colorName,
            style: AppText.serif(
              size: 34,
              weight: FontWeight.w700,
              color: AppColors.bgDeepest,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _hex,
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.bgDeepest.withValues(alpha: 0.6),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ruling planet chip ───────────────────────────────────────────────────
  Widget _planetChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Ruled by $_planet',
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.goldLight,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Why this colour ──────────────────────────────────────────────────────
  Widget _whyCard() {
    return GlassCard(
      goldTopBorder: true,
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.55,
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WHY THIS COLOUR'),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Mercury governs the day and rules the intellect, speech and '
            'exchange of ideas. Sky Blue carries its cool, airy vibration — '
            'wearing or surrounding yourself with it steadies the mind and '
            'keeps conversations clear.',
            style: AppText.sans(
              size: 14,
              color: AppColors.textTan,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.surfaceRaised3, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Favour it for meetings, writing, negotiations and any task that '
            'rewards a clear head.',
            style: AppText.sans(
              size: 14,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
