import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../services/panchang_api.dart';

/// Auspicious/Inauspicious Time Windows — Rahu Kaal, Yamaganda and Gulika
/// (all inauspicious, classically) to avoid, and Abhijit Muhurat (the one
/// favourable window this Panchang computes) to favour. Wired to GET
/// /panchang/today, which already computes all four.
class TimeWindowsScreen extends StatefulWidget {
  const TimeWindowsScreen({super.key});

  @override
  State<TimeWindowsScreen> createState() => _TimeWindowsScreenState();
}

class _TimeWindowsScreenState extends State<TimeWindowsScreen> {
  Map<String, dynamic>? _panchang;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final panchang = await PanchangApi.getToday();
      if (!mounted) return;
      setState(() {
        _panchang = panchang;
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

  DateTime _parseUtc(String iso) => DateTime.parse(iso).toLocal();

  String _formatTime(String iso) {
    final t = _parseUtc(iso);
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final meridiem = t.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $meridiem';
  }

  String _range(Map<String, dynamic> window) =>
      '${_formatTime(window['start'] as String)} – ${_formatTime(window['end'] as String)}';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Auspicious Windows',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
              ),
            )
          else if (_errored || _panchang == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text("Couldn't load today's Panchang — check your connection.",
                  style: AppText.body),
            )
          else ...[
            const SectionLabel('AVOID THESE PERIODS'),
            const SizedBox(height: AppSpacing.md),
            _rahuKaalCard(_panchang!['rahuKaal'] as Map<String, dynamic>),
            const SizedBox(height: AppSpacing.lg),
            _AvoidRow(
              icon: Icons.hourglass_bottom,
              name: 'Yamaganda',
              range: _range(_panchang!['yamaganda'] as Map<String, dynamic>),
              note: "Yama's shadow period — avoid starting anything new.",
            ),
            const SizedBox(height: AppSpacing.md),
            _AvoidRow(
              icon: Icons.hourglass_bottom,
              name: 'Gulika Kaal',
              range: _range(_panchang!['gulika'] as Map<String, dynamic>),
              note: 'A minor inauspicious window — favour routine tasks only.',
            ),
            const SizedBox(height: AppSpacing.section),
            const SectionLabel('FAVOURABLE MUHURAT'),
            const SizedBox(height: AppSpacing.md),
            Text("Today's Green Light",
                style: AppText.serif(size: 24, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.xl),
            _WindowCard(
              range: _range(_panchang!['abhijit'] as Map<String, dynamic>),
              name: 'Abhijit Muhurat',
              note: 'The victorious midday window — Sun at its zenith.',
              activities: const ['Meetings', 'Signing', 'Travel', 'Payments'],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rahuKaalCard(Map<String, dynamic> rahuKaal) {
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
          Text(_range(rahuKaal),
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

class _AvoidRow extends StatelessWidget {
  const _AvoidRow({
    required this.icon,
    required this.name,
    required this.range,
    required this.note,
  });

  final IconData icon;
  final String name;
  final String range;
  final String note;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      borderColor: AppColors.surfaceRaised3,
      radius: AppRadius.md,
      child: Row(
        children: [
          IconChip(child: Icon(icon, size: 18, color: AppColors.criticalText)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(note,
                    style: AppText.sans(size: 12, color: AppColors.textTan, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(range,
              style: AppText.sans(
                  size: 13, weight: FontWeight.w600, color: AppColors.criticalText)),
        ],
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.range,
    required this.name,
    required this.note,
    required this.activities,
  });

  final String range;
  final String name;
  final String note;
  final List<String> activities;

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
                child: Text(range,
                    style: AppText.serif(
                      size: 20,
                      weight: FontWeight.w700,
                      color: AppColors.gold,
                    )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(name,
              style: AppText.serif(size: 18, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(note,
              style: AppText.sans(
                  size: 13, color: AppColors.textTan, height: 1.5)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in activities) _activityChip(a),
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
