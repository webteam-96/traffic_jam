import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';
import '../../models/kundli_profile.dart';
import '../../services/chart_api.dart';
import '../../services/api_client.dart';
import 'dasha_timeline_screen.dart';

const _monthNamesFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

DateTime _parseUtc(String iso) {
  final raw = DateTime.parse(iso);
  final utc = raw.isUtc
      ? raw
      : DateTime.utc(raw.year, raw.month, raw.day, raw.hour, raw.minute,
          raw.second, raw.millisecond, raw.microsecond);
  return utc.toLocal();
}

String _formatDeg(double deg) {
  final wholeDeg = deg.floor();
  final minutes = ((deg - wholeDeg) * 60).round();
  if (minutes == 60) {
    return "${(wholeDeg + 1).toString().padLeft(2, '0')}°00'";
  }
  return "${wholeDeg.toString().padLeft(2, '0')}°${minutes.toString().padLeft(2, '0')}'";
}

String _monthYear(DateTime d) => '${_monthNamesFull[d.month - 1].toUpperCase()} ${d.year}';
String _dateShort(DateTime d) =>
    '${d.day} ${_monthNamesFull[d.month - 1].substring(0, 3)} ${d.year}';

double _elapsedFraction(DateTime start, DateTime end) {
  final total = end.difference(start).inMilliseconds;
  if (total <= 0) return 1.0;
  final elapsed = DateTime.now().difference(start).inMilliseconds;
  return (elapsed / total).clamp(0.0, 1.0);
}

Map<String, dynamic>? _currentOf(List<dynamic> periods) {
  for (final p in periods) {
    if ((p as Map<String, dynamic>)['current'] == true) return p;
  }
  return null;
}

