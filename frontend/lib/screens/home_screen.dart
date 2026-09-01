import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_assets.dart';
import '../widgets/widgets.dart';
import '../nav.dart';
import '../services/panchang_api.dart';
import '../services/signal_api.dart';
import 'notifications_screen.dart';
import 'kundli/kundli_landing_screen.dart';
import 'details/traffic_signal_screen.dart';
import 'details/vibe_meter_screen.dart';
import 'profile/book_appointment_screen.dart';

/// Home dashboard — Figma node 1:711.
/// Action hub (2x2) · Today's Panchang · Celestial Vibe Meter ·
/// Private Cosmic Reading · Cosmic Foundations grid.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenTab});

  /// Switch the AppShell's active bottom-nav tab (0..4).
  final void Function(int index)? onOpenTab;

  @override
  Widget build(BuildContext context) {
    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionHub(onOpenTab: onOpenTab),
          const SizedBox(height: AppSpacing.section),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpenTab?.call(1),
            child: const _TodaysPanchangCard(),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCardTapWrapper(
            onTap: () => pushScreen(context, VibeMeterScreen.new),
            child: const _VibeMeterCard(),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _CosmicReadingCard(),
          const SizedBox(height: AppSpacing.section),
          const _CosmicFoundations(),
        ],
      ),
    );
  }
}

