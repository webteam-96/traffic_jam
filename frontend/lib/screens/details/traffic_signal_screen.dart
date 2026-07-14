import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// Flagship "Today's Signal" detail — a pushed (non-tab) screen.
/// Big green GO-AHEAD dial, the weighted breakdown behind the 82/100 score,
/// and a do/avoid checklist. All data is mocked inline; no interactivity, so
/// this is a plain StatelessWidget. (ponytail: no state = no StatefulWidget.)
class TrafficSignalScreen extends StatelessWidget {
  const TrafficSignalScreen({super.key});

  // The four weighted factors. Weights sum to 1.0 and the weighted average of
  // the values reconstructs the 82/100 score:
  //   .9*.30 + .8*.25 + .7*.20 + .85*.25 = 0.8225 ≈ 82.
  static const List<_Factor> _factors = [
    _Factor('Moon Transit', 0.90, 0.30),
    _Factor('Panchang Quality', 0.80, 0.25),
    _Factor('Dasha Influence', 0.70, 0.20),
    _Factor('Planetary Transits', 0.85, 0.25),
  ];

  static const List<_Guidance> _todo = [
    _Guidance(true, 'Sign contracts and commit before noon — Jupiter favours '
        'binding decisions early.'),
    _Guidance(true, 'Begin travel and new journeys; the road ahead is clear.'),
    _Guidance(false, 'Avoid major financial disputes until after dusk.'),
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: "Today's Signal",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SectionLabel("TODAY'S TRAFFIC SIGNAL")),
          const SizedBox(height: AppSpacing.xxl),
          Center(child: _dial()),
          const SizedBox(height: AppSpacing.xl),
          Center(child: _goAheadPill()),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'The cosmic lanes are open. Momentum favours action taken with '
            'intent today — the planets clear the path for forward motion, '
            'so trust the green and proceed with confidence.',
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
          _calcCard(),
          const SizedBox(height: AppSpacing.section),
          _todoCard(),
        ],
      ),
    );
  }

  // ── Green GO-AHEAD dial ──────────────────────────────────────────────────
  Widget _dial() {
    return Container(
      width: 208,
      height: 208,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.22),
            AppColors.success.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AppColors.success, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.45),
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
          Text('82',
              style: AppText.serif(
                size: 68,
                weight: FontWeight.w700,
                color: AppColors.success,
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

  Widget _goAheadPill() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle,
              size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Text('GO AHEAD',
              style: AppText.sans(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.success,
                letterSpacing: 2.0,
              )),
        ],
      ),
    );
  }

  // ── Weighted breakdown ───────────────────────────────────────────────────
  Widget _calcCard() {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _factors.length; i++) ...[
            MeterBar(label: _factors[i].label, value: _factors[i].value),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(_factors[i].weight * 100).round()}% weight',
                style: AppText.sans(
                  size: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (i != _factors.length - 1)
              const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  // ── Do / avoid checklist ─────────────────────────────────────────────────
  Widget _todoCard() {
    return GlassCard(
      goldTopBorder: true,
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.55,
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('WHAT TO DO TODAY'),
          const SizedBox(height: AppSpacing.lg),
          for (int i = 0; i < _todo.length; i++) ...[
            _guidanceRow(_todo[i]),
            if (i != _todo.length - 1)
              const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  Widget _guidanceRow(_Guidance g) {
    final color = g.isDo ? AppColors.success : AppColors.criticalText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(g.isDo ? Icons.check_circle : Icons.do_not_disturb_on,
            size: 20, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(g.text,
              style: AppText.sans(
                size: 14,
                color: AppColors.textTan,
                height: 1.5,
              )),
        ),
      ],
    );
  }
}

class _Factor {
  final String label;
  final double value; // 0..1 strength
  final double weight; // 0..1 contribution
  const _Factor(this.label, this.value, this.weight);
}

class _Guidance {
  final bool isDo;
  final String text;
  const _Guidance(this.isDo, this.text);
}
