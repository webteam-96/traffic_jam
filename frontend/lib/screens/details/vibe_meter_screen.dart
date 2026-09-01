import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/signal_api.dart';

/// Astro Vibe Meter — the real factors behind today's Traffic Signal score
/// (Moon Transit / Panchang / Dasha / Planetary Transits), each with its
/// real 0-100 sub-score and driver text from GET /signal/today.
class VibeMeterScreen extends StatefulWidget {
  const VibeMeterScreen({super.key});

  @override
  State<VibeMeterScreen> createState() => _VibeMeterScreenState();
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

class _VibeMeterScreenState extends State<VibeMeterScreen> {
  static const _factors = [
    ('moonTransit', Icons.brightness_3, 'Moon Transit'),
    ('panchang', Icons.wb_sunny_outlined, "Today's Panchang"),
    ('dasha', Icons.hourglass_bottom, 'Current Dasha'),
    ('transits', Icons.auto_awesome, 'Planetary Transits'),
  ];

  List<_Domain>? _domains;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final signal = await SignalApi.getToday();
      final breakdown = signal['breakdown'] as Map<String, dynamic>;
      final domains = _factors.map((f) {
        final factor = breakdown[f.$1] as Map<String, dynamic>;
        return _Domain(
          icon: f.$2,
          title: f.$3,
          value: (factor['score'] as int) / 100.0,
          blurb: factor['driver'] as String,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _domains = domains;
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
      title: 'Vibe Meter',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel("TODAY'S ALIGNMENT"),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The real factors shaping your Traffic Signal today, at a glance.',
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
          else if (_errored || _domains == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Save your birth data to see your daily alignment.',
                style: AppText.sans(size: 14, color: AppColors.textMuted),
              ),
            )
          else
            for (final d in _domains!) ...[
              _DomainCard(domain: d),
              const SizedBox(height: AppSpacing.lg),
            ],
        ],
      ),
    );
  }
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
