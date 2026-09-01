import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/chart_api.dart';
import 'package:traffic_jam/services/signal_api.dart';
import 'package:traffic_jam/data/planet_dignity.dart';

/// Personal Astro Insights — running Dasha, the real factors driving today's
/// Traffic Signal, and a real 7-day energy forecast (reusing GET
/// /signal/today's optional `date` param for each day ahead).
class AstroInsightsScreen extends StatefulWidget {
  const AstroInsightsScreen({super.key});

  @override
  State<AstroInsightsScreen> createState() => _AstroInsightsScreenState();
}

class _DayEnergy {
  const _DayEnergy(this.label, this.value);
  final String label;
  final double value; // 0..1
}

class _PlanetEvent {
  const _PlanetEvent({required this.icon, required this.title, required this.note});
  final IconData icon;
  final String title;
  final String note;
}

class _AstroInsightsScreenState extends State<AstroInsightsScreen> {
  String? _mahaLord, _antarLord;
  String? _dashaNarrative;
  List<_PlanetEvent>? _events;
  List<_DayEnergy>? _week;
  bool _loading = true;
  bool _errored = false;

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _factorIcons = {
    'moonTransit': Icons.brightness_3,
    'panchang': Icons.wb_sunny_outlined,
    'dasha': Icons.hourglass_bottom,
    'transits': Icons.auto_awesome,
  };
  static const _factorTitles = {
    'moonTransit': 'Moon Transit',
    'panchang': "Today's Panchang",
    'dasha': 'Current Dasha',
    'transits': 'Planetary Transits',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dasha = await ChartApi.getDasha();
      final maha = (dasha['maha'] as List).cast<Map<String, dynamic>>();
      final antar = (dasha['antar'] as List).cast<Map<String, dynamic>>();
      final currentMaha = maha.where((p) => p['current'] == true).firstOrNull;
      final currentAntar = antar.where((p) => p['current'] == true).firstOrNull;
      final mahaLord = currentMaha?['lord'] as String?;
      final antarLord = currentAntar?['lord'] as String?;

      final today = await SignalApi.getToday();
      final breakdown = today['breakdown'] as Map<String, dynamic>;
      final events = _factorTitles.entries.map((e) {
        final driver = (breakdown[e.key] as Map<String, dynamic>)['driver'] as String;
        return _PlanetEvent(icon: _factorIcons[e.key]!, title: e.value, note: driver);
      }).toList();

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final week = await Future.wait(List.generate(7, (i) async {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        try {
          final signal = await SignalApi.getToday(date: day);
          return _DayEnergy(_weekdayLabels[i], (signal['score'] as int) / 100.0);
        } catch (_) {
          return _DayEnergy(_weekdayLabels[i], 0.0);
        }
      }));

      if (!mounted) return;
      setState(() {
        _mahaLord = mahaLord;
        _antarLord = antarLord;
        _dashaNarrative = (mahaLord != null && antarLord != null)
            ? 'A period that blends ${mahaLord == antarLord ? "" : "$mahaLord's ${kGrahaKeyword[mahaLord] ?? ''} with "}'
                '$antarLord\'s ${kGrahaKeyword[antarLord] ?? ''}. Expect this window to shape your '
                '${kGrahaDomain[antarLord] ?? kGrahaDomain[mahaLord] ?? 'day-to-day life'} most strongly.'
            : null;
        _events = events;
        _week = week;
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_errored)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Save your birth data to see your personal insights.',
                style: AppText.sans(size: 14, color: AppColors.textMuted),
              ),
            )
          else ...[
            // ── Card 1: Current dasha ──────────────────────────────────
            GlassCard(
              goldTopBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('CURRENT DASHA'),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _mahaLord != null ? '$_mahaLord Mahadasha' : '—',
                    style: AppText.serif(size: 26, weight: FontWeight.w700),
                  ),
                  if (_antarLord != null)
                    Text(
                      '$_antarLord Antardasha',
                      style: AppText.serifValue.copyWith(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _dashaNarrative ?? 'Save your birth data to see your current Dasha.',
                    style: AppText.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Card 2: What's driving today ───────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('PLANETARY EVENTS'),
                  const SizedBox(height: AppSpacing.lg),
                  for (int i = 0; i < (_events?.length ?? 0); i++) ...[
                    _EventRow(event: _events![i]),
                    if (i != _events!.length - 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Divider(color: AppColors.borderFaint, height: 1),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Card 3: Weekly energy forecast ─────────────────────────
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
                        for (final d in (_week ?? const <_DayEnergy>[]))
                          Expanded(child: _EnergyBar(day: d)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
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
