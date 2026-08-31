import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../nav.dart';
import '../services/chart_api.dart';
import '../services/api_client.dart';
import 'details/dasha_timeline_screen.dart';

const _monthNamesShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
  if (minutes == 60) return "${(wholeDeg + 1).toString().padLeft(2, '0')}°00'";
  return "${wholeDeg.toString().padLeft(2, '0')}°${minutes.toString().padLeft(2, '0')}'";
}

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

/// My Chart tab — Figma node 1:3 (dc_3_mychart). Rashi (D1) chart, Vimshottari
/// Dasha, Graha Sphuta table. Wired to GET /chart and GET /dasha (the same
/// endpoints "My Kundli" uses — see details/kundli_screen.dart for the
/// Planet/Dasha/Charts/KP/Cusp tab breakdown this screen doesn't duplicate).
class MyChartScreen extends StatefulWidget {
  const MyChartScreen({super.key});

  @override
  State<MyChartScreen> createState() => _MyChartScreenState();
}

class _MyChartScreenState extends State<MyChartScreen> {
  Map<String, dynamic>? _chart;
  Map<String, dynamic>? _dasha;
  bool _loading = true;
  String? _error; // 'no-data' | 'generic' | null

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([ChartApi.getChart(), ChartApi.getDasha()]);
      if (!mounted) return;
      setState(() {
        _chart = results[0];
        _dasha = results[1];
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

    if (_error == 'no-data') {
      return CosmicScrollView(
        child: SizedBox(
          height: 400,
          child: Center(
            child: Text('Save your birth details first to see your chart.',
                textAlign: TextAlign.center, style: AppText.body),
          ),
        ),
      );
    }

    if (_error != null || _chart == null || _dasha == null) {
      return CosmicScrollView(
        child: SizedBox(
          height: 400,
          child: Center(
            child: Text("Couldn't load your chart — check your connection.",
                textAlign: TextAlign.center, style: AppText.body),
          ),
        ),
      );
    }

    final chart = _chart!;
    final dasha = _dasha!;
    final d1 = chart['d1'] as List<dynamic>;
    final ascendant = chart['ascendant'] as Map<String, dynamic>;
    final houses = housesFromD1(d1);

    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero: identity ──────────────────────────────────────────────
          Text(
            'NATAL CHART ANALYSIS',
            style: AppText.sans(
                size: 10, weight: FontWeight.w500, color: AppColors.gold, letterSpacing: 3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text('Rashi Chart',
                    style:
                        AppText.serif(size: 32, color: AppColors.textPrimary, height: 48 / 32)),
              ),
              _IconButtonBox(
                icon: Icons.ios_share,
                iconColor: AppColors.textPrimary,
                borderColor: AppColors.gold.withValues(alpha: 0.2),
                onTap: () => toast(context, 'Chart shared'),
              ),
              const SizedBox(width: AppSpacing.sm),
              _IconButtonBox(
                icon: Icons.file_download_outlined,
                iconColor: AppColors.navBarBase,
                fill: AppColors.gold,
                onTap: () => toast(context, 'Chart downloaded'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.section),

          // ── Rashi chart card ────────────────────────────────────────────
          GlassCard(
            radius: AppRadius.lg,
            borderColor: AppColors.borderSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text('LAGNA (D1)',
                          style: AppText.sans(
                              size: 11,
                              weight: FontWeight.w400,
                              color: AppColors.textPrimary.withValues(alpha: 0.5),
                              letterSpacing: 1.1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('SIDEREAL',
                          style: AppText.sans(
                              size: 9, weight: FontWeight.w400, color: AppColors.gold)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 12)
                          ],
                        ),
                        child: CustomPaint(painter: NorthChartPainter(houses)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Vimshottari Dasha ───────────────────────────────────────────
          _dashaCard(dasha),
          const SizedBox(height: AppSpacing.xxl),

          // ── Graha Sphuta table ──────────────────────────────────────────
          GlassCard(
            radius: AppRadius.lg,
            borderColor: AppColors.borderSoft,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Graha Sphuta',
                                style: AppText.serif(
                                    size: 20, color: AppColors.textPrimary, height: 30 / 20)),
                            const SizedBox(height: 3),
                            Text('PLANETARY DEGREES',
                                style: AppText.sans(
                                    size: 9,
                                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                                    letterSpacing: 0.45)),
                          ],
                        ),
                      ),
                      Icon(Icons.grid_view_outlined,
                          size: 18, color: AppColors.textPrimary.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
                _tableRow(const ['GRAHA', 'RASHI', 'DEGREES', 'H'], isHeader: true),
                _lagnaRow(ascendant),
                for (int i = 0; i < d1.length; i++)
                  _planetRow(d1[i] as Map<String, dynamic>, last: i == d1.length - 1),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Current Antardasha spotlight ────────────────────────────────
          _antardashaSpotlight(dasha),
        ],
      ),
    );
  }

