import 'package:flutter/material.dart';

import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';
import 'package:traffic_jam/services/chart_api.dart';
import 'package:traffic_jam/services/api_client.dart';

const _planetIcons = <String, IconData>{
  'Sun': Icons.wb_sunny,
  'Moon': Icons.nightlight_round,
  'Mars': Icons.local_fire_department,
  'Mercury': Icons.bolt,
  'Jupiter': Icons.auto_awesome,
  'Venus': Icons.favorite,
  'Saturn': Icons.hourglass_bottom,
  'Rahu': Icons.dark_mode,
  'Ketu': Icons.nights_stay,
};
IconData _iconFor(String lord) => _planetIcons[lord] ?? Icons.circle;

DateTime _parseUtc(String iso) {
  final raw = DateTime.parse(iso);
  final utc = raw.isUtc
      ? raw
      : DateTime.utc(raw.year, raw.month, raw.day, raw.hour, raw.minute,
          raw.second, raw.millisecond, raw.microsecond);
  return utc.toLocal();
}

double _elapsedFraction(DateTime start, DateTime end) {
  final total = end.difference(start).inMilliseconds;
  if (total <= 0) return 1.0;
  final elapsed = DateTime.now().difference(start).inMilliseconds;
  return (elapsed / total).clamp(0.0, 1.0);
}

/// Vimshottari Dasha timeline — vertical rail of Mahadasha periods with the
/// current period highlighted and its Antardasha sub-progress nested. Wired
/// to GET /dasha (`maha` for the rail, `antar` — already scoped to the
/// current Mahadasha by the backend — for the nested sub-periods).
class DashaTimelineScreen extends StatefulWidget {
  const DashaTimelineScreen({super.key});

  @override
  State<DashaTimelineScreen> createState() => _DashaTimelineScreenState();
}

class _DashaTimelineScreenState extends State<DashaTimelineScreen> {
  Map<String, dynamic>? _dasha;
  bool _loading = true;
  String? _error; // 'no-data' | 'generic' | null

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dasha = await ChartApi.getDasha();
      if (!mounted) return;
      setState(() {
        _dasha = dasha;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.code == 'NO_DASHA' ? 'no-data' : 'generic';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'generic';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DetailScaffold(
        title: 'Dasha Timeline',
        scrollable: false,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (_error == 'no-data') {
      return DetailScaffold(
        title: 'Dasha Timeline',
        scrollable: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text('Save your birth details first to see your Dasha timeline.',
                textAlign: TextAlign.center, style: AppText.body),
          ),
        ),
      );
    }

    if (_error != null || _dasha == null) {
      return DetailScaffold(
        title: 'Dasha Timeline',
        scrollable: false,
        child: Center(
          child: Text("Couldn't load your Dasha timeline — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final maha = (_dasha!['maha'] as List<dynamic>).cast<Map<String, dynamic>>();
    final antar = (_dasha!['antar'] as List<dynamic>).cast<Map<String, dynamic>>();
    final currentMahaLord =
        maha.firstWhere((m) => m['current'] == true, orElse: () => maha.first)['lord'] as String;

    return DetailScaffold(
      title: 'Dasha Timeline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Vimshottari Dasha'),
          const SizedBox(height: AppSpacing.md),
          Text('Mahadasha Timeline', style: AppText.headingSerif),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your life unfolds through nine planetary periods. $currentMahaLord currently '
            'guides your path.',
            style: AppText.sans(size: 14, color: AppColors.textMuted, height: 22 / 14),
          ),
          const SizedBox(height: AppSpacing.section),
          for (int i = 0; i < maha.length; i++)
            _TimelineEntry(
              maha: maha[i],
              isLast: i == maha.length - 1,
              antardashas: maha[i]['current'] == true ? antar : const [],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline row: rail (node + connector) + GlassCard
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.maha,
    required this.isLast,
    required this.antardashas,
  });

  final Map<String, dynamic> maha;
  final bool isLast;
  final List<Map<String, dynamic>> antardashas;

  bool get _active => maha['current'] == true;
  DateTime get _start => _parseUtc(maha['start'] as String);
  DateTime get _end => _parseUtc(maha['end'] as String);
  bool get _done => !_active && _end.isBefore(DateTime.now());
  String get _lord => maha['lord'] as String;
  String get _range => '${_start.year} – ${_end.year}';
  String get _years => '${_end.year - _start.year} yrs';

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(active: _active, done: _done, isLast: isLast),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _card(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    final card = GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderColor: _active ? AppColors.gold.withValues(alpha: 0.55) : AppColors.borderFaint,
      fill: _active ? AppColors.amber : AppColors.surface,
      fillOpacity: _active ? 0.07 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(
                glow: _active,
                child: Icon(_iconFor(_lord), size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(_lord, style: AppText.serif(size: 20, weight: FontWeight.w400)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _active ? const _ActiveChip() : _yearsChip(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_range, style: AppText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _progressArea(),
        ],
      ),
    );

    if (!_active) return card;
    // Soft gold glow around the active period.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.18), blurRadius: 24, spreadRadius: -4),
        ],
      ),
      child: card,
    );
  }

  Widget _yearsChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(_years,
            style: AppText.sans(size: 11, weight: FontWeight.w500, color: AppColors.textTan)),
      );

