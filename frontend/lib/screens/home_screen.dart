import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_assets.dart';
import '../widgets/widgets.dart';
import '../nav.dart';
import '../services/panchang_api.dart';
import '../services/user_api.dart';
import '../services/chart_api.dart';
import 'kundli/kundli_landing_screen.dart';
import 'details/traffic_signal_screen.dart';
import 'details/time_windows_screen.dart';
import 'profile/book_appointment_screen.dart';

/// Home dashboard — Figma node 1:711.
/// Astro Identity · Today's Panchang · Action hub (2x2) · Private Cosmic
/// Meter · Private Cosmic Reading. Cosmic Foundations moved to its own page,
/// reachable from the top-bar button (see AppTopBar/AppShell).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenTab});

  /// Switch the AppShell's active bottom-nav tab (0..4).
  final void Function(int index)? onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Bumped by a pull-to-refresh. Each card below fetches its own data in its
  /// own `initState` and quietly falls back to a "—" placeholder on failure,
  /// so there is no single load to re-run: changing the subtree's key remounts
  /// all three cards and each re-fetches itself.
  ///
  /// The cost of doing it this way is that we can't await those fetches, so
  /// the pull spinner is timed rather than tied to the requests finishing.
  int _reloadToken = 0;

  Future<void> _refresh() async {
    setState(() => _reloadToken++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return CosmicScrollView(
      onRefresh: _refresh,
      child: KeyedSubtree(
        key: ValueKey(_reloadToken),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AstroIdentityHeader(),
            const SizedBox(height: AppSpacing.section),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onOpenTab?.call(1),
              child: const _TodaysPanchangCard(),
            ),
            const SizedBox(height: AppSpacing.section),
            _ActionHub(onOpenTab: widget.onOpenTab),
            const SizedBox(height: AppSpacing.xl),
            const _CosmicReadingCard(),
          ],
        ),
      ),
    );
  }
}

// ── Astro Identity + name ─────────────────────────────────────────────────
class _AstroIdentityHeader extends StatefulWidget {
  const _AstroIdentityHeader();

  @override
  State<_AstroIdentityHeader> createState() => _AstroIdentityHeaderState();
}

class _AstroIdentityHeaderState extends State<_AstroIdentityHeader> {
  String? _name;
  String? _lagna, _moonSign, _sunSign;
  bool _loadingName = true;
  bool _loadingChart = true;
  bool get _loading => _loadingName || _loadingChart;

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadChart();
  }

  // Split from _loadChart (rather than one Future.wait) so a chart hiccup
  // never hides a name we already successfully fetched, and vice versa.
  Future<void> _loadName() async {
    try {
      final birthData = await UserApi.getBirthData();
      if (mounted) setState(() => _name = (birthData?['name'] as String?)?.trim());
    } catch (_) {
      // No birth data yet, or a transient error — greeting falls back to "there".
    } finally {
      if (mounted) setState(() => _loadingName = false);
    }
  }

  Future<void> _loadChart() async {
    try {
      final chart = await ChartApi.getChart();
      final d1 = (chart['d1'] as List).cast<Map<String, dynamic>>();
      final sun = d1.where((p) => p['planet'] == 'Sun').firstOrNull;
      final moon = d1.where((p) => p['planet'] == 'Moon').firstOrNull;
      if (!mounted) return;
      setState(() {
        _lagna = (chart['ascendant'] as Map<String, dynamic>?)?['sign'] as String?;
        _sunSign = sun?['sign'] as String?;
        _moonSign = moon?['sign'] as String?;
      });
    } catch (_) {
      // No chart yet (birth data not saved) or a transient error — falls
      // back to the "—" empty state, same as Profile's own Astro Identity card.
    } finally {
      if (mounted) setState(() => _loadingChart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = (_name?.isNotEmpty ?? false) ? _name! : 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, $greetingName',
            style: AppText.serif(size: 26, weight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.lg),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
            ),
          )
        else if (_lagna == null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => pushScreen(context, KundliLandingScreen.new),
            child: Text(
              'Save your birth details to reveal your astro identity.',
              style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.4),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _IdentityChip('LAGNA', _lagna!),
              _IdentityChip('MOON SIGN', _moonSign ?? '—'),
              _IdentityChip('SUN SIGN', _sunSign ?? '—'),
            ],
          ),
      ],
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.sans(size: 9, color: AppColors.textMuted, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value, style: AppText.sans(size: 13, weight: FontWeight.w600, color: AppColors.gold)),
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
  const _ActionItem(this.icon, this.label);

  /// A widget rather than an IconData: Kundli's is a drawn North Indian chart,
  /// which no icon font has.
  final Widget icon;
  final String label;
}

/// Material icons rather than the Figma SVGs these tiles used to carry: the
/// old set didn't depict its labels — a broom for "Today's Signal", and the
/// same calendar for both Panchang and Auspicious Windows. These match the
/// icons the nav menu already uses for the identical destinations, so the two
/// routes to each screen look like the same thing.
const _actions = [
  // The North Indian chart's own outline — the shape the app draws a Kundli
  // in, and what anyone who reads one recognises at a glance.
  _ActionItem(NorthChartGlyph(size: 21, color: AppColors.gold), 'Kundli'),
  // A daily almanac — a calendar with something written on the day.
  _ActionItem(Icon(Icons.event_note_outlined, size: 21, color: AppColors.gold), 'Panchang'),
  // Windows of time to act in or avoid.
  _ActionItem(Icon(Icons.timelapse, size: 21, color: AppColors.gold), 'Auspicious Windows'),
  // Literally a traffic light, which is what the score is drawn as.
  _ActionItem(Icon(Icons.traffic_outlined, size: 21, color: AppColors.gold), "Today's Signal"),
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
        pushScreen(context, TimeWindowsScreen.new);
      case 3:
        // Opens the Traffic Signal screen, which is what this tile has always
        // done — it was labelled "Cleanup Major Transits", which named neither
        // the screen nor anything the app does.
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
            IconChip(size: 40, child: a.icon),
            const SizedBox(height: AppSpacing.md),
            Text(a.label, style: AppText.cardTitle),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < _actions.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.lg));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(i)),
              if (i + 1 < _actions.length) ...[
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: cell(i + 1)),
              ],
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
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

    // The Hindu lunar month, shown beside the Gregorian date. Purnimanta is
    // the reckoning used across the Hindi-speaking north — the API returns the
    // Amanta name too, for a southern reading, but showing both here would say
    // two different months on the same card for half of every lunation.
    final lunarMonth = panchang?['lunarMonth'] as Map<String, dynamic>?;
    final lunarMonthLabel = lunarMonth == null
        ? null
        : '${lunarMonth['purnimanta']} · ${lunarMonth['purnimantaHindi']}';

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
                    if (lunarMonthLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        lunarMonthLabel,
                        // Devanagari has no glyphs in the app's own typefaces,
                        // so this leans on the platform's font fallback rather
                        // than AppText.sans — same as the chart legend.
                        style: const TextStyle(
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppColors.amber),
                      ),
                    ],
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
