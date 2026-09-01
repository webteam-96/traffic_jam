import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/transit_api.dart';
import 'package:traffic_jam/data/planet_dignity.dart';

/// Upcoming Major Transits — §8 of Business Flow.
/// Each of Sun/Mars/Jupiter/Saturn/Rahu/Ketu's next sign change ("ingress"),
/// wired to GET /transits/upcoming — a real forward scan of the ephemeris
/// (see TransitEndpoints.cs), not a fixed list. Moon/Mercury/Venus change
/// sign too often to be a meaningful "upcoming event" and aren't included.
/// Severity is the classical dignity (see planet_dignity.dart) the planet
/// has in the sign it's entering — real, not invented per-event prose.
class UpcomingTransitsScreen extends StatefulWidget {
  const UpcomingTransitsScreen({super.key});

  @override
  State<UpcomingTransitsScreen> createState() => _UpcomingTransitsScreenState();
}

enum _Severity { benefic, moderate, challenging, high }

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

const _planetIcons = {
  'Sun': Icons.wb_sunny_outlined,
  'Mars': Icons.local_fire_department,
  'Jupiter': Icons.auto_awesome,
  'Saturn': Icons.brightness_3,
  'Rahu': Icons.blur_circular,
  'Ketu': Icons.blur_on,
};

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

_Severity _severityFor(String dignityLabel) => switch (dignityLabel) {
      'Exalted' || 'Own Sign' => _Severity.benefic,
      'Friendly Sign' => _Severity.moderate,
      'Neutral Sign' => _Severity.moderate,
      'Enemy Sign' => _Severity.challenging,
      'Debilitated' => _Severity.high,
      _ => _Severity.moderate,
    };

class _UpcomingTransitsScreenState extends State<UpcomingTransitsScreen> {
  List<_TransitEvent>? _events;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await TransitApi.getUpcoming();
      final events = raw.map((e) {
        final planet = e['planet'] as String;
        final toSign = e['toSign'] as String;
        final fromSign = e['fromSign'] as String;
        final date = DateTime.parse(e['date'] as String);
        final houseFromMoon = e['houseFromMoon'] as int;
        final houseFromLagna = e['houseFromLagna'] as int?;
        final toSignIndex = kSignNames.indexOf(toSign);
        final dignity = classicalDignity(planet, toSignIndex);
        final domain = kGrahaDomain[planet] ?? 'this area of life';

        return _TransitEvent(
          date: '${_months[date.month - 1]} ${date.day}, ${date.year}',
          planet: planet,
          event: 'Enters $toSign',
          house: houseFromLagna != null
              ? 'House $houseFromMoon from your Moon · House $houseFromLagna from your Lagna'
              : 'House $houseFromMoon from your Moon',
          interpretation: '$planet moves from $fromSign into $toSign, shifting energy '
              'around $domain. In $toSign, $planet is ${dignity.label.toLowerCase()} — '
              '${_dignityNote(dignity.label)}',
          severity: _severityFor(dignity.label),
          icon: _planetIcons[planet] ?? Icons.auto_awesome,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _events = events;
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

  String _dignityNote(String label) => switch (label) {
        'Exalted' => 'expect this transit to bring out its best.',
        'Own Sign' => 'a steady, self-assured expression of its energy.',
        'Friendly Sign' => 'a generally supportive, easier stretch.',
        'Neutral Sign' => 'a mixed period — outcomes depend on effort.',
        'Enemy Sign' => 'a more effortful stretch — patience helps.',
        'Debilitated' => 'a challenging placement — go gently here.',
        _ => 'a period worth watching.',
      };

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Upcoming Major Transits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WHAT\'S NEXT'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Each major graha's next sign change, read against your own chart.",
            style: AppText.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_errored || _events == null || _events!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Save your birth data to see your upcoming transits.',
                style: AppText.sans(size: 14, color: AppColors.textMuted),
              ),
            )
          else
            for (int i = 0; i < _events!.length; i++) ...[
              _TransitCard(event: _events![i]),
              if (i != _events!.length - 1) const SizedBox(height: AppSpacing.md),
            ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

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
                    Text('${event.planet}: ${event.event}',
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