/// Kundli detail — Business Flow §5.2. Six sections behind one top-level
/// PillToggle: Planet, Vimshottari Dasha, Charts (D1/D9/D10/D60 selector,
/// North/South style toggle), KP System, Cusp Chart. Works for the user's own
/// chart (`profile` omitted) or a generated one (family/friend). Only "My
/// Kundli" is wired to GET /chart and /dasha — a generated family/friend
/// profile has no backend behind it yet (see KundliProfile), so that path
/// keeps its illustrative mock content unchanged.
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

  Map<String, dynamic>? _chart;
  Map<String, dynamic>? _dasha;
  bool _loading = false;
  String? _error; // 'no-data' | 'generic' | null

  static const _sections = ['Planet', 'Dasha', 'Charts', 'KP System', 'Cusp'];

  KundliProfile get _profile => widget.profile ?? KundliProfile.own;

  @override
  void initState() {
    super.initState();
    if (_profile.isOwn) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chart = await ChartApi.getChart();
      final dasha = await ChartApi.getDasha();
      if (!mounted) return;
      setState(() {
        _chart = chart;
        _dasha = dasha;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (e.code == 'NO_CHART' || e.code == 'NO_DASHA') ? 'no-data' : 'generic';
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
    if (profile.isOwn && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (profile.isOwn && _error == 'no-data') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: AppSpacing.xxl),
        child: Center(
          child: Text('Save your birth details first to see your Kundli.',
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    if (profile.isOwn && _error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: AppSpacing.xxl),
        child: Center(
          child: Text("Couldn't load your birth chart — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final chart = profile.isOwn ? _chart : null;
    final dasha = profile.isOwn ? _dasha : null;

    switch (_section) {
      case 0:
        return _PlanetTab(chart: chart);
      case 1:
        return _DashaTab(dasha: dasha);
      case 2:
        return _ChartsTab(
          profile: profile,
          chart: chart,
          chartIndex: _chartIndex,
          southIndian: _southIndian,
          onChartChanged: (i) => setState(() => _chartIndex = i),
          onStyleChanged: (v) => setState(() => _southIndian = v),
        );
      case 3:
        return _KpTab(chart: chart);
      case 4:
      default:
        return _CuspTab(chart: chart);
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
  const _PlanetTab({this.chart});

  final Map<String, dynamic>? chart;

  static const _mockRows = <_PlanetRow>[
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
    final d1 = chart == null ? null : chart!['d1'] as List<dynamic>;
    final moonNakshatra = chart == null ? null : chart!['nakshatra'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Planetary Positions',
            style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Tap any planet for its exact placement.',
          style: AppText.sans(size: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: AppRadius.md,
          child: Column(
            children: [
              _row(const ['GRAHA', 'RASHI', 'DEG', 'H'], isHeader: true),
              if (d1 != null)
                for (int i = 0; i < d1.length; i++)
                  _tapRowReal(context, d1[i] as Map<String, dynamic>,
                      moonNakshatra: (d1[i]['planet'] as String) == 'Moon' ? moonNakshatra : null,
                      last: i == d1.length - 1)
              else
                for (int i = 0; i < _mockRows.length; i++)
                  _tapRow(context, _mockRows[i], last: i == _mockRows.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tapRowReal(BuildContext context, Map<String, dynamic> p,
      {String? moonNakshatra, required bool last}) {
    final retro = p['retrograde'] as bool;
    final degree = '${_formatDeg(p['degreeInSign'] as double)}${retro ? ' R' : ''}';
    final house = p['house'] as int?;
    return InkWell(
      onTap: () => _showExplainerReal(context, p, moonNakshatra),
      child: _row(
        [p['planet'] as String, p['sign'] as String, degree, house == null ? '—' : '$house'],
        last: last,
      ),
    );
  }

  Widget _tapRow(BuildContext context, _PlanetRow r, {required bool last}) {
    return InkWell(
      onTap: () => _showExplainer(context, r),
      child: _row(
        [r.graha, r.sign, r.degree, '${r.house}'],
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
          cell(2, 4, color: AppColors.textMuted),
          cell(3, 2, align: TextAlign.center),
        ],
      ),
    );
  }

  void _showExplainerReal(BuildContext context, Map<String, dynamic> p, String? moonNakshatra) {
    final planet = p['planet'] as String;
    final sign = p['sign'] as String;
    final house = p['house'] as int?;
    final retro = p['retrograde'] as bool;
    final buffer = StringBuffer('$planet is placed in $sign');
    if (house != null) buffer.write(', house $house');
    buffer.write('.');
    if (moonNakshatra != null) buffer.write(' Moon Nakshatra: $moonNakshatra.');
    if (retro) buffer.write(' Currently retrograde.');

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
                  Text(planet,
                      style:
                          AppText.serif(size: 22, color: AppColors.textPrimary)),
                  const SizedBox(width: AppSpacing.sm),
                  Text('in $sign',
                      style: AppText.sans(size: 14, color: AppColors.gold)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_formatDeg(p['degreeInSign'] as double)}${house != null ? ' · House $house' : ''}',
                style: AppText.sans(size: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(buffer.toString(),
                  style: AppText.sans(
                      size: 14, color: AppColors.textCream, height: 1.5)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
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
  const _DashaTab({this.dasha});

  final Map<String, dynamic>? dasha;

  @override
  Widget build(BuildContext context) {
    if (dasha == null) return _mock(context);

    final maha = _currentOf(dasha!['maha'] as List<dynamic>);
    final antar = _currentOf(dasha!['antar'] as List<dynamic>);
    if (maha == null) return _mock(context);

    final mahaStart = _parseUtc(maha['start'] as String);
    final mahaEnd = _parseUtc(maha['end'] as String);
    final mahaLord = maha['lord'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vimshottari Dasha',
            style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The planetary period you are living through now.',
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
                        Text('$mahaLord Mahadasha',
                            style: AppText.serif(size: 18, weight: FontWeight.w600)),
                        Text('ENDS ${_monthYear(mahaEnd)}',
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
                '$mahaLord Mahadasha runs from ${_dateShort(mahaStart)} to ${_dateShort(mahaEnd)}.',
                style: AppText.sans(
                    size: 13, color: AppColors.textCream, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              MeterBar(label: 'Mahadasha elapsed', value: _elapsedFraction(mahaStart, mahaEnd)),
              if (antar != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(height: 1, color: AppColors.borderFaint),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const SectionLabel('Current Antardasha'),
                    const Spacer(),
                    Text(antar['lord'] as String,
                        style: AppText.sans(size: 13, color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${antar['lord']} Antardasha runs from ${_dateShort(_parseUtc(antar['start'] as String))} '
                  'to ${_dateShort(_parseUtc(antar['end'] as String))}, within the $mahaLord Mahadasha.',
                  style: AppText.sans(
                      size: 13, color: AppColors.textMuted, height: 1.5),
                ),
              ],
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

  Widget _mock(BuildContext context) {
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
    this.chart,
  });

  final KundliProfile profile;
  final int chartIndex;
  final bool southIndian;
  final ValueChanged<int> onChartChanged;
  final ValueChanged<bool> onStyleChanged;
  final Map<String, dynamic>? chart;

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
  static const _jsonKeys = ['d1', 'd9', 'd10', 'd60'];

  // House (1..12) → planet abbreviations, relative to each varga's ascendant.
  static const List<Map<int, String>> _mockHouses = [
    {1: 'As', 3: 'Ra', 4: 'Mo', 5: 'Ju', 7: 'Sa', 9: 'Ke', 10: 'Su\nMa', 11: 'Me\nVe'},
    {1: 'As\nJu', 2: 'Ra', 3: 'Ma', 5: 'Su\nMe', 7: 'Sa', 8: 'Ke', 9: 'Mo', 11: 'Ve'},
    {1: 'As', 2: 'Su', 4: 'Ra', 5: 'Mo\nMe', 6: 'Ma', 8: 'Ju', 10: 'Sa\nVe', 12: 'Ke'},
    {1: 'As\nSa', 3: 'Mo', 4: 'Ju', 6: 'Ke', 7: 'Su\nVe', 9: 'Ra', 10: 'Ma', 11: 'Me'},
  ];

  // Ascendant sign index per varga (0=Aries..11=Pisces) — for South layout only.
  static const _mockAscendantSign = [4, 9, 0, 3]; // Leo, Capricorn, Aries, Cancer

  static const _legend = [
    ['As', 'Ascendant'], ['Su', 'Sun'], ['Mo', 'Moon'], ['Ma', 'Mars'],
    ['Me', 'Mercury'], ['Ju', 'Jupiter'], ['Ve', 'Venus'], ['Sa', 'Saturn'],
    ['Ra', 'Rahu'], ['Ke', 'Ketu'],
  ];

  bool get _isD60 => chartIndex == 3;

  List<dynamic>? get _planets => chart == null ? null : chart![_jsonKeys[chartIndex]] as List<dynamic>;

  bool get _d60Locked =>
      chart == null ? (_isD60 && profile.tobUnknown) : (_isD60 && (chart!['d60'] as List).isEmpty);

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
        if (chartIndex == 0) ...[_styleToggle(), const SizedBox(height: AppSpacing.lg)],
        if (_d60Locked)
          _lockedNotice()
        else if (chart == null)
          _mockChartCard()
        else if (chartIndex == 0)
          _realD1ChartCard()
        else
          _realVargaSignList(_planets!),
        const SizedBox(height: AppSpacing.lg),
        Text(_notes[chartIndex],
            textAlign: TextAlign.center,
            style: AppText.sans(size: 13, color: AppColors.textTan, height: 1.55)),
        if (_isD60 && !_d60Locked) ...[
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

  Widget _mockChartCard() {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: southIndian
              ? SouthChartPainter(_mockHouses[chartIndex], _mockAscendantSign[chartIndex])
              : NorthChartPainter(_mockHouses[chartIndex]),
        ),
      ),
    );
  }

  // Real D1 has per-planet house numbers (from the natal ascendant), so it
  // can be drawn in the same diamond/grid painters as the mock, just fed
  // real placements instead of hardcoded ones.
  Widget _realD1ChartCard() {
    final ascendant = chart!['ascendant'] as Map<String, dynamic>;
    final ascendantSignIndex = ascendant['signIndex'] as int;
    final houses = housesFromD1(_planets!);
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: southIndian
              ? SouthChartPainter(houses, ascendantSignIndex)
              : NorthChartPainter(houses),
        ),
      ),
    );
  }

  // D9/D10/D60 only carry each planet's sign (the backend doesn't compute a
  // varga-Lagna house position), so — rather than guess at house placement —
  // these are shown as a real sign table instead of the diamond chart.
  Widget _realVargaSignList(List<dynamic> planets) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Column(
        children: [
          for (int i = 0; i < planets.length; i++)
            _vargaRow(planets[i] as Map<String, dynamic>, last: i == planets.length - 1),
        ],
      ),
    );
  }

  Widget _vargaRow(Map<String, dynamic> p, {required bool last}) {
    final retro = p['retrograde'] as bool;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(p['planet'] as String,
                  style: AppText.sans(size: 13, color: AppColors.gold))),
          Expanded(
              flex: 4,
              child: Text(p['sign'] as String,
                  style: AppText.sans(size: 13, color: AppColors.textPrimary))),
          Expanded(
              flex: 3,
              child: Text(
                  '${_formatDeg(p['degreeInSign'] as double)}${retro ? ' R' : ''}',
                  textAlign: TextAlign.right,
                  style: AppText.sans(size: 13, color: AppColors.textMuted))),
        ],
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
    List<String> vargottamaPlanets = const ['Jupiter', 'Venus']; // mock fallback
    if (chart != null) {
      final d1 = chart!['d1'] as List<dynamic>;
      final d9 = chart!['d9'] as List<dynamic>;
      vargottamaPlanets = [
        for (final p1 in d1)
          if (d9.any((p9) =>
              (p9 as Map<String, dynamic>)['planet'] == (p1 as Map<String, dynamic>)['planet'] &&
              p9['signIndex'] == p1['signIndex']))
            p1['planet'] as String,
      ];
      if (vargottamaPlanets.isEmpty) return const SizedBox.shrink();
    }

    final list = vargottamaPlanets.length == 1
        ? vargottamaPlanets.first
        : '${vargottamaPlanets.sublist(0, vargottamaPlanets.length - 1).join(', ')} and ${vargottamaPlanets.last}';

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
              '$list ${vargottamaPlanets.length == 1 ? "is" : "are"} Vargottama — placed in '
              'the same sign in both the Rashi and Navamsha charts, which strengthens '
              '${vargottamaPlanets.length == 1 ? "it" : "them"} considerably.',
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

// ─────────────────────────────────────────────────────────────────────────────
// 4) KP System tab — cuspal sub-lord table
// ─────────────────────────────────────────────────────────────────────────────
class _KpTab extends StatelessWidget {
  const _KpTab({this.chart});

  final Map<String, dynamic>? chart;

  // House, Sign, Star (Nakshatra) Lord, Sub Lord.
  static const _mockRows = <List<String>>[
    ['1', 'Leo', 'Sun', 'Venus'], ['2', 'Virgo', 'Mercury', 'Saturn'],
    ['3', 'Libra', 'Venus', 'Mercury'], ['4', 'Scorpio', 'Ketu', 'Mars'],
    ['5', 'Sagittarius', 'Jupiter', 'Rahu'], ['6', 'Capricorn', 'Saturn', 'Sun'],
    ['7', 'Aquarius', 'Saturn', 'Moon'], ['8', 'Pisces', 'Jupiter', 'Ketu'],
    ['9', 'Aries', 'Mars', 'Venus'], ['10', 'Taurus', 'Venus', 'Jupiter'],
    ['11', 'Gemini', 'Mercury', 'Saturn'], ['12', 'Cancer', 'Moon', 'Mars'],
  ];

  @override
  Widget build(BuildContext context) {
    final cusps = chart == null ? null : chart!['cusps'] as List<dynamic>;
    final locked = chart != null && cusps!.isEmpty;

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
        if (locked)
          _lockedNotice()
        else ...[
          const SectionLabel('CUSPAL SUB-LORDS'),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            radius: AppRadius.md,
            child: Column(
              children: [
                _row(const ['HOUSE', 'SIGN', 'STAR LORD', 'SUB LORD'], isHeader: true),
                if (cusps != null)
                  for (int i = 0; i < cusps.length; i++)
                    _rowReal(cusps[i] as Map<String, dynamic>, last: i == cusps.length - 1)
                else
                  for (int i = 0; i < _mockRows.length; i++)
                    _row(_mockRows[i], last: i == _mockRows.length - 1),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _lockedNotice() {
    return GlassCard(
      fill: AppColors.critical,
      fillOpacity: 0.12,
      borderColor: AppColors.criticalText.withValues(alpha: 0.4),
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 32, color: AppColors.criticalText),
          const SizedBox(height: AppSpacing.md),
          Text('Requires exact birth time',
              style: AppText.serif(size: 16, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'KP sub-lords depend on the Placidus house cusps, which need a birth '
            'time exact to the minute.',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 12, color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _rowReal(Map<String, dynamic> c, {required bool last}) {
    final lordship = c['lordship'] as Map<String, dynamic>;
    return _row([
      '${c['house']}',
      c['sign'] as String,
      lordship['starLord'] as String,
      lordship['subLord'] as String,
    ], last: last);
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

// ─────────────────────────────────────────────────────────────────────────────
// 5) Cusp Chart tab — precise cusp degree + planets at each of the 12 houses
// ─────────────────────────────────────────────────────────────────────────────
class _CuspTab extends StatelessWidget {
  const _CuspTab({this.chart});

  final Map<String, dynamic>? chart;

  // House, Cusp degree, Sign, Planets at cusp (— if none).
  static const _mockRows = <List<String>>[
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
    final cusps = chart == null ? null : chart!['cusps'] as List<dynamic>;
    final locked = chart != null && cusps!.isEmpty;

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
        if (locked)
          _lockedNotice()
        else
          GlassCard(
            padding: EdgeInsets.zero,
            radius: AppRadius.md,
            child: Column(
              children: [
                _row(const ['H', 'CUSP', 'SIGN', 'PLANETS'], isHeader: true),
                if (cusps != null)
                  for (int i = 0; i < cusps.length; i++)
                    _rowReal(cusps[i] as Map<String, dynamic>, last: i == cusps.length - 1)
                else
                  for (int i = 0; i < _mockRows.length; i++)
                    _row(_mockRows[i], last: i == _mockRows.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lockedNotice() {
    return GlassCard(
      fill: AppColors.critical,
      fillOpacity: 0.12,
      borderColor: AppColors.criticalText.withValues(alpha: 0.4),
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 32, color: AppColors.criticalText),
          const SizedBox(height: AppSpacing.md),
          Text('Requires exact birth time',
              style: AppText.serif(size: 16, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'House cusps need a birth time exact to the minute.',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 12, color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _rowReal(Map<String, dynamic> c, {required bool last}) {
    final planets = (c['planets'] as List<dynamic>).cast<String>();
    return _row([
      '${c['house']}',
      _formatDeg(c['degreeInSign'] as double),
      c['sign'] as String,
      planets.isEmpty ? '—' : planets.join(', '),
    ], last: last);
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
