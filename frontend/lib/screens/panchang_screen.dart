import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../nav.dart';

/// Panchang tab — Figma node 1:544 (dc_544_panchang.txt).
/// Rahu Kaal alert with live countdown, Sunrise/Sunset pair, Shukla Paksha
/// waxing cycle, The Four Pillars, and an "Ask Jay Now" CTA. Data is mocked.
class PanchangScreen extends StatefulWidget {
  const PanchangScreen({super.key});

  @override
  State<PanchangScreen> createState() => _PanchangScreenState();
}

class _PanchangScreenState extends State<PanchangScreen> {
  // Rahu Kaal ends in 01:42:08 → count down live.
  Duration _remaining = const Duration(hours: 1, minutes: 42, seconds: 8);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining > Duration.zero
            ? _remaining - const Duration(seconds: 1)
            : Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rahuKaalCard(),
          const SizedBox(height: AppSpacing.xxl),
          _sunPair(),
          const SizedBox(height: AppSpacing.xxl),
          _shuklaPakshaCard(),
          const SizedBox(height: AppSpacing.section),
          _fourPillarsHeading(),
          const SizedBox(height: AppSpacing.xxl),
          _pillarCard(
            label: 'TITHI',
            iconHash: 'aaf576a65c3064d609174b020dd827ecb6badf3e.svg',
            iconW: 13,
            iconH: 20,
            name: 'Ekadashi',
            sub: 'Ends 11:22 PM',
            desc: 'A day of spiritual cleansing and internal fortification.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _pillarCard(
            label: 'NAKSHATRA',
            iconHash: '9d1fc44ecea6a95fd0a9e72c7addacee3adf5cc8.svg',
            iconW: 20,
            iconH: 19,
            name: 'Rohini',
            sub: 'Full Duration',
            desc: 'Abundant energy for creative pursuits and agriculture.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _pillarCard(
            label: 'YOGA',
            iconHash: '9d4a100e00500bd8c952292e776376f031412843.svg',
            iconW: 16,
            iconH: 16,
            name: 'Variyan',
            sub: 'Ends 09:15 AM',
            desc: 'Favorable for social gatherings and group achievements.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _pillarCard(
            label: 'KARANA',
            iconHash: 'c0c061064ca3ed921f90a2e20ef1432bc3c7b279.svg',
            iconW: 16,
            iconH: 20,
            name: 'Bava',
            sub: 'Active Now',
            desc: 'Stabilizing energy for property matters and foundations.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          _ctaCard(),
        ],
      ),
    );
  }

  // ── Rahu Kaal Alert ────────────────────────────────────────────────────────
  Widget _rahuKaalCard() {
    return GlassCard(
      goldTopBorder: true,
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.55,
      radius: AppRadius.sm,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Faint constellation flourish, top-right corner.
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.18,
              child: SvgIcon(
                'c29678b71eb2921c89ac40ace4bc9012825970db.svg',
                width: 130,
                height: 116,
                color: AppColors.amber,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('CURRENT CELESTIAL STATUS'),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Rahu Kaal\nAlert',
                  style: AppText.serif(
                    size: 40,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.48,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The shadow planet Rahu currently obscures the cosmic '
                  'flow. Exercise extreme caution in new ventures and '
                  'significant negotiations.',
                  style: AppText.sans(
                    size: 15,
                    color: AppColors.textTan,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _countdownBlock(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownBlock() {
    return Column(
      children: [
        Text(
          'Ends in',
          style: AppText.sans(
            size: 12,
            weight: FontWeight.w700,
            color: AppColors.goldLight,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _countdown,
            style: AppText.serif(
              size: 56,
              weight: FontWeight.w700,
              color: AppColors.gold,
              height: 1.1,
              letterSpacing: -1.28,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.critical,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                '9aa6a04603bad87027c58b9b449c323825fa1cec.svg',
                size: 12,
                color: AppColors.criticalBg,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'CRITICAL PHASE',
                style: AppText.sans(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.criticalBg,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sunrise / Sunset pair ───────────────────────────────────────────────────
  Widget _sunPair() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _sunCard(
              iconHash: 'dfa6d4d50dba7e8947d115db4edc12ff482dad2d.svg',
              iconW: 32,
              iconH: 32,
              label: 'SUNRISE',
              time: '06:24',
              meridiem: 'AM',
              note: 'Solar ascension\nbegins in Aries',
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _sunCard(
              iconHash: '502c5bba239c4d2eb83deb0ba26768a1be77a6c7.svg',
              iconW: 30,
              iconH: 24,
              label: 'SUNSET',
              time: '06:12',
              meridiem: 'PM',
              note: 'Descending into\ncosmic dusk',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sunCard({
    required String iconHash,
    required double iconW,
    required double iconH,
    required String label,
    required String time,
    required String meridiem,
    required String note,
  }) {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Center(
              child: SvgIcon(iconHash,
                  width: iconW, height: iconH, color: AppColors.amber),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(label,
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.textTan,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: AppSpacing.sm),
          Text('$time\n$meridiem',
              textAlign: TextAlign.center,
              style: AppText.serif(
                size: 28,
                color: AppColors.textPrimary,
                height: 1.3,
              )),
          const SizedBox(height: AppSpacing.lg),
          Text(note,
              textAlign: TextAlign.center,
              style: AppText.sans(
                size: 12,
                color: AppColors.textTan,
                height: 1.35,
              )),
        ],
      ),
    );
  }

  // ── Shukla Paksha ────────────────────────────────────────────────────────────
  Widget _shuklaPakshaCard() {
    // ponytail: dropped the mix-blend texture PNG overlay — purely decorative.
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Shukla\nPaksha',
            textAlign: TextAlign.center,
            style: AppText.serif(
              size: 40,
              weight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.48,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'The Waxing Crescent Cycle',
            style: AppText.serif(size: 16, color: AppColors.goldLight),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _phaseDot(AppColors.gold),
              _phaseDot(AppColors.gold.withValues(alpha: 0.8)),
              _phaseDot(AppColors.gold.withValues(alpha: 0.6)),
              _phaseDot(AppColors.surfaceRaised3),
              _phaseDot(AppColors.surfaceRaised3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseDot(Color color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ── The Four Pillars ─────────────────────────────────────────────────────────
  Widget _fourPillarsHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The Four Pillars',
            style: AppText.serif(size: 28, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.lg),
        const Divider(color: AppColors.surfaceRaised3, height: 1),
      ],
    );
  }

  Widget _pillarCard({
    required String label,
    required String iconHash,
    required double iconW,
    required double iconH,
    required String name,
    required String sub,
    required String desc,
  }) {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.gold,
                    letterSpacing: 1.2,
                  )),
              SvgIcon(iconHash,
                  width: iconW, height: iconH, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(name,
              style: AppText.serif(size: 24, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(sub,
              style: AppText.sans(size: 14, color: AppColors.goldLighter)),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.surfaceRaised3, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text(desc,
              style: AppText.sans(
                size: 15,
                color: AppColors.textTan,
                height: 1.6,
              )),
        ],
      ),
    );
  }

  // ── Ask Jay CTA ──────────────────────────────────────────────────────────────
  Widget _ctaCard() {
    return GlassCard(
      fill: AppColors.navBarBase,
      fillOpacity: 0.6,
      radius: AppRadius.sm,
      borderColor: AppColors.goldBorderSoft,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unclear on these\nalignments?',
              style: AppText.serif(size: 24, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ask Jay for a personalized cosmic traffic report based on your '
            'birth chart.',
            style: AppText.sans(
              size: 15,
              color: AppColors.textTan,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          GoldButton(
            label: 'Ask Jay Now',
            expand: false,
            height: 52,
            onPressed: () => goToChat(context),
          ),
        ],
      ),
    );
  }
}
