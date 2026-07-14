import 'package:flutter/material.dart';

import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/widgets.dart';

/// Vimshottari Dasha timeline — vertical rail of Mahadasha periods with the
/// current (Venus) period highlighted and its Antardasha sub-progress nested.
/// Stateless: pure read-only presentation of const mock data.
class DashaTimelineScreen extends StatelessWidget {
  const DashaTimelineScreen({super.key});

  // ── Mock data ──────────────────────────────────────────────────────────────
  static const List<_Dasha> _mahadashas = [
    _Dasha('Ketu', Icons.nights_stay, '2004 – 2011', '7 yrs', _Phase.done, 1.0),
    _Dasha('Venus', Icons.auto_awesome, '2011 – 2031', '20 yrs',
        _Phase.active, 0.75),
    _Dasha('Sun', Icons.wb_sunny, '2031 – 2037', '6 yrs', _Phase.upcoming, 0.0),
    _Dasha('Moon', Icons.nightlight_round, '2037 – 2047', '10 yrs',
        _Phase.upcoming, 0.0),
    _Dasha('Mars', Icons.local_fire_department, '2047 – 2054', '7 yrs',
        _Phase.upcoming, 0.0),
    _Dasha('Rahu', Icons.dark_mode, '2054 – 2072', '18 yrs',
        _Phase.upcoming, 0.0),
  ];

  // Antardasha sub-periods within the active Venus Mahadasha.
  static const List<_Anta> _antardashas = [
    _Anta('Rahu', '2018 – 2021', _Phase.done, 1.0),
    _Anta('Jupiter', '2021 – 2024', _Phase.done, 1.0),
    _Anta('Saturn', '2024 – 2027', _Phase.active, 0.68),
    _Anta('Mercury', '2027 – 2030', _Phase.upcoming, 0.0),
    _Anta('Ketu', '2030 – 2031', _Phase.upcoming, 0.0),
  ];

  @override
  Widget build(BuildContext context) {
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
            'Your life unfolds through nine planetary periods. Venus currently '
            'guides your path.',
            style: AppText.sans(
                size: 14, color: AppColors.textMuted, height: 22 / 14),
          ),
          const SizedBox(height: AppSpacing.section),
          for (int i = 0; i < _mahadashas.length; i++)
            _TimelineEntry(
              dasha: _mahadashas[i],
              isLast: i == _mahadashas.length - 1,
              antardashas: _mahadashas[i].phase == _Phase.active
                  ? _antardashas
                  : const [],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
enum _Phase { done, active, upcoming }

class _Dasha {
  const _Dasha(
      this.planet, this.icon, this.range, this.years, this.phase, this.progress);
  final String planet;
  final IconData icon;
  final String range;
  final String years;
  final _Phase phase;
  final double progress; // 0..1
}

class _Anta {
  const _Anta(this.planet, this.range, this.phase, this.progress);
  final String planet;
  final String range;
  final _Phase phase;
  final double progress; // 0..1
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline row: rail (node + connector) + GlassCard
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.dasha,
    required this.isLast,
    required this.antardashas,
  });

  final _Dasha dasha;
  final bool isLast;
  final List<_Anta> antardashas;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(phase: dasha.phase, isLast: isLast),
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
    final active = dasha.phase == _Phase.active;
    final card = GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderColor:
          active ? AppColors.gold.withValues(alpha: 0.55) : AppColors.borderFaint,
      fill: active ? AppColors.amber : AppColors.surface,
      fillOpacity: active ? 0.07 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(
                glow: active,
                child: Icon(dasha.icon, size: 20, color: AppColors.gold),
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
                          child: Text(dasha.planet,
                              style: AppText.serif(
                                  size: 20, weight: FontWeight.w400)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        active ? const _ActiveChip() : _yearsChip(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(dasha.range, style: AppText.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _progressArea(active),
        ],
      ),
    );

    if (!active) return card;
    // Soft gold glow around the active period.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: card,
    );
  }

  Widget _yearsChip() => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(dasha.years,
            style: AppText.sans(
                size: 11,
                weight: FontWeight.w500,
                color: AppColors.textTan)),
      );

  Widget _progressArea(bool active) {
    switch (dasha.phase) {
      case _Phase.done:
        return MeterBar(label: 'Completed', value: 1.0, glow: false);
      case _Phase.upcoming:
        return Row(
          children: [
            const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Text('Upcoming • ${dasha.years}', style: AppText.bodySmall),
          ],
        );
      case _Phase.active:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MeterBar(label: 'Elapsed', value: dasha.progress),
            const SizedBox(height: AppSpacing.xl),
            Container(height: 1, color: AppColors.borderFaint),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const SectionLabel('Antardasha'),
                const Spacer(),
                Text('within Venus', style: AppText.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final a in antardashas) _AntaRow(anta: a),
          ],
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rail — the vertical connector with a phase-styled node
// ─────────────────────────────────────────────────────────────────────────────
class _Rail extends StatelessWidget {
  const _Rail({required this.phase, required this.isLast});
  final _Phase phase;
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
                child: Container(
                  width: 2,
                  color: AppColors.gold.withValues(alpha: 0.22),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _node() {
    switch (phase) {
      case _Phase.active:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldButtonGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textOnGold,
              ),
            ),
          ),
        );
      case _Phase.done:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: const Icon(Icons.check, size: 13, color: AppColors.gold),
        );
      case _Phase.upcoming:
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Antardasha compact row
// ─────────────────────────────────────────────────────────────────────────────
class _AntaRow extends StatelessWidget {
  const _AntaRow({required this.anta});
  final _Anta anta;

  @override
  Widget build(BuildContext context) {
    final active = anta.phase == _Phase.active;
    final done = anta.phase == _Phase.done;
    final dotColor = active
        ? AppColors.gold
        : done
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
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            blurRadius: 6)
                      ]
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
                        anta.planet,
                        style: AppText.sans(
                          size: 13,
                          weight: active ? FontWeight.w600 : FontWeight.w500,
                          color: anta.phase == _Phase.upcoming
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _trailing(active, done),
                  ],
                ),
                Text(anta.range,
                    style: AppText.sans(size: 11, color: AppColors.textMuted)),
                if (active) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _slimBar(anta.progress),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailing(bool active, bool done) {
    if (active) {
      return Text('${(anta.progress * 100).round()}%',
          style: AppText.sans(
              size: 12, weight: FontWeight.w600, color: AppColors.amber));
    }
    if (done) {
      return Icon(Icons.check_circle,
          size: 14, color: AppColors.gold.withValues(alpha: 0.7));
    }
    return Text('Soon',
        style: AppText.sans(size: 11, color: AppColors.textMuted));
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
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Text(
        'ACTIVE',
        style: AppText.sans(
            size: 10,
            weight: FontWeight.w700,
            color: AppColors.gold,
            letterSpacing: 1.0),
      ),
    );
  }
}