  Widget _progressArea() {
    if (_done) return const MeterBar(label: 'Completed', value: 1.0, glow: false);
    if (!_active) {
      return Row(
        children: [
          const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text('Upcoming • $_years', style: AppText.bodySmall),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MeterBar(label: 'Elapsed', value: _elapsedFraction(_start, _end)),
        const SizedBox(height: AppSpacing.xl),
        Container(height: 1, color: AppColors.borderFaint),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const SectionLabel('Antardasha'),
            const Spacer(),
            Text('within $_lord', style: AppText.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final a in antardashas) _AntaRow(anta: a),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rail — the vertical connector with a phase-styled node
// ─────────────────────────────────────────────────────────────────────────────
class _Rail extends StatelessWidget {
  const _Rail({required this.active, required this.done, required this.isLast});
  final bool active;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _node(),
          if (!isLast)
            Expanded(
              child: Center(
                child: Container(width: 2, color: AppColors.gold.withValues(alpha: 0.22)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _node() {
    if (active) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.goldButtonGradient,
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 12)],
        ),
        child: Center(
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textOnGold),
          ),
        ),
      );
    }
    if (done) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
        ),
        child: const Icon(Icons.check, size: 13, color: AppColors.gold),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceRaised.withValues(alpha: 0.7),
        border: Border.all(color: AppColors.borderSoft),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Antardasha compact row
// ─────────────────────────────────────────────────────────────────────────────
class _AntaRow extends StatelessWidget {
  const _AntaRow({required this.anta});
  final Map<String, dynamic> anta;

  bool get _active => anta['current'] == true;
  DateTime get _start => _parseUtc(anta['start'] as String);
  DateTime get _end => _parseUtc(anta['end'] as String);
  bool get _done => !_active && _end.isBefore(DateTime.now());
  String get _lord => anta['lord'] as String;
  String get _range => '${_start.year} – ${_end.year}';

  @override
  Widget build(BuildContext context) {
    final dotColor = _active
        ? AppColors.gold
        : _done
            ? AppColors.gold.withValues(alpha: 0.5)
            : AppColors.textMuted.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: _active
                    ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 6)]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lord,
                        style: AppText.sans(
                          size: 13,
                          weight: _active ? FontWeight.w600 : FontWeight.w500,
                          color: !_active && !_done ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _trailing(),
                  ],
                ),
                Text(_range, style: AppText.sans(size: 11, color: AppColors.textMuted)),
                if (_active) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _slimBar(_elapsedFraction(_start, _end)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailing() {
    if (_active) {
      return Text('${(_elapsedFraction(_start, _end) * 100).round()}%',
          style: AppText.sans(size: 12, weight: FontWeight.w600, color: AppColors.amber));
    }
    if (_done) {
      return Icon(Icons.check_circle, size: 14, color: AppColors.gold.withValues(alpha: 0.7));
    }
    return Text('Soon', style: AppText.sans(size: 11, color: AppColors.textMuted));
  }

  Widget _slimBar(double v) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 3,
          color: AppColors.bgDeep,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v.clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.goldMeter,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// "ACTIVE" chip
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveChip extends StatelessWidget {
  const _ActiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Text(
        'ACTIVE',
        style: AppText.sans(size: 10, weight: FontWeight.w700, color: AppColors.gold, letterSpacing: 1.0),
      ),
    );
  }
}
