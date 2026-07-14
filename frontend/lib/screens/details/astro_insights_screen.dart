import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Personal Astro Insights — running dasha, planetary transits, weekly energy.
/// Pushed detail screen. All data mocked inline; no interactivity → stateless.
class AstroInsightsScreen extends StatelessWidget {
  const AstroInsightsScreen({super.key});

  static const List<_PlanetEvent> _events = [
    _PlanetEvent(
      icon: Icons.brightness_3,
      title: 'Mars transiting 8th from Moon',
      note: 'Guard your temper — channel the heat into a workout, not an argument.',
    ),
    _PlanetEvent(
      icon: Icons.wb_sunny_outlined,
      title: 'Sun conjunct natal Mercury',
      note: 'Sharp thinking and clear speech — a strong day to negotiate.',
    ),
    _PlanetEvent(
      icon: Icons.auto_awesome,
      title: 'Jupiter aspecting 5th house',
      note: 'Creativity and luck favour learning; start something you have delayed.',
    ),
  ];

  // Mon..Sun energy, 0..1. ponytail: static mock, wire to ephemeris later.
  static const List<_DayEnergy> _week = [
    _DayEnergy('Mon', 0.55),
    _DayEnergy('Tue', 0.72),
    _DayEnergy('Wed', 0.40),
    _DayEnergy('Thu', 0.88),
    _DayEnergy('Fri', 0.66),
    _DayEnergy('Sat', 0.50),
    _DayEnergy('Sun', 0.78),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Astro Insights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('YOUR SKY, RIGHT NOW'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A personal read on the cycles and transits shaping your week.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Card 1: Current dasha ──────────────────────────────────────
          GlassCard(
            goldTopBorder: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('CURRENT DASHA'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Venus Mahadasha',
                  style: AppText.serif(size: 26, weight: FontWeight.w700),
                ),
                Text(
                  'Mercury Antardasha',
                  style: AppText.serifValue.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'A period that blends Venus’ grace with Mercury’s wit. '
                  'Relationships, art and commerce all get a lift — pursue '
                  'collaborations and voice the ideas you have been holding back.',
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Card 2: Planetary events ───────────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('PLANETARY EVENTS'),
                const SizedBox(height: AppSpacing.lg),
                for (int i = 0; i < _events.length; i++) ...[
                  _EventRow(event: _events[i]),
                  if (i != _events.length - 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.borderFaint, height: 1),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Card 3: Weekly energy forecast ─────────────────────────────
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('WEEKLY ENERGY FORECAST'),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 132,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in _week)
                        Expanded(child: _EnergyBar(day: d)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetEvent {
  const _PlanetEvent({
    required this.icon,
    required this.title,
    required this.note,
  });

  final IconData icon;
  final String title;
  final String note;
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final _PlanetEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconChip(
          child: Icon(event.icon, size: 20, color: AppColors.gold),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: AppText.cardTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(event.note, style: AppText.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayEnergy {
  const _DayEnergy(this.label, this.value);
  final String label;
  final double value; // 0..1
}

class _EnergyBar extends StatelessWidget {
  const _EnergyBar({required this.day});

  final _DayEnergy day;

  static const double _maxBar = 96;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${(day.value * 100).round()}',
          style: AppText.sans(
            size: 10,
            weight: FontWeight.w600,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 14,
          height: (_maxBar * day.value).clamp(6, _maxBar),
          decoration: BoxDecoration(
            gradient: AppColors.goldMeter,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: AppColors.amber.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          day.label,
          style: AppText.sans(
            size: 11,
            weight: FontWeight.w500,
            color: AppColors.textTan,
          ),
        ),
      ],
    );
  }
}
