import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// Auspicious Time Windows — pushed detail screen. Lists today's favourable
/// muhurats plus the inauspicious Rahu Kaal to avoid. Data mocked inline.
class TimeWindowsScreen extends StatelessWidget {
  const TimeWindowsScreen({super.key});

  // ponytail: no interactivity in the spec → StatelessWidget, const data.
  static const List<_Window> _windows = [
    _Window(
      range: '11:48 AM – 12:36 PM',
      name: 'Abhijit Muhurat',
      note: 'The victorious midday window — Sun at its zenith.',
      activities: ['Meetings', 'Signing', 'Travel', 'Payments'],
    ),
    _Window(
      range: '01:30 PM – 03:06 PM',
      name: 'Amrit Kaal',
      note: 'Nectar hour favouring growth and new beginnings.',
      activities: ['Payments', 'Meetings', 'Travel'],
    ),
    _Window(
      range: '05:12 PM – 06:00 PM',
      name: 'Godhuli Bela',
      note: 'Dusk twilight — gentle, grounding, good for closure.',
      activities: ['Signing', 'Travel'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Auspicious Windows',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('AVOID THIS PERIOD'),
          const SizedBox(height: AppSpacing.md),
          _rahuKaalCard(),
          const SizedBox(height: AppSpacing.section),
          const SectionLabel('FAVOURABLE MUHURATS'),
          const SizedBox(height: AppSpacing.md),
          Text('Today\'s Green Lights',
              style: AppText.serif(size: 24, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xl),
          for (final w in _windows) ...[
            _WindowCard(window: w),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  Widget _rahuKaalCard() {
    return GlassCard(
      fill: AppColors.critical,
      fillOpacity: 0.18,
      borderColor: AppColors.criticalText.withValues(alpha: 0.4),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                size: 40,
                child: Icon(Icons.warning_amber_rounded,
                    size: 22, color: AppColors.criticalText),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Rahu Kaal',
                    style: AppText.serif(
                        size: 24, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.critical,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('AVOID',
                    style: AppText.sans(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.criticalBg,
                      letterSpacing: 1.0,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('09:00 – 10:30 AM',
              style: AppText.serif(
                size: 32,
                weight: FontWeight.w700,
                color: AppColors.criticalText,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The shadow planet clouds judgement. Hold off on new ventures, '
            'signings and negotiations during this window.',
            style: AppText.sans(
                size: 14, color: AppColors.textTan, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _Window {
  const _Window({
    required this.range,
    required this.name,
    required this.note,
    required this.activities,
  });

  final String range;
  final String name;
  final String note;
  final List<String> activities;
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window});

  final _Window window;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      borderColor: AppColors.surfaceRaised3,
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_twilight, size: 18, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(window.range,
                    style: AppText.serif(
                      size: 20,
                      weight: FontWeight.w700,
                      color: AppColors.gold,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(window.name,
              style: AppText.serif(size: 18, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(window.note,
              style: AppText.sans(
                  size: 13, color: AppColors.textTan, height: 1.5)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in window.activities) _activityChip(a),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.goldBorderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 13, color: AppColors.goldLight),
          const SizedBox(width: AppSpacing.xs),
          Text(label,
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.goldLighter,
              )),
        ],
      ),
    );
  }
}
