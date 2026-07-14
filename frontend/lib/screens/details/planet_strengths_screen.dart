import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// Planet Strengths & Life Themes — in-theme pushed screen (no Figma frame).
/// A 9-planet vertical bar chart (Shadbala-style) with benefic/malefic hints,
/// an overall strength meter, and a "Life Themes" list. All data mocked const.
class PlanetStrengthsScreen extends StatelessWidget {
  const PlanetStrengthsScreen({super.key});

  static const _planets = <_Planet>[
    _Planet('Su', 'Sun', 0.68, false),
    _Planet('Mo', 'Moon', 0.85, true),
    _Planet('Ma', 'Mars', 0.57, false),
    _Planet('Me', 'Mercury', 0.71, true),
    _Planet('Ju', 'Jupiter', 0.92, true),
    _Planet('Ve', 'Venus', 0.79, true),
    _Planet('Sa', 'Saturn', 0.46, false),
    _Planet('Ra', 'Rahu', 0.34, false),
    _Planet('Ke', 'Ketu', 0.41, false),
  ];

  static const _themes = <_Theme>[
    _Theme(Icons.workspace_premium, 'Career', 'Leadership & recognition'),
    _Theme(Icons.savings_outlined, 'Wealth', 'Steady accumulation'),
    _Theme(Icons.favorite_border, 'Relationships', 'Deep, enduring loyalty'),
    _Theme(Icons.spa_outlined, 'Health', 'Resilient vitality'),
    _Theme(Icons.self_improvement, 'Spirituality', 'Inner awakening'),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Planet Strengths',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('SHADBALA ANALYSIS'),
          const SizedBox(height: AppSpacing.md),
          Text('Planetary Power',
              style: AppText.serif(
                  size: 28,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Relative strength of the nine grahas in your natal chart, and the '
            'life themes they shape.',
            style: AppText.sans(
                size: 15, color: AppColors.textTan, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _chartCard(),
          const SizedBox(height: AppSpacing.section),
          Text('Life Themes',
              style: AppText.serif(size: 24, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
          for (final t in _themes) ...[
            _themeRow(t),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  // ── Bar chart ────────────────────────────────────────────────────────────
  Widget _chartCard() {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in _planets) Expanded(child: _bar(p)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(color: AppColors.surfaceRaised3, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _legend(AppColors.success, 'Benefic'),
              const SizedBox(width: AppSpacing.xl),
              _legend(AppColors.critical, 'Malefic'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const MeterBar(label: 'Overall Chart Strength', value: 0.74),
        ],
      ),
    );
  }

  Widget _bar(_Planet p) {
    const trackH = 128.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${(p.strength * 100).round()}',
            style: AppText.sans(
                size: 10,
                weight: FontWeight.w600,
                color: AppColors.goldLighter)),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: trackH,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 11,
              height: trackH * p.strength,
              decoration: BoxDecoration(
                gradient: AppColors.goldMeter,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.25),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(p.abbr,
            style: AppText.sans(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: p.benefic ? AppColors.success : AppColors.critical,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppText.sans(size: 12, color: AppColors.textTan)),
      ],
    );
  }

  // ── Life theme row ───────────────────────────────────────────────────────
  Widget _themeRow(_Theme t) {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          IconChip(
            child: Icon(t.icon, size: 20, color: AppColors.gold),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.category.toUpperCase(),
                    style: AppText.sans(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.gold,
                        letterSpacing: 1.1)),
                const SizedBox(height: AppSpacing.xs),
                Text(t.description,
                    style: AppText.serif(
                        size: 17, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 20, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _Planet {
  final String abbr;
  final String name;
  final double strength; // 0..1
  final bool benefic;
  const _Planet(this.abbr, this.name, this.strength, this.benefic);
}

class _Theme {
  final IconData icon;
  final String category;
  final String description;
  const _Theme(this.icon, this.category, this.description);
}
