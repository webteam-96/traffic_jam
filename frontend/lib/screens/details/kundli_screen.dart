import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';
import '../../models/kundli_profile.dart';
import '../../services/chart_api.dart';
import '../../services/api_client.dart';
import '../../services/user_api.dart';
import '../../services/pdf_download_service.dart';
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

/// dd-MM-yyyy, zero-padded — the form Dasha boundaries are quoted in. A period
/// hands over on a specific day, and "ENDS APRIL 2036" left the reader to
/// guess which day of that month it was.
String _dateDmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.year}';

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
  int _section = 0; // Charts / KP System / Cusp / Dasha / Planet
  int _chartIndex = 0; // D1 / D9 / D10 / D60
  bool _southIndian = false;

  Map<String, dynamic>? _chart;
  Map<String, dynamic>? _dasha;
  bool _loading = false;
  String? _error; // 'no-data' | 'generic' | null

  // Real name + formatted DOB for "My Kundli" — KundliProfile.own is a
  // static placeholder ("You" / a fixed mock date, see kundli_profile.dart),
  // not the signed-in user's actual birth data, so the identity one-liner
  // below needs its own fetch rather than trusting profile.name/profile.dob
  // for the isOwn case (same reason _downloadPdf already re-fetches this
  // separately for the PDF's cover page).
  String? _ownName;
  String? _ownDobDisplay;

  // Charts first: the diagram is what people open a Kundli for, so it is the
  // landing tab. The tables that read off it follow, then the timeline, then
  // the raw positions.
  static const _sections = ['Charts', 'KP System', 'Cusp', 'Dasha', 'Planet'];

  KundliProfile get _profile => widget.profile ?? KundliProfile.own;

  @override
  void initState() {
    super.initState();
    if (_profile.isOwn) {
      _load();
      _loadOwnIdentity();
    } else {
      // Already computed by get_kundli_screen.dart before this screen was
      // pushed — nothing to fetch.
      _chart = _profile.chart;
      _dasha = _profile.dasha;
    }
  }

  /// Pull-to-refresh. Re-fetches the chart, the dasha and the header identity
  /// together, so a chart recomputed server-side (new birth data saved on
  /// another device, or an engine change) shows up without a reinstall.
  Future<void> _refresh() async {
    await Future.wait([_load(showSpinner: false), _loadOwnIdentity()]);
  }

  Future<void> _loadOwnIdentity() async {
    try {
      final birthData = await UserApi.getBirthData();
      if (birthData == null || !mounted) return;
      final dobDate = DateTime.parse(birthData['dob'] as String);
      setState(() {
        _ownName = (birthData['name'] as String?)?.trim().isNotEmpty == true
            ? birthData['name'] as String
            : null;
        _ownDobDisplay =
            '${dobDate.day} ${_monthNamesFull[dobDate.month - 1]} ${dobDate.year}';
      });
    } catch (_) {
      // Transient error — the header just falls back to the placeholder
      // name/date rather than blocking the rest of the Kundli.
    }
  }

  /// First word of the nakshatra string (e.g. "Krittika" from the chart's
  /// "Krittika-3" pada notation) — the compact identity marker for the
  /// one-liner header, same source as Profile's own Astro Identity card.
  String? _nakshatraLabel(Map<String, dynamic>? chart) {
    final raw = chart?['nakshatra'] as String?;
    if (raw == null || raw.isEmpty) return null;
    return raw.split('-').first;
  }

  Future<void> _load({bool showSpinner = true}) async {
    setState(() {
      // A pull-to-refresh draws its own spinner, so the page keeps showing the
      // chart it already has instead of flashing to the full-screen loader and
      // back.
      if (showSpinner) _loading = true;
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


  bool _exporting = false;

  /// Builds the Kundli PDF — cover page, birth details, every chart the app
  /// computes as a diamond + table, Dasha and KP cusps — and saves it to the
  /// device's Downloads folder.
  ///
  /// This used to hand the PDF to the system share sheet and rely on the user
  /// finding "Save to Files" inside it. That is a share, not a download, and
  /// it didn't work reliably — see PdfDownloadService.
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
      );

      final fileName = '${name.replaceAll(' ', '_')}_Kundli.pdf';
      final location = await PdfDownloadService.save(bytes, fileName);

      if (!mounted) return;
      toast(context, 'Saved to $location — $fileName');
    } on PlatformException catch (e) {
      if (mounted) toast(context, e.message ?? "Couldn't save the PDF.");
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
      // Only the user's own Kundli can be refetched. A generated profile was
      // computed once by get_kundli_screen and handed over — there is no
      // endpoint to pull it again, so it gets no refresh gesture rather than
      // one that silently does nothing.
      onRefresh: profile.isOwn ? _refresh : null,
      actions: [
        IconButton(
          onPressed: _exporting ? null : () => _downloadPdf(profile),
          tooltip: 'Download Kundli PDF',
          // A download arrow, not a share glyph — the action saves the file to
          // the device rather than handing it to another app.
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                )
              : const Icon(Icons.download_outlined, size: 20, color: AppColors.textPrimary),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profile.isOwn) ...[
            // A quick "yes, this is me" confirmation — the one thing missing
            // for "My Kundli" that generated profiles already got from
            // _ProfileBanner below.
            Center(
              child: Text(
                [
                  _ownName ?? profile.name,
                  _ownDobDisplay ?? profile.dob,
                  ?_nakshatraLabel(_chart),
                ].join('  ·  '),
                textAlign: TextAlign.center,
                style: AppText.sans(size: 13, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            _ProfileBanner(profile: profile, nakshatra: _nakshatraLabel(profile.chart)),
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
        child: LoadingView(height: null),
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
        child: RetryView(
          height: null,
          message: "Couldn't load your birth chart",
          onRetry: _refresh,
        ),
      );
    }

    final chart = _chart;
    final dasha = _dasha;

    switch (_section) {
      case 0:
        return _ChartsTab(
          profile: profile,
          chart: chart,
          chartIndex: _chartIndex,
          southIndian: _southIndian,
          onChartChanged: (i) => setState(() => _chartIndex = i),
          onStyleChanged: (v) => setState(() => _southIndian = v),
        );
      case 1:
        return _KpTab(chart: chart);
      case 2:
        return _CuspTab(chart: chart);
      case 3:
        return _DashaTab(dasha: dasha);
      case 4:
      default:
        return _PlanetTab(chart: chart);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generated-profile banner — shown above the tabs for anyone but "My Kundli"
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.profile, this.nakshatra});
  final KundliProfile profile;
  final String? nakshatra;

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
                  [
                    profile.dob,
                    profile.tobUnknown ? 'Time unknown' : profile.tob,
                    profile.place,
                    ?nakshatra,
                  ].join(' · '),
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
              _row(const ['GRAHA', 'RASHI', 'DEGREE', 'HOUSE'], isHeader: true),
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
                        Text('ENDS ${_dateDmy(mahaEnd)}',
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
                '$mahaLord Mahadasha runs from ${_dateDmy(mahaStart)} to ${_dateDmy(mahaEnd)}.',
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
                  '${antar['lord']} Antardasha runs from ${_dateDmy(_parseUtc(antar['start'] as String))} '
                  'to ${_dateDmy(_parseUtc(antar['end'] as String))}, within the $mahaLord Mahadasha.',
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

  // abbreviation, English name, Hindi name. The English name stays because the
  // abbreviations are drawn from it — 'Mo' only explains itself next to 'Moon',
  // not next to 'Chandra'.
  static const _legend = [
    ['As', 'Ascendant', 'लग्न'],
    ['Su', 'Sun', 'सूर्य'],
    ['Mo', 'Moon', 'चंद्र'],
    ['Ma', 'Mars', 'मंगल'],
    ['Me', 'Mercury', 'बुध'],
    ['Ju', 'Jupiter', 'गुरु'],
    ['Ve', 'Venus', 'शुक्र'],
    ['Sa', 'Saturn', 'शनि'],
    ['Ra', 'Rahu', 'राहु'],
    ['Ke', 'Ketu', 'केतु'],
    // Not grahas — shown in the divisional charts only, with no part in any
    // classical rule. No traditional Hindi name exists for them; the ones in
    // modern use are transliterations, so the English name stands alone.
    ['Ura', 'Uranus', ''],
    ['Nep', 'Neptune', ''],
    ['Plu', 'Pluto', ''],
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
  // which is exactly when this chart shows a notice instead of a diamond
  // with nowhere honest to put "house 1".
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
        // Shown on every chart, not just D1. The North/South choice is applied
        // to all four, but the control used to appear only on D1 — so a South
        // Indian selection followed the reader into D9/D10/D60 with no way to
        // change it back, and the two layouts are read completely differently
        // (South fixes the signs to cells; North fixes the houses).
        _styleToggle(),
        const SizedBox(height: AppSpacing.lg),
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
        else if (_ascendantSignIndexForCurrentChart != null)
          _realChartCard(_ascendantSignIndexForCurrentChart!, _planets!)
        else
          // D9/D10 with no birth time: the planet signs are still valid,
          // but there is no Lagna to count houses from, so the diamond
          // has nowhere honest to put house 1. Says so rather than
          // drawing a chart that would be wrong.
          _lockedNotice(
            'This chart needs a real clock time to place the planets into houses. '
            '${profile.isOwn ? "You" : profile.name} marked the birth time as unknown, '
            'so the diagram can\'t be drawn.',
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(_notes[chartIndex],
            textAlign: TextAlign.center,
            style: AppText.sans(size: 13, color: AppColors.textTan, height: 1.55)),
        const SizedBox(height: AppSpacing.lg),
        // Below the diamond, not above it. The chart is what the tab is for
        // and it used to open a full screen of explanation away — you had to
        // scroll to reach the thing you came for.
        _howToReadNote(
          "The diamond's twelve slots are the twelve houses, in fixed "
          "positions — house 1 is always the top-centre slot, marked 'As', "
          "and they run anticlockwise from there. The small number in each "
          "slot is the sign sitting in that house (1 = Aries ... 12 = "
          "Pisces), which is how North Indian charts are labelled everywhere. "
          "Every divisional chart (D1, D9, D10, D60...) re-slices the same "
          "birth moment through a different lens — the signs and placements "
          "shift, the underlying birth data doesn't.",
        ),
        if (_isD60 && !_d60Locked) ...[
          const SizedBox(height: AppSpacing.md),
          _sensitivityNote(),
        ],
        if (chartIndex == 1) ...[
          const SizedBox(height: AppSpacing.md),
          _vargottamaNote(),
        ],
        const SizedBox(height: AppSpacing.section),
        const SectionLabel('CHART ABBREVIATIONS'),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          radius: AppRadius.md,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: [for (final l in _legend) _legendItem(l[0], l[1], l[2])],
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
              : NorthChartPainter(_mockHouses[chartIndex], _mockAscendantSign[chartIndex]),
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
              : NorthChartPainter(houses, ascendantSignIndex),
        ),
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

  Widget _legendItem(String abbr, String name, String hindi) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(abbr,
            style: AppText.sans(
                size: 13, weight: FontWeight.w700, color: AppColors.amber)),
        const SizedBox(width: AppSpacing.xs),
        Text(name, style: AppText.sans(size: 13, color: AppColors.textMuted)),
        const SizedBox(width: AppSpacing.xs),
        // Devanagari has no glyphs in the app's own typefaces; this leans on
        // the platform's font fallback, which is why it isn't styled with
        // AppText.sans like its neighbours.
        Text(hindi,
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: AppColors.textTan)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4) KP System tab — the planets table: position + full lordship chain
// ─────────────────────────────────────────────────────────────────────────────
class _KpTab extends StatelessWidget {
  const _KpTab({this.chart});

  final Map<String, dynamic>? chart;

  @override
  Widget build(BuildContext context) {
    final planets = chart == null ? null : chart!['kp'] as List<dynamic>;
    final locked = chart != null && planets!.isEmpty;

    final cusps = chart == null ? null : chart!['cusps'] as List<dynamic>;
    final significators =
        chart == null ? null : chart!['kpSignificators'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('KP System', style: AppText.serif(size: 22, color: AppColors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A Krishnamurti Paddhati read of your chart — the full lordship '
          'chain behind every planet, for those already familiar with the '
          'system.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (locked)
          _kpLockedNotice('KP lordships are read off the Placidus house cusps, '
              'which need a birth time exact to the minute.')
        else ...[
          // ── 1. The KP (cuspal) chart ──────────────────────────────────
          const SectionLabel('KP CHART'),
          const SizedBox(height: AppSpacing.md),
          if (planets != null && cusps != null)
            _kpCuspChartCard(planets, cusps)
          else
            _kpChartPlaceholder(),
          const SizedBox(height: AppSpacing.lg),
          _howToReadNote(
            'KP places the houses by Placidus, not by whole signs. Each slot '
            'is a house, numbered as always from the top-centre; the small '
            'number is the sign its CUSP falls in. Because Placidus houses '
            'are unequal, the same sign can head two houses and another sign '
            'none — which is why these numbers do not simply run 1..12 the '
            'way they do on the Rashi chart below.',
          ),
          const SizedBox(height: AppSpacing.section),

          // ── 2. The same planets read by sign ──────────────────────────
          const SectionLabel('RASHI CHART'),
          const SizedBox(height: AppSpacing.md),
          if (planets != null)
            _kpRashiChartCard(planets)
          else
            _kpChartPlaceholder(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'The same moment read the ordinary way — planets by sign, houses '
            'counted whole-sign from the Ascendant. Shown beside the KP chart '
            'because the two disagree on purpose: where a planet sits by sign '
            'and which KP house it answers to are different questions.',
            style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.section),

          // ── 3. The lordship chain ─────────────────────────────────────
          const SectionLabel('PLANETS'),
          const SizedBox(height: AppSpacing.sm),
          _howToReadNote(
            'Each position carries four rulers, from coarse to fine: the Sign '
            'Lord rules the sign it falls in, the Nakshatra Lord the star, and '
            'the Sub and Sub-Sub Lords come from dividing that star twice over. '
            'KP treats the Sub Lord as the real decision-maker — often weighted '
            'above the sign itself.',
          ),
          const SizedBox(height: AppSpacing.md),
          KpTable(
            firstColumnLabel: 'Planet',
            rows: [
              if (planets != null)
                for (final p in planets)
                  _kpRow(
                    p as Map<String, dynamic>,
                    label: kpAbbreviation(p['planet'] as String) +
                        ((p['retrograde'] as bool? ?? false) ? '(R)' : ''),
                  )
              else
                ..._mockPlanetRows,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _kpLegend(),
          const SizedBox(height: AppSpacing.section),

          // ── 4. What each planet speaks for ────────────────────────────
          const SectionLabel('PLANET SIGNIFICATORS'),
          const SizedBox(height: AppSpacing.sm),
          _howToReadNote(
            'Which houses each planet speaks for, strongest column first. KP '
            'reads a planet as the agent of the star it sits in, so the houses '
            "of its star lord outrank its own — which is why the star lord's "
            'columns come first. A planet with no entry in a column signifies '
            'nothing at that level: Rahu, Ketu and the outer planets rule no '
            'sign, so they never own a house.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (significators != null && significators.isNotEmpty)
            _significatorTable(significators)
          else
            _kpLockedNotice(
                'Significators are derived from the Placidus cusps, so they '
                'need the same exact birth time the rest of KP does.'),
        ],
      ],
    );
  }

  /// The KP chart: Placidus houses, each slot labelled with its own cusp's
  /// sign rather than a whole-sign walk from the Ascendant.
  Widget _kpCuspChartCard(List<dynamic> planets, List<dynamic> cusps) {
    final houseSigns = <int, int>{
      for (final c in cusps)
        (c as Map<String, dynamic>)['house'] as int: c['signIndex'] as int,
    };

    // Planets carry their real Placidus house from the backend, so the labels
    // come straight off that rather than being re-derived here.
    final labels = <int, String>{};
    for (final entry in planets) {
      final p = entry as Map<String, dynamic>;
      if (p['planet'] == 'Ascendant') continue;
      final house = p['house'] as int?;
      if (house == null) continue;
      final abbr = kpAbbreviation(p['planet'] as String);
      labels[house] = labels.containsKey(house) ? '${labels[house]}\n$abbr' : abbr;
    }
    labels[1] = labels.containsKey(1) ? 'As\n${labels[1]}' : 'As';

    final ascSign = houseSigns[1] ?? 0;
    return _chartCard(
        NorthChartPainter(labels, ascSign, houseSigns: houseSigns));
  }

  /// The Rashi chart from the same KP positions — planets by sign, houses
  /// whole-sign from the Ascendant's sign. No houseSigns override: here the
  /// whole-sign walk is the correct reading.
  Widget _kpRashiChartCard(List<dynamic> planets) {
    final asc = planets.cast<Map<String, dynamic>>().firstWhere(
        (p) => p['planet'] == 'Ascendant',
        orElse: () => const {'signIndex': 0});
    final ascSign = asc['signIndex'] as int? ?? 0;

    final labels = <int, String>{};
    for (final entry in planets) {
      final p = entry as Map<String, dynamic>;
      if (p['planet'] == 'Ascendant') continue;
      final sign = p['signIndex'] as int?;
      if (sign == null) continue;
      final house = (sign - ascSign + 12) % 12 + 1;
      final abbr = kpAbbreviation(p['planet'] as String);
      labels[house] = labels.containsKey(house) ? '${labels[house]}\n$abbr' : abbr;
    }
    labels[1] = labels.containsKey(1) ? 'As\n${labels[1]}' : 'As';

    return _chartCard(NorthChartPainter(labels, ascSign));
  }

  Widget _chartCard(CustomPainter painter) {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: painter)),
    );
  }

  Widget _kpChartPlaceholder() {
    return GlassCard(
      fill: AppColors.surfaceRaised,
      fillOpacity: 0.5,
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: const AspectRatio(aspectRatio: 1, child: LoadingView(height: null)),
    );
  }

  /// Planet | A | B | C | D. Its own table rather than a KpTable: that one is
  /// built around the lordship chain's fixed `Degree | SL | NL | SB | SS`
  /// columns, and these five carry different content and widths.
  Widget _significatorTable(List<dynamic> rows) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: Column(
        children: [
          _sigRow(
            const [
              'PLANET',
              'STAR LORD OCCUPIES',
              'STAR LORD OWNS',
              'PLANET OCCUPIES',
              'PLANET OWNS',
            ],
            isHeader: true,
          ),
          for (var i = 0; i < rows.length; i++)
            if (rows[i] is Map<String, dynamic>)
              _sigRow(
                [
                  kpAbbreviation((rows[i] as Map<String, dynamic>)['planet'] as String),
                  _houses((rows[i] as Map<String, dynamic>)['starLordOccupies']),
                  _houses((rows[i] as Map<String, dynamic>)['starLordOwns']),
                  _houses((rows[i] as Map<String, dynamic>)['occupies']),
                  _houses((rows[i] as Map<String, dynamic>)['owns']),
                ],
                last: i == rows.length - 1,
              ),
        ],
      ),
    );
  }

  Widget _sigRow(List<String> cells, {bool isHeader = false, bool last = false}) {
    Widget cell(int i, int flex) => Expanded(
          flex: flex,
          child: Text(
            cells[i],
            style: isHeader
                ? AppText.sans(
                    size: 9,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                    letterSpacing: 0.8)
                : AppText.sans(
                    size: 12,
                    color: i == 0 ? AppColors.gold : AppColors.textPrimary,
                    weight: i == 0 ? FontWeight.w600 : FontWeight.w400),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.textPrimary.withValues(alpha: 0.02) : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(children: [
        cell(0, 4),
        cell(1, 5),
        cell(2, 5),
        cell(3, 5),
        cell(4, 5),
      ]),
    );
  }

  /// An empty level is meaningful in KP — the planet signifies nothing there —
  /// so it shows a dash rather than blank space that reads as missing data.
  static String _houses(dynamic list) {
    final houses = (list as List?)?.cast<int>() ?? const <int>[];
    return houses.isEmpty ? '—' : houses.join(', ');
  }

  static final _mockPlanetRows = <KpTableRow>[
    for (final r in const [
      ['Asc', "346°49'50\"", 'Ju', 'Me', 'Me', 'Me'],
      ['Su', "139°53'39\"", 'Su', 'Ve', 'Ra', 'Mo'],
      ['Mo', "80°15'15\"", 'Me', 'Ju', 'Ju', 'Sa'],
      ['Ma', "82°46'34\"", 'Me', 'Ju', 'Sa', 'Ve'],
      ['Me', "148°49'30\"", 'Su', 'Su', 'Ma', 'Sa'],
      ['Ju', "110°41'34\"", 'Mo', 'Me', 'Ve', 'Ju'],
      ['Ve', "183°17'49\"", 'Ve', 'Ma', 'Ve', 'Mo'],
      ['Sa(R)', "349°10'42\"", 'Ju', 'Me', 'Ke', 'Sa'],
      ['Ra(R)', "304°51'32\"", 'Sa', 'Ma', 'Ve', 'Ke'],
      ['Ke(R)', "124°51'32\"", 'Su', 'Ke', 'Ma', 'Ra'],
    ])
      KpTableRow(
        label: r[0], degree: r[1], signLord: r[2],
        starLord: r[3], subLord: r[4], subSubLord: r[5],
      ),
  ];
}

/// One table row from a `kp` or `cusps` entry — both carry the same
/// `signIndex`/`degreeInSign`/`lordship` shape, which is exactly why KP calls
/// this a lordship chain rather than something planet-specific.
KpTableRow _kpRow(Map<String, dynamic> e, {required String label}) {
  final lordship = e['lordship'] as Map<String, dynamic>;
  return KpTableRow(
    label: label,
    degree: formatKpDegree(
        e['signIndex'] as int, (e['degreeInSign'] as num).toDouble()),
    signLord: kpAbbreviation(lordship['signLord'] as String),
    starLord: kpAbbreviation(lordship['starLord'] as String),
    subLord: kpAbbreviation(lordship['subLord'] as String),
    subSubLord: kpAbbreviation(lordship['subSubLord'] as String),
  );
}

/// The column abbreviations aren't guessable, so they're spelled out under
/// every KP table rather than assumed.
Widget _kpLegend() {
  return Text(
    // The column headers spell the lords out now, so this no longer expands
    // abbreviations — it carries only what the table itself can't say.
    'Swipe the table sideways for the remaining lords.   ·   (R) retrograde\n'
    'Positions use the KP (Krishnamurti) ayanamsa, not Lahiri — so these '
    'degrees differ slightly from the other Kundli tabs by design.',
    style: AppText.sans(size: 11, color: AppColors.textMuted, height: 1.6),
  );
}

Widget _kpLockedNotice(String detail) {
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
        Text(detail,
            textAlign: TextAlign.center,
            style: AppText.sans(size: 12, color: AppColors.textMuted, height: 1.5)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 5) Cusp Chart tab — the cusps table: each house's degree + lordship chain
// ─────────────────────────────────────────────────────────────────────────────
class _CuspTab extends StatelessWidget {
  const _CuspTab({this.chart});

  final Map<String, dynamic>? chart;

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
          'The exact starting degree of each of the twelve houses, with the '
          'lordship chain that governs it.',
          style: AppText.sans(size: 13, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.md),
        _howToReadNote(
          "A house's Sub Lord is what KP actually judges the house on — "
          'whether it promises the matter that house rules. House 1 is the '
          'Ascendant itself, so its row matches the Asc row on the KP System '
          'tab exactly.',
        ),
        const SizedBox(height: AppSpacing.lg),
        if (locked)
          _kpLockedNotice(
              'House cusps need a birth time exact to the minute.')
        else ...[
          const SectionLabel('CUSPS'),
          const SizedBox(height: AppSpacing.md),
          KpTable(
            firstColumnLabel: 'House',
            rows: [
              if (cusps != null)
                for (final c in cusps)
                  _kpRow(c as Map<String, dynamic>,
                      label: '${c['house']}')
              else
                ..._mockCuspRows,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _kpLegend(),
          if (cusps != null) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('PLANETS IN EACH HOUSE'),
            const SizedBox(height: AppSpacing.md),
            // Kept from the previous Cusp tab: the lordship table above says
            // who governs a house, this says who is actually sitting in it.
            GlassCard(
              radius: AppRadius.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in cusps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text('${(c as Map<String, dynamic>)['house']}',
                                style: AppText.sans(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: AppColors.gold)),
                          ),
                          Expanded(
                            child: Text(
                              ((c['planets'] as List<dynamic>).cast<String>()).isEmpty
                                  ? '—'
                                  : (c['planets'] as List<dynamic>)
                                      .cast<String>()
                                      .join(', '),
                              style: AppText.sans(
                                  size: 13, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  static final _mockCuspRows = <KpTableRow>[
    for (final r in const [
      ['1', "346°49'50\"", 'Ju', 'Me', 'Me', 'Me'],
      ['2', "20°46'44\"", 'Ma', 'Ve', 'Ju', 'Me'],
      ['3', "48°36'34\"", 'Ve', 'Mo', 'Me', 'Mo'],
      ['4', "73°44'35\"", 'Me', 'Ra', 'Me', 'Ra'],
      ['5', "99°48'22\"", 'Mo', 'Sa', 'Ve', 'Sa'],
      ['6', "130°15'49\"", 'Su', 'Ke', 'Sa', 'Ve'],
      ['7', "166°49'50\"", 'Me', 'Mo', 'Sa', 'Su'],
      ['8', "200°46'44\"", 'Ve', 'Ju', 'Ju', 'Ke'],
      ['9', "228°36'34\"", 'Ma', 'Me', 'Ke', 'Ve'],
      ['10', "253°44'35\"", 'Ju', 'Ve', 'Ve', 'Su'],
      ['11', "279°48'22\"", 'Sa', 'Su', 'Ve', 'Me'],
      ['12', "310°15'49\"", 'Sa', 'Ra', 'Ju', 'Ra'],
    ])
      KpTableRow(
        label: r[0], degree: r[1], signLord: r[2],
        starLord: r[3], subLord: r[4], subSubLord: r[5],
      ),
  ];
}

