import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/signal_api.dart';

/// Flagship "Today's Signal" detail — a pushed (non-tab) screen.
/// Big dial (green/yellow/red by band), the weighted breakdown behind the
/// score, and the four factor drivers explaining why. Wired to GET /signal/today.
class TrafficSignalScreen extends StatefulWidget {
  const TrafficSignalScreen({super.key});

  @override
  State<TrafficSignalScreen> createState() => _TrafficSignalScreenState();
}

class _TrafficSignalScreenState extends State<TrafficSignalScreen> {
  Map<String, dynamic>? _signal;
  bool _loading = true;
  String? _error; // null = no error; 'no-birth-data' or 'generic'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final signal = await SignalApi.getToday();
      if (!mounted) return;
      setState(() {
        _signal = signal;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.code == 'NO_BIRTH_DATA' ? 'no-birth-data' : 'generic';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'generic';
      });
    }
  }

  Color _bandColor(String band) => switch (band) {
        'green' => AppColors.success,
        'yellow' => AppColors.amber,
        _ => AppColors.criticalText,
      };

  IconData _bandIcon(String band) => switch (band) {
        'green' => Icons.check_circle,
        'yellow' => Icons.warning_amber_rounded,
        _ => Icons.do_not_disturb_on,
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
        title: "Today's Signal",
        scrollable: false,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (_error == 'no-birth-data') {
      return DetailScaffold(
        title: "Today's Signal",
        scrollable: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              'Save your birth details first to see your daily Traffic Signal.',
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ),
        ),
      );
    }

    if (_error != null || _signal == null) {
      return DetailScaffold(
        title: "Today's Signal",
        scrollable: false,
        child: Center(
          child: Text("Couldn't load today's signal — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final signal = _signal!;
    final band = signal['band'] as String;
    final score = signal['score'] as int;
    final label = signal['label'] as String;
    final guidance = signal['guidance'] as String;
    final breakdown = signal['breakdown'] as Map<String, dynamic>;
    final weights = signal['weights'] as Map<String, dynamic>;
    final color = _bandColor(band);

    return DetailScaffold(
      title: "Today's Signal",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SectionLabel("TODAY'S TRAFFIC SIGNAL")),
          const SizedBox(height: AppSpacing.xxl),
          Center(child: _dial(score, color)),
          const SizedBox(height: AppSpacing.xl),
          Center(child: _bandPill(label, band, color)),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            guidance,
            textAlign: TextAlign.center,
            style: AppText.sans(
              size: 15,
              color: AppColors.textTan,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          Text('How this was calculated',
              style: AppText.serif(size: 24, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.surfaceRaised3, height: 1),
          const SizedBox(height: AppSpacing.xl),
          _calcCard(breakdown, weights),
          const SizedBox(height: AppSpacing.section),
          _driversCard(breakdown),
        ],
      ),
    );
  }

  // ── Score dial ───────────────────────────────────────────────────────────
  Widget _dial(int score, Color color) {
    return Container(
      width: 208,
      height: 208,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 44,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('SCORE',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 2.4,
              )),
          const SizedBox(height: AppSpacing.xs),
          Text('$score',
              style: AppText.serif(
                size: 68,
                weight: FontWeight.w700,
                color: color,
                height: 1.0,
                letterSpacing: -1.5,
              )),
          Text('/ 100',
              style: AppText.sans(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 1.2,
              )),
        ],
      ),
    );
  }

  Widget _bandPill(String label, String band, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_bandIcon(band), size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Text(label.toUpperCase(),
              style: AppText.sans(
                size: 15,
                weight: FontWeight.w700,
                color: color,
                letterSpacing: 2.0,
              )),
        ],
      ),
    );
  }

  // ── Weighted breakdown ───────────────────────────────────────────────────
  Widget _calcCard(Map<String, dynamic> breakdown, Map<String, dynamic> weights) {
    const factors = [
      ('moonTransit', 'Moon Transit'),
      ('panchang', 'Panchang Quality'),
      ('dasha', 'Dasha Influence'),
      ('transits', 'Planetary Transits'),
    ];

    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < factors.length; i++) ...[
            MeterBar(
              label: factors[i].$2,
              value: (breakdown[factors[i].$1]['score'] as int) / 100.0,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${((weights[factors[i].$1] as num) * 100).round()}% weight',
                style: AppText.sans(
                  size: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (i != factors.length - 1) const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  // ── Why — the four factor drivers ───────────────────────────────────────
  Widget _driversCard(Map<String, dynamic> breakdown) {
    const factors = [
      ('moonTransit', 'Moon Transit'),
      ('panchang', 'Panchang'),
      ('dasha', 'Dasha'),
      ('transits', 'Transits'),
    ];

    return GlassCard(
      goldTopBorder: true,
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.55,
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WHY'),
          const SizedBox(height: AppSpacing.lg),
          for (int i = 0; i < factors.length; i++) ...[
            _driverRow(factors[i].$2, breakdown[factors[i].$1]['driver'] as String),
            if (i != factors.length - 1) const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  Widget _driverRow(String label, String driver) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.circle, size: 8, color: AppColors.gold),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label — ',
                  style: AppText.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.goldLighter,
                  ),
                ),
                TextSpan(
                  text: driver,
                  style: AppText.sans(
                    size: 14,
                    color: AppColors.textTan,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
