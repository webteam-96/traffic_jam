import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Onboarding welcome — introduces the Traffic Signal metaphor.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // ponytail: mock data inline, no backend for onboarding copy.
  static const _signals = <(Color, String, String)>[
    (AppColors.success, 'Go Ahead', 'The stars align — act with confidence.'),
    (AppColors.amber, 'Careful Moves', 'Proceed, but weigh each step.'),
    (AppColors.critical, 'Avoid Major Decisions', 'Hold off — let the day pass.'),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WELCOME TO TRAFFIC JAM'),
          const SizedBox(height: AppSpacing.md),
          Text('Your day,\ndecoded.',
              style: AppText.serif(size: 40, weight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Every day carries a cosmic signal. We read the sky and hand you a '
            'simple traffic light for your decisions.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          for (final (color, title, sub) in _signals) ...[
            _SignalRow(color: color, title: title, subtitle: sub),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.lg),
          GoldButton(
            label: 'DISCOVER YOUR DAY',
            icon: Icons.auto_awesome,
            onPressed: () => goToIdentity(context),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppText.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
