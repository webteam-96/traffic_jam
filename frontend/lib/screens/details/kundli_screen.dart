import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';
import '../../models/kundli_profile.dart';
import '../../services/chart_api.dart';
import '../../services/dosha_api.dart';
import '../../services/api_client.dart';
import '../../services/user_api.dart';
import '../../services/kundli_pdf_service.dart';
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

/// Generic "how to read this" explainer — same visual language as the
/// Charts tab's existing sensitivity/vargottama notes, reused across tabs.
/// Never personalised to the profile being viewed; just teaches the format.
Widget _howToReadNote(String text) {
  return GlassCard(
    radius: AppRadius.sm,
    fill: AppColors.amber,
    fillOpacity: 0.08,
    borderColor: AppColors.gold.withValues(alpha: 0.3),
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.menu_book_outlined, size: 16, color: AppColors.gold),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              style: AppText.sans(size: 12, color: AppColors.textTan, height: 1.45)),
        ),
      ],
    ),
  );
}

/// Kundli detail — Business Flow §5.2. Six sections behind one top-level
/// PillToggle: Planet, Vimshottari Dasha, Charts (D1/D9/D10/D60 selector,
/// North/South style toggle), KP System, Cusp Chart. Works for the user's own
/// chart (`profile` omitted, wired to GET /chart and /dasha) or a generated
/// family/friend one (its chart/dasha were already computed by
/// get_kundli_screen.dart via POST /chart/compute and travel with the
/// KundliProfile — no extra fetch needed here).
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
  Map<String, dynamic>? _doshas;
  bool _loading = false;
  String? _error; // 'no-data' | 'generic' | null

  static const _sections = ['Planet', 'Dasha', 'Charts', 'KP System', 'Cusp', 'Doshas'];

  KundliProfile get _profile => widget.profile ?? KundliProfile.own;

  @override
  void initState() {
    super.initState();
    if (_profile.isOwn) {
      _load();
    } else {
      // Already computed by get_kundli_screen.dart before this screen was
      // pushed — nothing to fetch.
      _chart = _profile.chart;
      _dasha = _profile.dasha;
      _doshas = _profile.doshas;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chart = await ChartApi.getChart();
      final dasha = await ChartApi.getDasha();
      // Doshas need a saved chart too, but a failure here (e.g. a transient
      // error) shouldn't block the rest of the Kundli — it just leaves the
      // Doshas tab showing its own empty state.
      Map<String, dynamic>? doshas;
      try {
        doshas = await DoshaApi.getDoshas();
      } catch (_) {
        doshas = null;
      }
      if (!mounted) return;
      setState(() {
        _chart = chart;
        _dasha = dasha;
        _doshas = doshas;
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

  bool _exporting = false;

  /// Builds the same downloadable PDF the report's Share icon offers —
  /// cover page, birth details, every chart the app computes as a diamond +
  /// table, Dasha, KP cusps and Doshas — then hands it to the OS share sheet
  /// (Printing.sharePdf), whose "Save to Files" is this app's download.
  Future<void> _downloadPdf(KundliProfile profile) async {
    if (_chart == null && profile.chart == null) {
      toast(context, "Nothing to export yet — save birth details first.");
      return;
    }
    setState(() => _exporting = true);
    try {
      String name = profile.name;
      String dob = profile.dob;
      String tob = profile.tob;
      String place = profile.place;
      if (profile.isOwn) {
        final birthData = await UserApi.getBirthData();
        if (birthData != null) {
          final dobDate = DateTime.parse(birthData['dob'] as String);
          dob = '${dobDate.day} ${_monthNamesFull[dobDate.month - 1]} ${dobDate.year}';
          final tobRaw = birthData['tob'] as String?;
          final unknownTime = birthData['unknownTime'] as bool? ?? false;
          if (!unknownTime && tobRaw != null) {
            final parts = tobRaw.split(':');
            final hour24 = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            final isAm = hour24 < 12;
            final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
            tob = '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} ${isAm ? "AM" : "PM"}';
          } else {
            tob = '';
          }
          place = birthData['place'] as String? ?? place;
          name = (birthData['name'] as String?)?.trim().isNotEmpty == true
              ? birthData['name'] as String
              : name;
        }
      }

      final bytes = await KundliPdfService.generate(
        name: name,
        dobDisplay: dob,
        tobDisplay: tob,
        place: place,
        chart: profile.isOwn ? _chart : profile.chart,
        dasha: profile.isOwn ? _dasha : profile.dasha,
        doshas: profile.isOwn ? _doshas : profile.doshas,
      );

      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: '${name.replaceAll(' ', '_')}_kundli.pdf');
    } catch (_) {
      if (mounted) toast(context, "Couldn't generate the PDF — try again.");
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return DetailScaffold(
      title: profile.isOwn ? 'My Kundli' : profile.name,
      actions: [
        IconButton(
          onPressed: _exporting ? null : () => _downloadPdf(profile),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                )
              : const Icon(Icons.ios_share, size: 18, color: AppColors.textPrimary),
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
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.gold)),
        ),
      );
    }

    if (_error == 'no-data') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: AppSpacing.xxl),
        child: Center(
          child: Text('Save your birth details first to see your Kundli.',
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: AppSpacing.xxl),
        child: Center(
          child: Text("Couldn't load your birth chart — check your connection.",
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final chart = _chart;
    final dasha = _dasha;

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
        return _CuspTab(chart: chart);
      case 5:
      default:
        return _DoshaTab(doshas: _doshas);
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
        const SizedBox(height: AppSpacing.md),
        _howToReadNote(
          'Each row is one graha (planet): its Rashi (zodiac sign), exact '
          "degree within that sign, and House — the life area it's currently "
          "colouring. Sign shows how a planet expresses itself; house shows "
          "where in your life.",
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
        const SizedBox(height: AppSpacing.md),
        _howToReadNote(
          'Vimshottari Dasha splits your whole life into planetary periods '
          "(Mahadashas) in a fixed 120-year cycle — the order and length of "
          "each one is set by your Moon's Nakshatra at birth, not random. "
          'Inside every Mahadasha runs a shorter Antardasha, blending that '
          "period's ruling planet with another's. A planet's own house and "
          'sign shape what its period tends to bring.',
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

  bool get _isD1 => chartIndex == 0;
  bool get _isD60 => chartIndex == 3;

  List<dynamic>? get _planets => chart == null ? null : chart![_jsonKeys[chartIndex]] as List<dynamic>;

  bool get _d60Locked =>
      chart == null ? (_isD60 && profile.tobUnknown) : (_isD60 && (chart!['d60'] as List).isEmpty);

  // D1's houses (and the Ascendant they're counted from) need a real clock
  // time the same way D60 does — see AstroModels.cs's BirthChartResult doc
  // comment. Unlike D60, the `d1` planet list itself is never empty (only
  // each planet's `house` is null), so this checks the Ascendant's own
  // `known` flag rather than array emptiness.
  bool get _d1Locked => chart == null
      ? (_isD1 && profile.tobUnknown)
      : (_isD1 && (chart!['ascendant'] as Map<String, dynamic>)['known'] != true);

  // Every chart's own Lagna (house 1) — D1's from `ascendant`, each varga's
  // from its own `d9AscendantSignIndex`/etc. (see AstroModels.cs's
  // BirthChartResult doc comment). Null for D9/D10 when the birth time is
  // unknown — their planet *signs* are still valid then, just not houses —
  // which is exactly when this chart falls back to a plain sign list below
  // instead of a diamond with nowhere honest to put "house 1".
  int? get _ascendantSignIndexForCurrentChart {
    if (chart == null) return null;
    return switch (chartIndex) {
      0 => (chart!['ascendant'] as Map<String, dynamic>)['signIndex'] as int?,
      1 => chart!['d9AscendantSignIndex'] as int?,
      2 => chart!['d10AscendantSignIndex'] as int?,
      _ => chart!['d60AscendantSignIndex'] as int?,
    };
  }

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
        const SizedBox(height: AppSpacing.md),
        _howToReadNote(
          "Each numbered slot in the diamond is a house, counted from your "
          "Ascendant (marked 'As') as House 1. Planets listed in a slot are "
          "placed in that house for this chart. Every divisional chart "
          "(D1, D9, D10, D60...) re-slices the same birth moment through a "
          "different lens — the houses and placements shift, the underlying "
          "birth data doesn't.",
        ),
        const SizedBox(height: AppSpacing.lg),
        if (chartIndex == 0) ...[_styleToggle(), const SizedBox(height: AppSpacing.lg)],
        if (_d60Locked)
          _lockedNotice(
            'Shastiamsha shifts with just a few minutes\' difference. '
            '${profile.isOwn ? "You" : profile.name} marked the birth time as unknown, '
            'so this chart is hidden.',
          )
        else if (_d1Locked)
          _lockedNotice(
            'The Lagna (Ascendant) needs a real clock time to place any planet '
            'into a house. ${profile.isOwn ? "You" : profile.name} marked the birth '
            'time as unknown, so this chart can\'t be drawn.',
          )
        else if (chart == null)
          _mockChartCard()
        else if (_ascendantSignIndexForCurrentChart != null) ...[
          _realChartCard(_ascendantSignIndexForCurrentChart!, _planets!),
          const SizedBox(height: AppSpacing.lg),
          _realVargaSignList(_planets!),
        ] else
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

  // Every chart with a known Lagna — D1 and, now, D9/D10/D60 — has
  // per-planet house numbers, so all of them draw in the same diamond/grid
  // painters as the mock, just fed real placements instead of hardcoded ones.
  Widget _realChartCard(int ascendantSignIndex, List<dynamic> planets) {
    final houses = housesFromPlanets(planets);
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

  // The table alongside every diamond — same planet/sign/degree/house
  // columns as the Planet tab, just scoped to whichever chart is selected
  // here. Also stands alone (no House column filled in) for D9/D10 when the
  // birth time is unknown and there's no honest house to show.
  Widget _realVargaSignList(List<dynamic> planets) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Column(
        children: [
          _vargaRow(const {'planet': 'GRAHA', 'sign': 'RASHI', 'degreeInSign': 'DEG', 'house': 'H'},
              isHeader: true, last: false),
          for (int i = 0; i < planets.length; i++)
            _vargaRow(planets[i] as Map<String, dynamic>, last: i == planets.length - 1),
        ],
      ),
    );
  }

  Widget _vargaRow(Map<String, dynamic> p, {bool isHeader = false, required bool last}) {
    final headerStyle = AppText.sans(
        size: 9,
        weight: FontWeight.w700,
        color: AppColors.textPrimary.withValues(alpha: 0.4),
        letterSpacing: 0.8);
    final degreeCell = isHeader
        ? p['degreeInSign'] as String
        : '${_formatDeg(p['degreeInSign'] as double)}${(p['retrograde'] as bool) ? ' R' : ''}';
    final houseCell = isHeader ? p['house'] as String : (p['house'] as int?)?.toString() ?? '—';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: isHeader ? 10 : 13),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.textPrimary.withValues(alpha: 0.02) : null,
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(p['planet'] as String,
                  style: isHeader ? headerStyle : AppText.sans(size: 13, color: AppColors.gold))),
          Expanded(
              flex: 4,
              child: Text(p['sign'] as String,
                  style: isHeader
                      ? headerStyle
                      : AppText.sans(size: 13, color: AppColors.textPrimary))),
          Expanded(
              flex: 3,
              child: Text(degreeCell,
                  textAlign: TextAlign.right,
                  style: isHeader ? headerStyle : AppText.sans(size: 13, color: AppColors.textMuted))),
          Expanded(
              flex: 2,
              child: Text(houseCell,
                  textAlign: TextAlign.center,
                  style: isHeader ? headerStyle : AppText.sans(size: 13, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _lockedNotice(String detail) {
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
                  detail,
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
        const SizedBox(height: AppSpacing.md),
        _howToReadNote(
          'Every house cusp has three rulers: the Sign Lord (rules the sign '
          'the cusp falls in), the Star Lord (rules the Nakshatra at that '
          'exact degree), and the Sub Lord (a finer 249-part division within '
          'the Nakshatra). In KP, the Sub Lord is treated as the real '
          "decision-maker for that house — often weighted above the sign.",
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

// ─────────────────────────────────────────────────────────────────────────────
// Doshas tab — Mangal Dosha, Kaal Sarp Dosha (natal), Sade Sati (transit).
// Wired to GET /doshas (own chart) or the doshas POST /chart/compute already
// returned (a friend/family profile) — see DoshaEndpoints.cs/DoshaService.cs.
// Pitra Dosha is deliberately absent: no single classical rule for it is
// settled enough to compute as fact — that stays an Ask Jay question.
// ─────────────────────────────────────────────────────────────────────────────
class _DoshaTab extends StatelessWidget {
  const _DoshaTab({this.doshas});

  final Map<String, dynamic>? doshas;

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    final month = _monthsShort[int.parse(parts[1]) - 1];
    return '${int.parse(parts[2])} $month ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (doshas == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: AppSpacing.xxl),
        child: Center(
          child: Text('Save your birth details first to see your doshas.',
              textAlign: TextAlign.center, style: AppText.body),
        ),
      );
    }

    final mangal = doshas!['mangal'] as Map<String, dynamic>;
    final kaalSarp = doshas!['kaalSarp'] as Map<String, dynamic>;
    final sadeSati = doshas!['sadeSati'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Doshas', style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Classical placement checks — Mangal Dosha and Kaal Sarp Dosha from '
          'your birth chart, Sade Sati from where Saturn is transiting today.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        _mangalCard(mangal),
        const SizedBox(height: AppSpacing.lg),
        _kaalSarpCard(kaalSarp),
        const SizedBox(height: AppSpacing.lg),
        _sadeSatiCard(sadeSati),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Pitra Dosha isn\'t shown here — classical texts don\'t agree on a single '
          'rule for it, so it stays a question for Ask Jay rather than an automated flag.',
          style: AppText.sans(size: 12, color: AppColors.textMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _statusHeader(bool isPresent, String presentLabel, String absentLabel) {
    return Row(
      children: [
        IconChip(
          child: Icon(isPresent ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 18, color: isPresent ? AppColors.amber : AppColors.success),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(isPresent ? presentLabel : absentLabel,
              style: AppText.serif(size: 18, weight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _mangalCard(Map<String, dynamic> mangal) {
    final fromLagna = mangal['fromLagna'] as bool?;
    final fromMoon = mangal['fromMoon'] as bool;
    final fromVenus = mangal['fromVenus'] as bool;
    final marsDignified = mangal['marsInOwnOrExaltedSign'] as bool;
    final isManglik = fromLagna ?? (fromMoon || fromVenus);

    return GlassCard(
      goldTopBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusHeader(isManglik, 'Manglik', 'Not Manglik'),
          const SizedBox(height: AppSpacing.lg),
          if (fromLagna == null)
            Text(
              'Birth time unknown — the Lagna-based check (the primary one) needs an '
              'exact time. Shown below are the Moon- and Venus-based checks only.',
              style: AppText.sans(size: 12, color: AppColors.textMuted, height: 1.5),
            )
          else
            _doshaRow('From Lagna', fromLagna, 'House ${mangal['houseFromLagna']}'),
          const SizedBox(height: AppSpacing.sm),
          _doshaRow('From Moon', fromMoon, 'House ${mangal['houseFromMoon']}'),
          const SizedBox(height: AppSpacing.sm),
          _doshaRow('From Venus', fromVenus, 'House ${mangal['houseFromVenus']}'),
          if (marsDignified) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(height: 1, color: AppColors.borderFaint),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Mars sits in its own or exalted sign here — classically this is the most '
              'commonly cited condition that weakens or cancels the dosha.',
              style: AppText.sans(size: 12, color: AppColors.amber, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kaalSarpCard(Map<String, dynamic> kaalSarp) {
    final isPresent = kaalSarp['isPresent'] as bool;
    final subType = kaalSarp['subType'] as String?;
    final rahuHouse = kaalSarp['rahuHouseFromLagna'] as int?;

    return GlassCard(
      goldTopBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusHeader(isPresent, 'Kaal Sarp Dosha Present', 'No Kaal Sarp Dosha'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isPresent
                ? (subType != null
                    ? '$subType Kaal Sarp — Rahu sits in house $rahuHouse from your Lagna, with '
                        'all seven other grahas hemmed to one side of the Rahu-Ketu axis.'
                    : 'All seven other grahas are hemmed to one side of the Rahu-Ketu axis. '
                        '(The named sub-type needs a known birth time.)')
                : 'Not all planets fall on one side of the Rahu-Ketu axis.',
            style: AppText.sans(size: 13, color: AppColors.textCream, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _sadeSatiCard(Map<String, dynamic> sadeSati) {
    final isActive = sadeSati['isActive'] as bool;
    final phase = sadeSati['phase'] as String?;

    return GlassCard(
      goldTopBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusHeader(isActive, 'Sade Sati Active${phase != null ? " — $phase Phase" : ""}',
              'Sade Sati Not Active'),
          if (isActive) ...[
            const SizedBox(height: AppSpacing.lg),
            _doshaDateRow('Phase started', sadeSati['phaseStartedOn'] as String),
            const SizedBox(height: AppSpacing.sm),
            _doshaDateRow('Phase ends', sadeSati['phaseEndsOn'] as String),
            const SizedBox(height: AppSpacing.sm),
            _doshaDateRow('Full cycle ends', sadeSati['fullCycleEndsOn'] as String),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Transiting Saturn is not currently in the sign before, the same as, or '
              'after your natal Moon.',
              style: AppText.sans(size: 13, color: AppColors.textCream, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _doshaRow(String label, bool present, String detail) {
    return Row(
      children: [
        Icon(present ? Icons.circle : Icons.circle_outlined,
            size: 8, color: present ? AppColors.amber : AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: AppText.sans(size: 13, color: AppColors.textCream)),
        ),
        Text(detail, style: AppText.sans(size: 12, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _doshaDateRow(String label, String isoDate) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppText.sans(size: 13, color: AppColors.textMuted)),
        ),
        Text(_formatDate(isoDate),
            style: AppText.sans(size: 13, weight: FontWeight.w600, color: AppColors.gold)),
      ],
    );
  }
}
