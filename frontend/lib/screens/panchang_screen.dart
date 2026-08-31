import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../services/panchang_api.dart';
import '../nav.dart';

/// Panchang tab — Figma node 1:544 (dc_544_panchang.txt).
/// Rahu Kaal alert with live countdown, Sunrise/Sunset pair, Paksha waxing/
/// waning cycle, and The Four Pillars. Wired to GET /panchang/today.
class PanchangScreen extends StatefulWidget {
  const PanchangScreen({super.key});

  @override
  State<PanchangScreen> createState() => _PanchangScreenState();
}

// The 15 within-Paksha Tithi names, in order — used only to give the phase
// dots a real data-driven position (how far through the 15-day arc), not to
// invent a description we don't have.
const _tithiDayNames = [
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi', 'Saptami',
  'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi',
];

class _PanchangScreenState extends State<PanchangScreen> {
  Map<String, dynamic>? _panchang;
  bool _loading = true;
  bool _errored = false;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    return '$hour12:$minute';
  }

  String _meridiem(String iso) => _parseUtc(iso).hour < 12 ? 'AM' : 'PM';

  String _endsAtLabel(String iso) => 'Ends ${_formatTime(iso)} ${_meridiem(iso)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CosmicScrollView(
        child: SizedBox(
          height: 400,
          child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
          ),
        ),
      );
    }

    if (_errored || _panchang == null) {
      return CosmicScrollView(
        child: SizedBox(
          height: 400,
          child: Center(
            child: Text("Couldn't load today's Panchang — check your connection.",
                textAlign: TextAlign.center, style: AppText.body),
          ),
        ),
      );
    }

    final panchang = _panchang!;
    final rahuKaal = panchang['rahuKaal'] as Map<String, dynamic>;

    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rahuKaalCard(rahuKaal),
          const SizedBox(height: AppSpacing.xxl),
          _sunPair(panchang),
          const SizedBox(height: AppSpacing.xxl),
          _pakshaCard(panchang),
          const SizedBox(height: AppSpacing.section),
          _fourPillarsHeading(),
          const SizedBox(height: AppSpacing.xxl),
          _pillarCard(
            label: 'TITHI',
            iconHash: 'aaf576a65c3064d609174b020dd827ecb6badf3e.svg',
            iconW: 13,
            iconH: 20,
            name: (panchang['tithi'] as Map<String, dynamic>)['name'] as String,
            sub: _endsAtLabel((panchang['tithi'] as Map<String, dynamic>)['endsAt'] as String),
          ),
          const SizedBox(height: AppSpacing.lg),
          _pillarCard(
            label: 'NAKSHATRA',
            iconHash: '9d1fc44ecea6a95fd0a9e72c7addacee3adf5cc8.svg',
            iconW: 20,
            iconH: 19,
            name: (panchang['nakshatra'] as Map<String, dynamic>)['name'] as String,
            sub: _endsAtLabel((panchang['nakshatra'] as Map<String, dynamic>)['endsAt'] as String),
          ),
          const SizedBox(height: AppSpacing.lg),
          _pillarCard(
            label: 'YOGA',
            iconHash: '9d4a100e00500bd8c952292e776376f031412843.svg',
            iconW: 16,
            iconH: 16,
            name: (panchang['yoga'] as Map<String, dynamic>)['name'] as String,
            sub: _endsAtLabel((panchang['yoga'] as Map<String, dynamic>)['endsAt'] as String),
          ),
          const SizedBox(height: AppSpacing.lg),
          _pillarCard(
            label: 'KARANA',
            iconHash: 'c0c061064ca3ed921f90a2e20ef1432bc3c7b279.svg',
            iconW: 16,
            iconH: 20,
            name: (panchang['karana'] as Map<String, dynamic>)['name'] as String,
            sub: _endsAtLabel((panchang['karana'] as Map<String, dynamic>)['endsAt'] as String),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _ctaCard(),
        ],
      ),
    );
  }

  // ── Rahu Kaal Alert ────────────────────────────────────────────────────────
  Widget _rahuKaalCard(Map<String, dynamic> rahuKaal) {
    final start = _parseUtc(rahuKaal['start'] as String);
    final end = _parseUtc(rahuKaal['end'] as String);
    final isActive = _now.isAfter(start) && _now.isBefore(end);
    final isUpcoming = _now.isBefore(start);

    final Duration? countdown = isActive
        ? end.difference(_now)
        : isUpcoming
            ? start.difference(_now)
            : null; // already passed for today

    return GlassCard(
      goldTopBorder: true,
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.55,
      radius: AppRadius.sm,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
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
                  isActive
                      ? 'The shadow planet Rahu currently obscures the cosmic '
                          'flow. Exercise extreme caution in new ventures and '
                          'significant negotiations.'
                      : isUpcoming
                          ? 'Rahu Kaal begins later today — plan important '
                              'commitments before it starts.'
                          : "Today's Rahu Kaal has passed — the shadow has lifted.",
                  style: AppText.sans(
                    size: 15,
                    color: AppColors.textTan,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (countdown != null) _countdownBlock(countdown, isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownBlock(Duration remaining, bool isActive) {
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Column(
      children: [
        Text(
          isActive ? 'Ends in' : 'Starts in',
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
            '$h:$m:$s',
            style: AppText.serif(
              size: 56,
              weight: FontWeight.w700,
              color: AppColors.gold,
              height: 1.1,
              letterSpacing: -1.28,
            ),
          ),
        ),
        if (isActive) ...[
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
      ],
    );
  }

  // ── Sunrise / Sunset pair ───────────────────────────────────────────────────
  Widget _sunPair(Map<String, dynamic> panchang) {
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
              time: _formatTime(panchang['sunrise'] as String),
              meridiem: _meridiem(panchang['sunrise'] as String),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _sunCard(
              iconHash: '502c5bba239c4d2eb83deb0ba26768a1be77a6c7.svg',
              iconW: 30,
              iconH: 24,
              label: 'SUNSET',
              time: _formatTime(panchang['sunset'] as String),
              meridiem: _meridiem(panchang['sunset'] as String),
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
        ],
      ),
    );
  }

  // ── Paksha ────────────────────────────────────────────────────────────────
  Widget _pakshaCard(Map<String, dynamic> panchang) {
    final paksha = panchang['paksha'] as String; // "Shukla" or "Krishna"
    final tithiName = (panchang['tithi'] as Map<String, dynamic>)['name'] as String;
    final dayIndex = _tithiDayNames.indexOf(tithiName); // -1 for Purnima/Amavasya (the 15th day)
    final position = dayIndex == -1 ? 15 : dayIndex + 1; // 1-15 through the Paksha
    final litDots = ((position / 15.0) * 5).ceil().clamp(1, 5);

    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.sm,
      borderColor: AppColors.surfaceRaised3,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(
            '$paksha\nPaksha',
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
            paksha == 'Shukla' ? 'The Waxing Crescent Cycle' : 'The Waning Crescent Cycle',
            style: AppText.serif(size: 16, color: AppColors.goldLight),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final lit = i < litDots;
              return _phaseDot(lit
                  ? AppColors.gold.withValues(alpha: 1.0 - (i * 0.1))
                  : AppColors.surfaceRaised3);
            }),
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
            onPressed: () => goToAskJayTab(context),
          ),
        ],
      ),
    );
  }
}
