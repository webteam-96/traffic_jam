import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../services/chart_api.dart';
import '../../data/planet_dignity.dart';

/// Planet Strengths & Life Themes — a 9-planet bar chart of each graha's
/// classical sign dignity (exalted/own/friendly/neutral/enemy/debilitated —
/// see planet_dignity.dart) computed from the real natal D1 chart, plus a
/// Life Themes list templated off the relevant significator's dignity.
///
/// This is a simplified, sign-level strength read, not full Shadbala
/// (Sthana/Dig/Kala/Cheshta/Naisargika/Drik Bala) — that needs house/time/
/// aspect inputs this screen doesn't compute. Labelling it "Shadbala" would
/// overclaim precision the data doesn't have.
class PlanetStrengthsScreen extends StatefulWidget {
  const PlanetStrengthsScreen({super.key});

  @override
  State<PlanetStrengthsScreen> createState() => _PlanetStrengthsScreenState();
}

class _Planet {
  final String abbr;
  final String name;
  final double strength; // 0..1
  final String dignityLabel;
  final bool benefic;
  const _Planet(this.abbr, this.name, this.strength, this.dignityLabel, this.benefic);
}

class _Theme {
  final IconData icon;
  final String category;
  final String description;
  const _Theme(this.icon, this.category, this.description);
}

class _PlanetStrengthsScreenState extends State<PlanetStrengthsScreen> {
  static const _abbr = {
    'Sun': 'Su', 'Moon': 'Mo', 'Mars': 'Ma', 'Mercury': 'Me', 'Jupiter': 'Ju',
    'Venus': 'Ve', 'Saturn': 'Sa', 'Rahu': 'Ra', 'Ketu': 'Ke',
  };
  // Natural benefic/malefic classification (Moon assumed waxing — see
  // Cosmic Foundations → 9 Planets for the general rule).
  static const _naturalBenefics = {'Moon', 'Mercury', 'Jupiter', 'Venus'};

  List<_Planet>? _planets;
  List<_Theme>? _themes;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final chart = await ChartApi.getChart();
      final d1 = (chart['d1'] as List).cast<Map<String, dynamic>>();
      final dignityByPlanet = <String, Dignity>{};
      final planets = <_Planet>[];
      for (final abbrEntry in _abbr.entries) {
        final name = abbrEntry.key;
        final row = d1.where((p) => p['planet'] == name).firstOrNull;
        if (row == null) continue;
        final signIndex = row['signIndex'] as int;
        final dignity = classicalDignity(name, signIndex);
        dignityByPlanet[name] = dignity;
        planets.add(_Planet(
          abbrEntry.value, name, dignity.strength, dignity.label,
          _naturalBenefics.contains(name),
        ));
      }
      final themes = [
        _themeFor(Icons.workspace_premium, 'Career', 'Sun', dignityByPlanet),
        _themeFor(Icons.savings_outlined, 'Wealth', 'Jupiter', dignityByPlanet),
        _themeFor(Icons.favorite_border, 'Relationships', 'Venus', dignityByPlanet),
        _themeFor(Icons.spa_outlined, 'Health', 'Mars', dignityByPlanet),
        _themeFor(Icons.self_improvement, 'Spirituality', 'Ketu', dignityByPlanet),
      ];
      if (!mounted) return;
      setState(() {
        _planets = planets;
        _themes = themes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errored = true;
      });
    }
  }

  _Theme _themeFor(IconData icon, String category, String significator,
      Map<String, Dignity> dignities) {
    final dignity = dignities[significator];
    final domain = kGrahaDomain[significator] ?? '';
    if (dignity == null) {
      return _Theme(icon, category, 'Save your birth data to see this reading.');
    }
    final desc = switch (dignity.label) {
      'Exalted' => 'Exceptionally favoured — expect strong results in $domain.',
      'Own Sign' => 'Solidly placed — steady, self-reliant strength in $domain.',
      'Friendly Sign' => 'Well supported — a gentle lift in $domain.',
      'Neutral Sign' => 'Mixed footing — $domain unfolds gradually, with effort.',
      'Enemy Sign' => 'Under some strain — $domain calls for extra patience.',
      'Debilitated' => 'Weakly placed — $domain needs conscious, sustained work.',
      _ => domain,
    };
    return _Theme(icon, category, desc);
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Planet Strengths',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('DIGNITY ANALYSIS'),
          const SizedBox(height: AppSpacing.md),
          Text('Planetary Power',
              style: AppText.serif(
                  size: 28,
                  weight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Classical sign dignity of the nine grahas in your natal chart, and the '
            'life themes they shape.',
            style: AppText.sans(
                size: 15, color: AppColors.textTan, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_errored || _planets == null || _planets!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Save your birth data to see your planetary strengths.',
                style: AppText.sans(size: 14, color: AppColors.textMuted),
              ),
            )
          else ...[
            _chartCard(_planets!),
            const SizedBox(height: AppSpacing.section),
            Text('Life Themes',
                style: AppText.serif(size: 24, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            for (final t in _themes!) ...[
              _themeRow(t),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
    );
  }

  // ── Bar chart ────────────────────────────────────────────────────────────
  Widget _chartCard(List<_Planet> planets) {
    final overall = planets.map((p) => p.strength).reduce((a, b) => a + b) / planets.length;
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
              for (final p in planets) Expanded(child: _bar(p)),
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
          MeterBar(label: 'Overall Chart Strength', value: overall),
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
            child: Tooltip(
              message: p.dignityLabel,
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
