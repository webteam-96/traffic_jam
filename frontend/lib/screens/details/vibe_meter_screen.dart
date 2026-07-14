import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Astro Vibe Meter — three domain readings (Focus / Money / Relationships).
/// Pushed detail screen. Data mocked inline; no interactivity → stateless.
class VibeMeterScreen extends StatelessWidget {
  const VibeMeterScreen({super.key});

  static const List<_Domain> _domains = [
    _Domain(
      icon: Icons.center_focus_strong_rounded,
      title: 'Focus',
      value: 0.94,
      blurb: 'Cognitive clarity is high — tackle deep work.',
    ),
    _Domain(
      icon: Icons.savings_rounded,
      title: 'Money',
      value: 0.76,
      blurb: 'Steady flow — a good day to plan, not splurge.',
    ),
    _Domain(
      icon: Icons.favorite_rounded,
      title: 'Relationships',
      value: 0.61,
      blurb: 'Warm but tender — lead with patience.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Vibe Meter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel("TODAY'S ALIGNMENT"),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your cosmic energy across the day, by domain.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final d in _domains) ...[
            _DomainCard(domain: d),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _Domain {
  const _Domain({
    required this.icon,
    required this.title,
    required this.value,
    required this.blurb,
  });

  final IconData icon;
  final String title;
  final double value; // 0..1
  final String blurb;
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain});

  final _Domain domain;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      goldTopBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconChip(
                glow: true,
                child: Icon(domain.icon, size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(domain.title, style: AppText.cardTitle),
              ),
              Text(
                '${(domain.value * 100).round()}%',
                style: AppText.serif(
                  size: 40,
                  weight: FontWeight.w700,
                  color: AppColors.gold,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MeterBar(label: 'Alignment', value: domain.value),
          const SizedBox(height: AppSpacing.md),
          Text(domain.blurb, style: AppText.bodySmall),
        ],
      ),
    );
  }
}
