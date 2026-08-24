import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Upcoming Major Transits — §8 of Business Flow.
/// Chronological list of significant planetary events over ~3 months, personalised to user's chart.
class UpcomingTransitsScreen extends StatelessWidget {
  const UpcomingTransitsScreen({super.key});

  static const List<_TransitEvent> _events = [
    _TransitEvent(
      date: 'Aug 26, 2026',
      planet: 'Saturn',
      event: 'Retrograde begins in Pisces',
      house: '12th from Lagna',
      interpretation:
          'A 4.5-month review of spiritual debts, subconscious patterns, and hidden '
          'enemies. Old karmic themes resurface for resolution. Avoid new long-term '
          'commitments in foreign lands or institutions.',
      severity: _Severity.high,
      icon: Icons.brightness_3,
    ),
    _TransitEvent(
      date: 'Sep 4, 2026',
      planet: 'Jupiter',
      event: 'Enters Gemini',
      house: '3rd from Moon',
      interpretation:
          'Expansion through communication, learning, and short travel. Siblings and '
          'neighbors become sources of opportunity. Excellent period for writing, '
          'teaching, or launching a newsletter/podcast.',
      severity: _Severity.benefic,
      icon: Icons.wb_sunny_outlined,
    ),
    _TransitEvent(
      date: 'Sep 18, 2026',
      planet: 'Mercury',
      event: 'Retrograde in Virgo',
      house: '6th from Lagna',
      interpretation:
          'Review daily routines, health protocols, and work processes. Avoid signing '
          'contracts or launching tech products. Backup data; double-check communications.',
      severity: _Severity.moderate,
      icon: Icons.auto_awesome,
    ),
    _TransitEvent(
      date: 'Oct 7, 2026',
      planet: 'Sun',
      event: 'Solar Eclipse in Virgo',
      house: '6th from Moon',
      interpretation:
          'A powerful reset for health, service, and work-life boundaries. Something '
          'ends to make space for a more authentic routine. Effects felt 6 months prior '
          'and 6 months post.',
      severity: _Severity.high,
      icon: Icons.wb_sunny_outlined,
    ),
    _TransitEvent(
      date: 'Oct 22, 2026',
      planet: 'Mars',
      event: 'Enters Cancer (Debilitated)',
      house: '4th from Lagna',
      interpretation:
          'Mars in fall triggers domestic tension and emotional reactivity. Property '
          'matters and mother-figure relationships need patience. Channel energy into '
          'home improvement, not arguments.',
      severity: _Severity.challenging,
      icon: Icons.local_fire_department,
    ),
    _TransitEvent(
      date: 'Nov 11, 2026',
      planet: 'Venus',
      event: 'Enters Sagittarius',
      house: '9th from Moon',
      interpretation:
          'Love, beauty, and finances expand through higher learning, travel, or '
          'philosophical alignment. Attraction to foreign cultures or spiritual partners '
          'increases. Favorable for creative publishing.',
      severity: _Severity.benefic,
      icon: Icons.favorite_outline,
    ),
    _TransitEvent(
      date: 'Nov 25, 2026',
      planet: 'Rahu–Ketu',
      event: 'Transit axis shift (Rahu to Pisces, Ketu to Virgo)',
      house: 'Rahu in 12th / Ketu in 6th',
      interpretation:
          '18-month cycle begins: spiritual dissolution (Rahu in 12th) meets service '
          'refinement (Ketu in 6th). Past-life karma around isolation vs. usefulness '
          'activates. Watch for health anxieties and psychic openings.',
      severity: _Severity.high,
      icon: Icons.auto_awesome,
    ),
    _TransitEvent(
      date: 'Dec 15, 2026',
      planet: 'Jupiter',
      event: 'Retrograde in Gemini',
      house: '3rd from Moon',
      interpretation:
          'Internal review of beliefs, communication style, and learning methods. '
          'Revisit abandoned studies or rewrite old content. Avoid over-promising in '
          'negotiations until direct station.',
      severity: _Severity.moderate,
      icon: Icons.wb_sunny_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Upcoming Major Transits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('NEXT 90 DAYS'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Personalised planetary movements interpreted for your chart. '
            'Tap any event for details and to set a reminder.',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          for (int i = 0; i < _events.length; i++) ...[
            _TransitCard(event: _events[i]),
            if (i != _events.length - 1) const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _TransitEvent {
  const _TransitEvent({
    required this.date,
    required this.planet,
    required this.event,
    required this.house,
    required this.interpretation,
    required this.severity,
    required this.icon,
  });

  final String date;
  final String planet;
  final String event;
  final String house;
  final String interpretation;
  final _Severity severity;
  final IconData icon;
}

enum _Severity { benefic, moderate, challenging, high }

class _TransitCard extends StatelessWidget {
  const _TransitCard({required this.event});
  final _TransitEvent event;

  Color get _badgeColor {
    switch (event.severity) {
      case _Severity.benefic:
        return AppColors.success;
      case _Severity.moderate:
        return AppColors.amber;
      case _Severity.challenging:
        return AppColors.orange;
      case _Severity.high:
        return AppColors.critical;
    }
  }

  String get _badgeLabel {
    switch (event.severity) {
      case _Severity.benefic:
        return 'FAVOURABLE';
      case _Severity.moderate:
        return 'NEUTRAL';
      case _Severity.challenging:
        return 'CHALLENGING';
      case _Severity.high:
        return 'CRITICAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => _showDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(
                size: 40,
                child: Icon(event.icon, size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(event.date,
                            style: AppText.sans(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.textMuted)),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: _badgeColor),
                          ),
                          child: Text(_badgeLabel,
                              style: AppText.sans(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: _badgeColor,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('$event.planet: $event.event',
                        style: AppText.cardTitle),
                    Text(event.house,
                        style: AppText.sans(
                            size: 12,
                            color: AppColors.textTan,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(event.interpretation, style: AppText.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _setReminder(context),
              icon: const Icon(Icons.notifications_none, size: 16),
              label: Text('Set Reminder',
                  style: AppText.sans(
                      size: 13, weight: FontWeight.w600, color: AppColors.gold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransitDetailSheet(event: event),
    );
  }

  void _setReminder(BuildContext context) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Reminder set for ${event.date}',
          style: AppText.sans(size: 14, color: AppColors.textPrimary)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceRaised2,
      duration: const Duration(seconds: 2),
    ));
  }
}

class _TransitDetailSheet extends StatelessWidget {
  const _TransitDetailSheet({required this.event});
  final _TransitEvent event;

  String _badgeLabelForEvent(_TransitEvent e) {
    switch (e.severity) {
      case _Severity.benefic:
        return 'FAVOURABLE';
      case _Severity.moderate:
        return 'NEUTRAL';
      case _Severity.challenging:
        return 'CHALLENGING';
      case _Severity.high:
        return 'CRITICAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.borderSoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconChip(
                          size: 48,
                          child: Icon(event.icon, size: 24, color: AppColors.gold),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.planet,
                                  style: AppText.serif(
                                      size: 24, weight: FontWeight.w700)),
                              Text(event.event,
                                  style: AppText.sans(
                                      size: 14, color: AppColors.amber)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailRow('Date', event.date),
                    _DetailRow('House Activation', event.house),
                    _DetailRow('Impact Level', _badgeLabelForEvent(event)),
                    const SizedBox(height: AppSpacing.lg),
                    const SectionLabel('PERSONAL INTERPRETATION'),
                    const SizedBox(height: AppSpacing.md),
                    Text(event.interpretation, style: AppText.body),
                    const SizedBox(height: AppSpacing.xl),
                    GoldButton(
                      label: 'SET REMINDER',
                      icon: Icons.notifications,
                      onPressed: () {
                        Navigator.pop(context);
                        _setReminder(context);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setReminder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Reminder set for ${event.date}',
          style: AppText.sans(size: 14, color: AppColors.textPrimary)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceRaised2,
      duration: const Duration(seconds: 2),
    ));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppText.sans(
                    size: 13, color: AppColors.textMuted, letterSpacing: 0.5)),
          ),
          Expanded(
            child: Text(value,
                style: AppText.sans(
                    size: 13, weight: FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}