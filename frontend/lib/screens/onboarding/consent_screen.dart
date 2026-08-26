import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/nav.dart';

/// Onboarding step 4 of 4 — consent. Business Flow §3 step 9: upgraded from
/// a single checkbox into a fuller trust screen, reflecting the sensitivity
/// of birth data and the brand's trust positioning.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  static const _points = <_TrustPoint>[
    _TrustPoint(
      Icons.lock_outline,
      'Encrypted at rest',
      'Your birth details are stored AES-256 encrypted — never in plain text.',
    ),
    _TrustPoint(
      Icons.auto_awesome_outlined,
      'Used only to cast your chart',
      'Name, date, time and place feed the ephemeris that generates your '
          'personal Kundli — nothing else.',
    ),
    _TrustPoint(
      Icons.block_outlined,
      'Never sold or shared',
      'Your data is never passed to third parties or used for advertising.',
    ),
    _TrustPoint(
      Icons.delete_outline,
      'Yours to remove',
      'Export or permanently delete your data at any time from Profile → Privacy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Your Trust',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldMeter,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Step 4 of 4', style: AppText.microLabel),
          const SizedBox(height: AppSpacing.xl),
          Text('Before we cast your chart', style: AppText.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Birth-time astrology depends on genuinely personal data. Here '
            "is exactly how we protect it, before you say yes.",
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.section),
          for (final p in _points) ...[
            _TrustRow(point: p),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            onTap: () => setState(() => _agreed = !_agreed),
            borderColor: _agreed ? AppColors.gold : AppColors.borderFaint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _agreed ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _agreed ? AppColors.gold : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'I agree that my birth details will be used to generate '
                    'my personal chart, stored securely as described above.',
                    style: AppText.sans(
                        size: 13, color: AppColors.textCream, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          GoldButton(
            label: 'AGREE & CONTINUE',
            icon: Icons.arrow_forward,
            onPressed: _agreed ? () => goToCalculating(context) : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _TrustPoint {
  const _TrustPoint(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.point});
  final _TrustPoint point;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconChip(child: Icon(point.icon, size: 18, color: AppColors.gold)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point.title, style: AppText.cardTitle),
              const SizedBox(height: 2),
              Text(point.body, style: AppText.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