  // ── Vimshottari Dasha card — real current Maha/Antar + a real elapsed-time
  // progress bar and prev/current/next Antar timeline. ──────────────────────
  Widget _dashaCard(Map<String, dynamic> dasha) {
    final maha = _currentOf(dasha['maha'] as List<dynamic>);
    final antarList = (dasha['antar'] as List<dynamic>).cast<Map<String, dynamic>>();
    final antarIndex = antarList.indexWhere((a) => a['current'] == true);

    if (maha == null || antarIndex == -1) {
      return const SizedBox.shrink();
    }

    final mahaEnd = _parseUtc(maha['end'] as String);
    final curr = antarList[antarIndex];
    final prev = antarIndex > 0 ? antarList[antarIndex - 1] : null;
    final next = antarIndex < antarList.length - 1 ? antarList[antarIndex + 1] : null;
    final fraction = _elapsedFraction(
        _parseUtc(curr['start'] as String), _parseUtc(curr['end'] as String));

    return GlassCard(
      radius: AppRadius.lg,
      borderColor: AppColors.borderSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VIMSHOTTARI DASHA',
              style:
                  AppText.sans(size: 10, weight: FontWeight.w400, color: AppColors.gold, letterSpacing: 1)),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.only(bottom: AppSpacing.cardPad),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                IconChip(
                  size: 40,
                  child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.gold),
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${maha['lord']} Mahadasha',
                        style: AppText.serif(size: 16, color: AppColors.textPrimary, height: 20 / 16)),
                    Text(
                      'ENDS ${_monthNamesShort[mahaEnd.month - 1].toUpperCase()} ${mahaEnd.year}',
                      style: AppText.sans(
                          size: 11,
                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                          letterSpacing: -0.55,
                          height: 16.5 / 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('ANTARDASHA PROGRESS',
                    style: AppText.sans(
                        size: 9,
                        color: AppColors.textPrimary.withValues(alpha: 0.4),
                        letterSpacing: 0.9)),
              ),
              Text('${curr['lord']} Period', style: AppText.sans(size: 11, color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  if (fraction > 0)
                    Expanded(
                      flex: (fraction * 100).round().clamp(1, 100),
                      child: Container(color: AppColors.gold),
                    ),
                  if (fraction < 1)
                    Expanded(
                      flex: (100 - (fraction * 100).round()).clamp(1, 100),
                      child: Container(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _DashaStep(
                  name: prev == null ? '—' : prev['lord'] as String,
                  date: prev == null ? '' : _monthYear(_parseUtc(prev['start'] as String)),
                  align: CrossAxisAlignment.start,
                  nameColor: AppColors.textPrimary.withValues(alpha: 0.6),
                  dateColor: AppColors.textPrimary.withValues(alpha: 0.3),
                ),
              ),
              Expanded(
                child: _DashaStep(
                  name: curr['lord'] as String,
                  date: _monthYear(_parseUtc(curr['start'] as String)),
                  align: CrossAxisAlignment.center,
                  nameColor: AppColors.gold,
                  dateColor: AppColors.gold.withValues(alpha: 0.5),
                  underline: true,
                  bold: true,
                ),
              ),
              Expanded(
                child: _DashaStep(
                  name: next == null ? '—' : next['lord'] as String,
                  date: next == null ? '' : _monthYear(_parseUtc(next['start'] as String)),
                  align: CrossAxisAlignment.end,
                  nameColor: AppColors.textPrimary.withValues(alpha: 0.3),
                  dateColor: AppColors.textPrimary.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _monthYear(DateTime d) => '${_monthNamesShort[d.month - 1]} ${d.year}';

  Widget _lagnaRow(Map<String, dynamic> ascendant) {
    final known = ascendant['known'] as bool;
    return _tableRow([
      'Lagna',
      known ? ascendant['sign'] as String : '—',
      known ? _formatDeg((ascendant['siderealLongitude'] as double) % 30) : '—',
      '1',
    ]);
  }

  Widget _planetRow(Map<String, dynamic> p, {required bool last}) {
    final retro = p['retrograde'] as bool;
    final house = p['house'] as int?;
    return _tableRow(
      [
        p['planet'] as String,
        p['sign'] as String,
        '${_formatDeg(p['degreeInSign'] as double)}${retro ? ' R' : ''}',
        house == null ? '—' : '$house',
      ],
      last: last,
    );
  }

  // One table row (header or data). Flex-sized cells so it never overflows.
  Widget _tableRow(List<String> cells, {bool isHeader = false, bool last = false}) {
    TextStyle headerStyle = AppText.sans(
        size: 9,
        weight: FontWeight.w700,
        color: AppColors.textPrimary.withValues(alpha: 0.4),
        letterSpacing: 0.9);
    Widget cell(int i, {required int flex, Color? color, TextAlign align = TextAlign.left}) {
      final style = isHeader
          ? headerStyle
          : AppText.sans(size: 12, color: color ?? AppColors.textPrimary);
      return Expanded(flex: flex, child: Text(cells[i], textAlign: align, style: style));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isHeader ? AppColors.textPrimary.withValues(alpha: 0.02) : null,
        border: last
            ? null
            : Border(bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(0, flex: 5),
          cell(1, flex: 6, color: AppColors.textPrimary.withValues(alpha: 0.6)),
          cell(2, flex: 5, color: AppColors.gold),
          cell(3, flex: 2, align: TextAlign.right),
        ],
      ),
    );
  }

  // Real "current Antardasha" spotlight — replaces the old fabricated
  // "Weekly Insight" quote card (no backend equivalent) with a factual
  // summary, linking to the full Dasha timeline.
  Widget _antardashaSpotlight(Map<String, dynamic> dasha) {
    final maha = _currentOf(dasha['maha'] as List<dynamic>);
    final antar = _currentOf(dasha['antar'] as List<dynamic>);
    if (maha == null || antar == null) return const SizedBox.shrink();

    final navy = AppColors.navBarBase;
    final antarEnd = _parseUtc(antar['end'] as String);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        color: AppColors.gold,
        child: Stack(
          children: [
            Positioned(
              right: 24,
              bottom: 20,
              child: Icon(Icons.star, size: 40, color: navy.withValues(alpha: 0.12)),
            ),
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT ANTARDASHA',
                      style: AppText.sans(
                          size: 10, weight: FontWeight.w700, color: navy.withValues(alpha: 0.6), letterSpacing: 1)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${antar['lord']} within ${maha['lord']}',
                      style: AppText.serif(size: 28, color: navy, height: 42 / 28)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${antar['lord']} Antardasha runs until ${_monthNamesShort[antarEnd.month - 1]} '
                    '${antarEnd.day}, ${antarEnd.year}, within your ${maha['lord']} Mahadasha.',
                    style: AppText.sans(size: 16, color: navy.withValues(alpha: 0.8), height: 26 / 16),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => pushScreen(context, DashaTimelineScreen.new),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: navy,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('FULL TIMELINE',
                                  style: AppText.sans(
                                      size: 13, weight: FontWeight.w700, color: AppColors.textPrimary)),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(Icons.arrow_forward, size: 12, color: AppColors.textPrimary),
                            ],
                          ),
                        ),
                      ),
                    ],
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

/// Small square icon button (share / download) from the hero row.
class _IconButtonBox extends StatelessWidget {
  const _IconButtonBox({
    required this.icon,
    required this.iconColor,
    this.fill,
    this.borderColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color? fill;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Icon(icon, size: 15, color: iconColor),
      ),
    );
  }
}

/// One of the three antardasha timeline steps under the progress bar.
class _DashaStep extends StatelessWidget {
  const _DashaStep({
    required this.name,
    required this.date,
    required this.align,
    required this.nameColor,
    required this.dateColor,
    this.underline = false,
    this.bold = false,
  });

  final String name;
  final String date;
  final CrossAxisAlignment align;
  final Color nameColor;
  final Color dateColor;
  final bool underline;
  final bool bold;

  TextAlign get _textAlign => align == CrossAxisAlignment.start
      ? TextAlign.left
      : align == CrossAxisAlignment.end
          ? TextAlign.right
          : TextAlign.center;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(name,
            textAlign: _textAlign,
            style: AppText.sans(
                size: 11,
                weight: bold ? FontWeight.w700 : FontWeight.w400,
                color: nameColor,
                height: 16.5 / 11).copyWith(
                decoration: underline ? TextDecoration.underline : TextDecoration.none,
                decorationColor: nameColor)),
        Text(date,
            textAlign: _textAlign,
            style: AppText.sans(size: 9, color: dateColor, height: 13.5 / 9)),
      ],
    );
  }
}
