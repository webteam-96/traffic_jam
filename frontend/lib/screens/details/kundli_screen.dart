import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';
import '../../models/kundli_profile.dart';
import 'dasha_timeline_screen.dart';

/// Kundli detail — Business Flow §5.2. Six sections behind one top-level
/// PillToggle: Planet, Vimshottari Dasha, Charts (D1/D9/D10/D60 selector,
/// North/South style toggle), KP System, Cusp Chart. Works for the user's own
/// chart (`profile` omitted) or a generated one (family/friend), so "Get
/// Kundli" pushes the same screen with a different [profile].
class KundliScreen extends StatefulWidget {
  const KundliScreen({super.key, this.profile});

  final KundliProfile? profile;

  @override
  State<KundliScreen> createState() => _KundliScreenState();
}

class _KundliScreenState extends State<KundliScreen> {
  int _section = 0; // Planet / Dasha / Charts / KP / Cusp
  int _chartIndex = 0; // D1 / D9 / D10 / D60
  bool _southIndian = false;

  static const _sections = ['Planet', 'Dasha', 'Charts', 'KP System', 'Cusp'];

  KundliProfile get _profile => widget.profile ?? KundliProfile.own;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return DetailScaffold(
      title: profile.isOwn ? 'My Kundli' : profile.name,
      actions: [
        IconButton(
          onPressed: () => toast(context, 'Chart shared'),
          icon: const Icon(Icons.ios_share,
              size: 18, color: AppColors.textPrimary),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!profile.isOwn) ...[
            _ProfileBanner(profile: profile),
            const SizedBox(height: AppSpacing.xl),
          ],
          const Center(child: SectionLabel('BIRTH CHART')),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: PillToggle(
              options: _sections,
              selectedIndex: _section,
              onChanged: (i) => setState(() => _section = i),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _body(profile),
        ],
      ),
    );
  }

  Widget _body(KundliProfile profile) {
    switch (_section) {
      case 0:
        return const _PlanetTab();
      case 1:
        return const _DashaTab();
      case 2:
        return _ChartsTab(
          profile: profile,
          chartIndex: _chartIndex,
          southIndian: _southIndian,
          onChartChanged: (i) => setState(() => _chartIndex = i),
          onStyleChanged: (v) => setState(() => _southIndian = v),
        );
      case 3:
        return const _KpTab();
      case 4:
      default:
        return const _CuspTab();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generated-profile banner — shown above the tabs for anyone but "My Kundli"
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.profile});
  final KundliProfile profile;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      goldTopBorder: true,
      child: Row(
        children: [
          IconChip(
            size: 44,
            child: const Icon(Icons.person_outline,
                size: 20, color: AppColors.gold),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: AppText.serif(size: 18, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${profile.dob} · ${profile.tobUnknown ? "Time unknown" : profile.tob} · ${profile.place}',
                  style: AppText.sans(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1) Planet tab — table of 9 grahas, tap a row for a plain-language card
// ─────────────────────────────────────────────────────────────────────────────
class _PlanetRow {
  const _PlanetRow(this.graha, this.sign, this.degree, this.house,
      this.nakshatra, this.explainer);
  final String graha;
  final String sign;
  final String degree;
  final int house;
  final String nakshatra;
  final String explainer;
}

class _PlanetTab extends StatelessWidget {
  const _PlanetTab();

  static const _rows = <_PlanetRow>[
    _PlanetRow('Sun', 'Aquarius', "28°12'", 7, 'P. Bhadrapada (3)',
        'Sun in the 7th sharpens how you show up in partnerships — visible, direct, sometimes a little dominant in negotiations.'),
    _PlanetRow('Moon', 'Taurus', "04°22'", 10, 'Krittika (3)',
        'Moon in the 10th ties your emotional steadiness to career and public standing — you feel most secure when your work is recognised.'),
    _PlanetRow('Mars', 'Capricorn', "15°55'", 6, 'Shravana (2)',
        'Mars in the 6th gives drive for competition and problem-solving — a natural fit for pressured, deadline-heavy work.'),
    _PlanetRow('Mercury', 'Aquarius', "02°09'", 7, 'Dhanishta (3)',
        'Mercury with the Sun in the 7th makes you an articulate, persuasive communicator in one-to-one dealings.'),
    _PlanetRow('Jupiter', 'Leo', "22°30'", 1, 'P. Phalguni (3)',
        'Jupiter in the 1st is a strong blessing — optimism, ethics and a naturally generous presence colour your whole personality.'),
    _PlanetRow('Venus', 'Aquarius', "11°47'", 7, 'Shatabhisha (2)',
        'Venus in the 7th favours committed partnership — you do best with one steady bond rather than many shallow ones.'),
    _PlanetRow('Saturn', 'Scorpio', "19°03'", 4, 'Anuradha (1)',
        'Saturn in the 4th asks patience of home life — security is built slowly, but what you build tends to last.'),
    _PlanetRow('Rahu', 'Libra', "08°15'", 3, 'Swati (2)',
        'Rahu in the 3rd fuels ambition through communication, media and courageous short journeys.'),
    _PlanetRow('Ketu', 'Aries', "08°15'", 9, 'Ashwini (2)',
        'Ketu in the 9th detaches you from inherited belief, pushing a more self-made, unconventional philosophy of life.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Planetary Positions',
            style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tap any planet for what its placement means in plain language.',
          style: AppText.sans(size: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.md,
          child: Column(
            children: [
              _row(const ['GRAHA', 'RASHI', 'DEG', 'H', 'NAKSHATRA'],
                  isHeader: true),
              for (int i = 0; i < _rows.length; i++)
                _tapRow(context, _rows[i], last: i == _rows.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tapRow(BuildContext context, _PlanetRow r, {required bool last}) {
    return InkWell(
      onTap: () => _showExplainer(context, r),
      child: _row(
        [r.graha, r.sign, r.degree, '${r.house}', r.nakshatra],
        last: last,
      ),
    );
  }

  Widget _row(List<String> cells, {bool isHeader = false, bool last = false}) {
    final headerStyle = AppText.sans(
        size: 9,
        weight: FontWeight.w700,
        color: AppColors.textPrimary.withValues(alpha: 0.4),
        letterSpacing: 0.8);
    Widget cell(int i, int flex, {Color? color, TextAlign align = TextAlign.left}) {
      return Expanded(
        flex: flex,
        child: Text(
          cells[i],
          textAlign: align,
          style: isHeader
              ? headerStyle
              : AppText.sans(size: 12, color: color ?? AppColors.textPrimary),
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.textPrimary.withValues(alpha: 0.02) : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          cell(0, 4, color: AppColors.gold),
          cell(1, 5, color: AppColors.textPrimary.withValues(alpha: 0.7)),
          cell(2, 3, color: AppColors.textMuted),
          cell(3, 2, align: TextAlign.center),
          cell(4, 5,
              color: AppColors.textPrimary.withValues(alpha: 0.4),
              align: TextAlign.right),
        ],
      ),
    );
  }

  void _showExplainer(BuildContext context, _PlanetRow r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GlassCard(
          fill: AppColors.navBarBase,
          fillOpacity: 0.96,
          goldTopBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.graha,
                      style:
                          AppText.serif(size: 22, color: AppColors.textPrimary)),
                  const SizedBox(width: AppSpacing.sm),
                  Text('in ${r.sign}',
                      style: AppText.sans(size: 14, color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'House ${r.house} · ${r.degree} · ${r.nakshatra}',
                style: AppText.sans(size: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(r.explainer,
                  style: AppText.sans(
                      size: 14, color: AppColors.textCream, height: 1.5)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2) Vimshottari Dasha tab — current period card + link to the full timeline
// ─────────────────────────────────────────────────────────────────────────────
class _DashaTab extends StatelessWidget {
  const _DashaTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vimshottari Dasha',
            style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The planetary period you are living through now, and what it '
          'typically brings.',
          style: AppText.sans(size: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          goldTopBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconChip(
                    glow: true,
                    child: const Icon(Icons.auto_awesome,
                        size: 18, color: AppColors.gold),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Venus Mahadasha',
                            style: AppText.serif(size: 18, weight: FontWeight.w600)),
                        Text('ENDS AUGUST 2031',
                            style: AppText.sans(
                                size: 10,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Venus brings a two-decade emphasis on relationships, comfort, '
                'creativity and finances — a generally favourable, harmonising period.',
                style: AppText.sans(
                    size: 13, color: AppColors.textCream, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              const MeterBar(label: 'Mahadasha elapsed', value: 0.75),
              const SizedBox(height: AppSpacing.lg),
              Container(height: 1, color: AppColors.borderFaint),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const SectionLabel('Current Antardasha'),
                  const Spacer(),
                  Text('Saturn', style: AppText.sans(size: 13, color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Saturn within Venus (2024–2027) asks for discipline inside an '
                'otherwise easy period — steady, structured effort pays off now.',
                style: AppText.sans(
                    size: 13, color: AppColors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        GoldButton(
          label: 'VIEW FULL DASHA TIMELINE',
          icon: Icons.timeline,
          outlined: true,
          onPressed: () => pushScreen(context, DashaTimelineScreen.new),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3) Charts tab — D1/D9/D10/D60 selector + North/South style toggle
// ─────────────────────────────────────────────────────────────────────────────
class _ChartsTab extends StatelessWidget {
  const _ChartsTab({
    required this.profile,
    required this.chartIndex,
    required this.southIndian,
    required this.onChartChanged,
    required this.onStyleChanged,
  });

  final KundliProfile profile;
  final int chartIndex;
  final bool southIndian;
  final ValueChanged<int> onChartChanged;
  final ValueChanged<bool> onStyleChanged;

  static const _tabs = ['Rashi D1', 'Navamsha D9', 'Dashamsha D10', 'Shastiamsha D60'];
  static const _titles = [
    'Lagna Chart · D1',
    'Navamsha · D9',
    'Dashamsha · D10',
    'Shastiamsha · D60',
  ];
  static const _notes = [
    'The rising sign and the frame of the whole life — houses counted from '
        'your ascendant.',
    'The ninth harmonic — marriage, dharma and the ripened fruit of each '
        'planet.',
    'The tenth harmonic — career trajectory, professional recognition and '
        'the shape of your working life.',
    'The finest divisional chart in the Parashari system — a detailed read '
        'of karma and overall life fortune.',
  ];

  // House (1..12) → planet abbreviations, relative to each varga's ascendant.
  static const List<Map<int, String>> _houses = [
    {1: 'As', 3: 'Ra', 4: 'Mo', 5: 'Ju', 7: 'Sa', 9: 'Ke', 10: 'Su\nMa', 11: 'Me\nVe'},
    {1: 'As\nJu', 2: 'Ra', 3: 'Ma', 5: 'Su\nMe', 7: 'Sa', 8: 'Ke', 9: 'Mo', 11: 'Ve'},
    {1: 'As', 2: 'Su', 4: 'Ra', 5: 'Mo\nMe', 6: 'Ma', 8: 'Ju', 10: 'Sa\nVe', 12: 'Ke'},
    {1: 'As\nSa', 3: 'Mo', 4: 'Ju', 6: 'Ke', 7: 'Su\nVe', 9: 'Ra', 10: 'Ma', 11: 'Me'},
  ];

  // Ascendant sign index per varga (0=Aries..11=Pisces) — for South layout only.
  static const _ascendantSign = [4, 9, 0, 3]; // Leo, Capricorn, Aries, Cancer

  static const _legend = [
    ['As', 'Ascendant'], ['Su', 'Sun'], ['Mo', 'Moon'], ['Ma', 'Mars'],
    ['Me', 'Mercury'], ['Ju', 'Jupiter'], ['Ve', 'Venus'], ['Sa', 'Saturn'],
    ['Ra', 'Rahu'], ['Ke', 'Ketu'],
  ];

  bool get _isD60 => chartIndex == 3;
  bool get _d60Locked => _isD60 && profile.tobUnknown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillToggle(options: _tabs, selectedIndex: chartIndex, onChanged: onChartChanged),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Text(_titles[chartIndex],
              style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: AppSpacing.lg),
        _styleToggle(),
        const SizedBox(height: AppSpacing.lg),
        if (_d60Locked) _lockedNotice() else _chartCard(),
        const SizedBox(height: AppSpacing.lg),
        Text(_notes[chartIndex],
            textAlign: TextAlign.center,
            style: AppText.sans(size: 13, color: AppColors.textTan, height: 1.55)),
        if (_isD60 && !profile.tobUnknown) ...[
          const SizedBox(height: AppSpacing.md),
          _sensitivityNote(),
        ],
        if (chartIndex == 1) ...[
          const SizedBox(height: AppSpacing.md),
          _vargottamaNote(),
        ],
        const SizedBox(height: AppSpacing.section),
        const SectionLabel('LEGEND'),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          radius: AppRadius.md,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: [for (final l in _legend) _legendItem(l[0], l[1])],
          ),
        ),
      ],
    );
  }

  Widget _styleToggle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _styleChip('North Indian', !southIndian),
            _styleChip('South Indian', southIndian),
          ],
        ),
      ),
    );
  }

  Widget _styleChip(String label, bool selected) {
    return GestureDetector(
      onTap: () => onStyleChanged(label == 'South Indian'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label,
            style: AppText.sans(
                size: 12,
                weight: FontWeight.w600,
                color: selected ? AppColors.textOnGold : AppColors.textTan)),
      ),
    );
  }

  Widget _chartCard() {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: southIndian
              ? _SouthChartPainter(_houses[chartIndex], _ascendantSign[chartIndex])
              : _NorthChartPainter(_houses[chartIndex]),
        ),
      ),
    );
  }

  Widget _lockedNotice() {
    return GlassCard(
      fill: AppColors.critical,
      fillOpacity: 0.12,
      borderColor: AppColors.criticalText.withValues(alpha: 0.4),
      radius: AppRadius.md,
      child: AspectRatio(
        aspectRatio: 1,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 36, color: AppColors.criticalText),
              const SizedBox(height: AppSpacing.lg),
              Text('Requires exact birth time',
                  style: AppText.serif(size: 18, color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  'Shastiamsha shifts with just a few minutes\' difference. '
                  '${profile.isOwn ? "You" : profile.name} marked the birth time as unknown, '
                  'so this chart is hidden.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 12, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sensitivityNote() {
    return GlassCard(
      radius: AppRadius.sm,
      fill: AppColors.amber,
      fillOpacity: 0.08,
      borderColor: AppColors.gold.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'D60 is extremely sensitive to birth time — treat it as directional '
              'unless your birth time is exact to the minute.',
              style: AppText.sans(size: 12, color: AppColors.textTan, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vargottamaNote() {
    return GlassCard(
      radius: AppRadius.sm,
      fill: AppColors.gold,
      fillOpacity: 0.1,
      borderColor: AppColors.gold.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.stars_rounded, size: 16, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Jupiter and Venus are Vargottama — placed in the same sign in '
              'both the Rashi and Navamsha charts, which strengthens them '
              'considerably.',
              style: AppText.sans(size: 12, color: AppColors.textTan, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String abbr, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(abbr,
            style: AppText.sans(
                size: 13, weight: FontWeight.w700, color: AppColors.amber)),
        const SizedBox(width: AppSpacing.xs),
        Text(name, style: AppText.sans(size: 13, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Draws the North-Indian diamond (square + both diagonals + midpoint diamond)
/// in thin gold lines, then seats planet labels at fixed house centers.
class _NorthChartPainter extends CustomPainter {
  const _NorthChartPainter(this.houses);

  final Map<int, String> houses;

  static const Map<int, Offset> _centers = {
    1: Offset(0.50, 0.25), 2: Offset(0.25, 0.11), 3: Offset(0.11, 0.25),
    4: Offset(0.25, 0.50), 5: Offset(0.11, 0.75), 6: Offset(0.25, 0.89),
    7: Offset(0.50, 0.75), 8: Offset(0.75, 0.89), 9: Offset(0.89, 0.75),
    10: Offset(0.75, 0.50), 11: Offset(0.89, 0.25), 12: Offset(0.75, 0.11),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), line);
    canvas.drawLine(Offset.zero, Offset(w, h), line);
    canvas.drawLine(Offset(w, 0), Offset(0, h), line);

    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(diamond, line..color = AppColors.gold.withValues(alpha: 0.32));

    houses.forEach((house, label) {
      final c = _centers[house];
      if (c == null) return;
      final isAsc = label.startsWith('As');
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: AppText.sans(
            size: 12,
            weight: FontWeight.w600,
            color: isAsc ? AppColors.gold : AppColors.textCream,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w * 0.26);
      tp.paint(canvas, Offset(c.dx * w - tp.width / 2, c.dy * h - tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _NorthChartPainter old) => old.houses != houses;
}

/// Draws the South-Indian fixed 4x4 grid — signs sit in fixed cells; each
/// house's label is placed by converting house→sign via the ascendant.
class _SouthChartPainter extends CustomPainter {
  const _SouthChartPainter(this.houses, this.ascendantSign);

  final Map<int, String> houses;
  final int ascendantSign; // 0=Aries..11=Pisces

  // Fixed sign → grid cell (row, col) in the 4x4 layout.
  static const Map<int, (int, int)> _signCell = {
    11: (0, 0), 0: (0, 1), 1: (0, 2), 2: (0, 3), // Pisces Aries Taurus Gemini
    10: (1, 0), 3: (1, 3), // Aquarius .. Cancer
    9: (2, 0), 4: (2, 3), // Capricorn .. Leo
    8: (3, 0), 7: (3, 1), 6: (3, 2), 5: (3, 3), // Sag Scorpio Libra Virgo
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cell = s / 4;
    final line = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), line);
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(cell * i, 0), Offset(cell * i, s), line);
      canvas.drawLine(Offset(0, cell * i), Offset(s, cell * i), line);
    }
    // clear the inner 2x2 (not part of a South Indian chart)
    final wipe = Paint()..color = AppColors.surfaceRaised.withValues(alpha: 1);
    canvas.drawRect(Rect.fromLTWH(cell, cell, cell * 2, cell * 2), wipe);

    houses.forEach((house, label) {
      final sign = (ascendantSign + house - 1) % 12;
      final rc = _signCell[sign];
      if (rc == null) return;
      final center = Offset((rc.$2 + 0.5) * cell, (rc.$1 + 0.5) * cell);
      final isAsc = label.startsWith('As');
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: AppText.sans(
            size: 11,
            weight: FontWeight.w600,
            color: isAsc ? AppColors.gold : AppColors.textCream,
            height: 1.15,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cell * 0.85);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _SouthChartPainter old) =>
      old.houses != houses || old.ascendantSign != ascendantSign;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4) KP System tab — sub-lord table + live ruling planets
// ─────────────────────────────────────────────────────────────────────────────
class _KpTab extends StatelessWidget {
  const _KpTab();

  // House, Sign, Star (Nakshatra) Lord, Sub Lord.
  static const _rows = <List<String>>[
    ['1', 'Leo', 'Sun', 'Venus'], ['2', 'Virgo', 'Mercury', 'Saturn'],
    ['3', 'Libra', 'Venus', 'Mercury'], ['4', 'Scorpio', 'Ketu', 'Mars'],
    ['5', 'Sagittarius', 'Jupiter', 'Rahu'], ['6', 'Capricorn', 'Saturn', 'Sun'],
    ['7', 'Aquarius', 'Saturn', 'Moon'], ['8', 'Pisces', 'Jupiter', 'Ketu'],
    ['9', 'Aries', 'Mars', 'Venus'], ['10', 'Taurus', 'Venus', 'Jupiter'],
    ['11', 'Gemini', 'Mercury', 'Saturn'], ['12', 'Cancer', 'Moon', 'Mars'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('KP System', style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A Krishnamurti Paddhati read of your chart — sub-lord detail for '
          'those already familiar with the system.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          goldTopBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('RULING PLANETS · RIGHT NOW'),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: const [
                  _RulingChip('Lagna Lord', 'Sun'),
                  _RulingChip('Moon Sign Lord', 'Venus'),
                  _RulingChip('Day Lord', 'Saturn'),
                  _RulingChip('Star Lord', 'Mercury'),
                  _RulingChip('Sub Lord', 'Rahu'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionLabel('CUSPAL SUB-LORDS'),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.md,
          child: Column(
            children: [
              _row(const ['HOUSE', 'SIGN', 'STAR LORD', 'SUB LORD'], isHeader: true),
              for (int i = 0; i < _rows.length; i++)
                _row(_rows[i], last: i == _rows.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(List<String> cells, {bool isHeader = false, bool last = false}) {
    final headerStyle = AppText.sans(
        size: 9,
        weight: FontWeight.w700,
        color: AppColors.textPrimary.withValues(alpha: 0.4),
        letterSpacing: 0.8);
    Widget cell(int i, int flex, {Color? color}) => Expanded(
          flex: flex,
          child: Text(cells[i],
              style: isHeader
                  ? headerStyle
                  : AppText.sans(size: 12, color: color ?? AppColors.textPrimary)),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.textPrimary.withValues(alpha: 0.02) : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          cell(0, 2, color: AppColors.gold),
          cell(1, 3),
          cell(2, 3, color: AppColors.textTan),
          cell(3, 3, color: AppColors.amber),
        ],
      ),
    );
  }
}

class _RulingChip extends StatelessWidget {
  const _RulingChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: AppText.sans(size: 9, color: AppColors.textMuted, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value, style: AppText.sans(size: 13, weight: FontWeight.w600, color: AppColors.gold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5) Cusp Chart tab — precise cusp degree + planets at each of the 12 houses
// ─────────────────────────────────────────────────────────────────────────────
class _CuspTab extends StatelessWidget {
  const _CuspTab();

  // House, Cusp degree, Sign, Planets at cusp (— if none).
  static const _rows = <List<String>>[
    ['1', "12°44'", 'Leo', '—'], ['2', "09°10'", 'Virgo', '—'],
    ['3', "07°55'", 'Libra', 'Rahu'], ['4', "10°02'", 'Scorpio', 'Saturn'],
    ['5', "14°38'", 'Sagittarius', '—'], ['6', "16°21'", 'Capricorn', 'Mars'],
    ['7', "12°44'", 'Aquarius', 'Sun, Mercury, Venus'],
    ['8', "09°10'", 'Pisces', '—'], ['9', "07°55'", 'Aries', 'Ketu'],
    ['10', "10°02'", 'Taurus', 'Moon'], ['11', "14°38'", 'Gemini', '—'],
    ['12', "16°21'", 'Cancer', '—'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cusp Chart', style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The precise starting degree of each of the twelve houses, and the '
          'planets that fall on each cusp.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.md,
          child: Column(
            children: [
              _row(const ['H', 'CUSP', 'SIGN', 'PLANETS'], isHeader: true),
              for (int i = 0; i < _rows.length; i++)
                _row(_rows[i], last: i == _rows.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(List<String> cells, {bool isHeader = false, bool last = false}) {
    final headerStyle = AppText.sans(
        size: 9,
        weight: FontWeight.w700,
        color: AppColors.textPrimary.withValues(alpha: 0.4),
        letterSpacing: 0.8);
    Widget cell(int i, int flex, {Color? color}) => Expanded(
          flex: flex,
          child: Text(cells[i],
              style: isHeader
                  ? headerStyle
                  : AppText.sans(size: 12, color: color ?? AppColors.textPrimary)),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.textPrimary.withValues(alpha: 0.02) : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          cell(0, 2, color: AppColors.gold),
          cell(1, 3, color: AppColors.textTan),
          cell(2, 3),
          cell(3, 5, color: AppColors.amber),
        ],
      ),
    );
  }
}