/// Tiny helper so a whole card subtree becomes tappable without restyling.
class GlassCardTapWrapper extends StatelessWidget {
  const GlassCardTapWrapper({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
      behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}

// ── Action hub 2x2 ────────────────────────────────────────────────────────────
class _ActionItem {
  const _ActionItem(this.icon, this.label, this.w, this.h);
  final String icon;
  final String label;
  final double w;
  final double h;
}

const _actions = [
  _ActionItem(Assets.iconKundli, 'Kundli', 22, 18.5),
  _ActionItem(Assets.iconPanchangAction, 'Panchang', 18, 20),
  _ActionItem(Assets.iconNotifications, 'Notifications', 20, 20),
  _ActionItem(Assets.iconCleanupTransits, 'Cleanup Major Transits', 18, 22),
];

class _ActionHub extends StatelessWidget {
  const _ActionHub({this.onOpenTab});
  final void Function(int index)? onOpenTab;

  void _onTap(BuildContext context, int i) {
    switch (i) {
      case 0:
        pushScreen(context, KundliLandingScreen.new);
      case 1:
        onOpenTab?.call(1); // Panchang tab
      case 2:
        pushScreen(context, NotificationsScreen.new);
      case 3:
        pushScreen(context, TrafficSignalScreen.new);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cell(int i) {
      final a = _actions[i];
      return GlassCard(
        padding: const EdgeInsets.all(17),
        onTap: () => _onTap(context, i),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconChip(
              size: 40,
              child: SvgIcon(a.icon, width: a.w, height: a.h, color: AppColors.gold),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(a.label, style: AppText.cardTitle),
          ],
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(0)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: cell(1)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(2)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: cell(3)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Today's Panchang ──────────────────────────────────────────────────────────
const _weekdayNames = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _TodaysPanchangCard extends StatefulWidget {
  const _TodaysPanchangCard();

  @override
  State<_TodaysPanchangCard> createState() => _TodaysPanchangCardState();
}

class _TodaysPanchangCardState extends State<_TodaysPanchangCard> {
  Map<String, dynamic>? _panchang;

  @override
  void initState() {
    super.initState();
    PanchangApi.getToday().then((panchang) {
      if (!mounted) return;
      setState(() => _panchang = panchang);
    }).catchError((_) {
      // Silent — Home stays on its placeholder dashes; the Panchang tab
      // itself will surface the real error if the user opens it.
    });
  }

  String _dateLabel(String isoDate) {
    final d = DateTime.parse(isoDate);
    return '${_weekdayNames[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    Widget col(String label, List<String> lines) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.microLabel),
            const SizedBox(height: AppSpacing.sm),
            for (final l in lines) Text(l, style: AppText.serifValue),
          ],
        );

    final panchang = _panchang;
    final dateLabel = panchang == null ? '—' : _dateLabel(panchang['date'] as String);
    final tithiName = panchang == null
        ? '—'
        : (panchang['tithi'] as Map<String, dynamic>)['name'] as String;
    final nakshatraName = panchang == null
        ? '—'
        : (panchang['nakshatra'] as Map<String, dynamic>)['name'] as String;
    final paksha = panchang == null ? '' : panchang['paksha'] as String;

    return GlassCard(
      goldTopBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel("TODAY'S PANCHANG"),
                    const SizedBox(height: AppSpacing.xs),
                    Text(dateLabel, style: AppText.displayLg),
                  ],
                ),
              ),
              const SvgIcon(Assets.iconCalendar,
                  width: 36, height: 40, color: AppColors.amber),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: col('TITHI', [if (paksha.isNotEmpty) paksha, tithiName])),
              Expanded(child: col('NAKSHATRA', [nakshatraName])),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Celestial Vibe Meter ──────────────────────────────────────────────────────
// Preview of the same real factors shown in full on VibeMeterScreen (moon
// transit / Panchang / Dasha — from the Traffic Signal breakdown).
class _VibeMeterCard extends StatefulWidget {
  const _VibeMeterCard();

  @override
  State<_VibeMeterCard> createState() => _VibeMeterCardState();
}

class _VibeMeterCardState extends State<_VibeMeterCard> {
  Map<String, dynamic>? _breakdown;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SignalApi.getToday().then((signal) {
      if (!mounted) return;
      setState(() {
        _breakdown = signal['breakdown'] as Map<String, dynamic>;
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  double _score(String key) =>
      ((_breakdown?[key] as Map<String, dynamic>?)?['score'] as int? ?? 0) / 100.0;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CELESTIAL VIBE METER'),
          const SizedBox(height: AppSpacing.xl),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
                ),
              ),
            )
          else if (_breakdown == null)
            Text('Save your birth data to see your vibe meter.',
                style: AppText.sans(size: 13, color: AppColors.textMuted))
          else ...[
            MeterBar(label: 'Moon Transit', value: _score('moonTransit')),
            const SizedBox(height: AppSpacing.lg),
            MeterBar(label: 'Panchang', value: _score('panchang')),
            const SizedBox(height: AppSpacing.lg),
            MeterBar(label: 'Dasha', value: _score('dasha')),
          ],
        ],
      ),
    );
  }
}

// ── Private Cosmic Reading ────────────────────────────────────────────────────
class _CosmicReadingCard extends StatelessWidget {
  const _CosmicReadingCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: 180),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderFaint),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(figmaAsset(Assets.imgConsultation),
                    fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.bgDeepest,
                      AppColors.bgDeepest.withValues(alpha: 0.8),
                      AppColors.bgDeepest.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(33),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Private Cosmic\nReading', style: AppText.displayLg),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Connect with world-class astrologers for a '
                    'personalized deep-dive into your planetary transits.',
                    style: AppText.body,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  GoldButton(
                    label: 'BOOK APPOINTMENT',
                    expand: false,
                    height: 56,
                    onPressed: () => pushScreen(context, BookAppointmentScreen.new),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cosmic Foundations ────────────────────────────────────────────────────────
class _FoundationItem {
  const _FoundationItem(this.icon, this.title, this.subtitle, this.iconSize, this.onTap);
  final String icon;
  final String title;
  final String subtitle;
  final double iconSize;
  final void Function(BuildContext) onTap;
}

const _foundations = [
  _FoundationItem(Assets.iconZodiac, '12 Zodiac Signs', 'Discover your core identity.', 25, goToZodiacSigns),
  _FoundationItem(Assets.iconPlanets, '9 Planets', 'The celestial influencers.', 28, goToPlanets),
  _FoundationItem(Assets.iconHouses, '12 Houses', 'Areas of life experience.', 22, goToHouses),
  _FoundationItem(Assets.iconElements, '5 Elements', 'The energetic makeup.', 24, goToElements),
  _FoundationItem(Assets.iconNakshatras, '27 Nakshatras', 'The lunar mansions.', 27, goToNakshatras),
  _FoundationItem(Assets.iconYog, 'Yog in Astrology', 'Powerful cosmic pairings.', 22, goToYog),
];

class _CosmicFoundations extends StatelessWidget {
  const _CosmicFoundations();

  @override
  Widget build(BuildContext context) {
    Widget card(_FoundationItem f) => GlassCard(
          radius: AppRadius.lg,
          borderColor: AppColors.borderSoft,
          padding: const EdgeInsets.all(AppSpacing.cardPad),
          onTap: () => f.onTap(context),
          child: Column(
            children: [
              IconChip(
                size: 64,
                circular: true,
                glow: true,
                child: SvgIcon(f.icon, size: f.iconSize, color: AppColors.gold),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(f.title,
                  textAlign: TextAlign.center, style: AppText.headingSerif),
              const SizedBox(height: AppSpacing.sm),
              Text(f.subtitle,
                  textAlign: TextAlign.center,
                  style: AppText.microLabel.copyWith(color: AppColors.textMuted)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cosmic Foundations',
            style: AppText.headingSerif.copyWith(color: AppColors.amber)),
        const SizedBox(height: AppSpacing.xxl),
        for (int r = 0; r < _foundations.length; r += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(_foundations[r])),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: card(_foundations[r + 1])),
              ],
            ),
          ),
          if (r + 2 < _foundations.length) const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
