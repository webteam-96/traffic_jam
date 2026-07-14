import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../nav.dart';

/// My Chart tab — Figma node 1:3 (dc_3_mychart). Rashi (D1) chart, Vimshottari
/// Dasha, Graha Sphuta table, gold Weekly Insight card. Mock data inline.
class MyChartScreen extends StatelessWidget {
  const MyChartScreen({super.key});

  // Graha Sphuta rows: graha, rashi, degrees, nakshatra.
  static const _grahaRows = <List<String>>[
    ['Lagna', 'Leo', "12°44'", 'Magha (4)'],
    ['Sun', 'Aquarius', "28°12'", 'P. Bhadra (3)'],
    ['Moon', 'Taurus', "04°22'", 'Krittika (3)'],
    ['Mars', 'Capricorn', "15°55'", 'Shravana (2)'],
    ['Mercury', 'Aquarius', "02°09'", 'Dhanishta (3)'],
    ['Jupiter', 'Leo', "22°30'", 'P. Phalguni (3)'],
  ];

  @override
  Widget build(BuildContext context) {
    return CosmicScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero: identity ──────────────────────────────────────────────
          Text(
            'NATAL CHART ANALYSIS',
            style: AppText.sans(
                size: 10,
                weight: FontWeight.w500,
                color: AppColors.gold,
                letterSpacing: 3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text('Rashi Chart',
                    style: AppText.serif(
                        size: 32,
                        color: AppColors.textPrimary,
                        height: 48 / 32)),
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
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.5),
                              letterSpacing: 1.1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('SIDEREAL',
                          style: AppText.sans(
                              size: 9,
                              weight: FontWeight.w400,
                              color: AppColors.gold)),
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
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.1),
                              blurRadius: 12,
                            )
                          ],
                        ),
                        child: CustomPaint(painter: _RashiChartPainter()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Vimshottari Dasha ───────────────────────────────────────────
          GlassCard(
            radius: AppRadius.lg,
            borderColor: AppColors.borderSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VIMSHOTTARI DASHA',
                    style: AppText.sans(
                        size: 10,
                        weight: FontWeight.w400,
                        color: AppColors.gold,
                        letterSpacing: 1)),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardPad),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: AppColors.textPrimary
                              .withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconChip(
                        size: 40,
                        child: const Icon(Icons.auto_awesome,
                            size: 16, color: AppColors.gold),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jupiter Mahadasha',
                              style: AppText.serif(
                                  size: 16,
                                  color: AppColors.textPrimary,
                                  height: 20 / 16)),
                          Text('ENDS AUG 2032',
                              style: AppText.sans(
                                  size: 11,
                                  color: AppColors.textPrimary
                                      .withValues(alpha: 0.4),
                                  letterSpacing: -0.55,
                                  height: 16.5 / 11)),
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
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.4),
                              letterSpacing: 0.9)),
                    ),
                    Text('Mercury Period',
                        style: AppText.sans(
                            size: 11, color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Segmented antardasha bar: past | current (gold) | future.
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    height: 4,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 30,
                          child: Container(
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.1)),
                        ),
                        Expanded(
                          flex: 40,
                          child: Container(color: AppColors.gold),
                        ),
                        Expanded(
                          flex: 30,
                          child: Container(
                              color: AppColors.textPrimary
                                  .withValues(alpha: 0.05)),
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
                        name: 'Saturn',
                        date: 'Mar 2024',
                        align: CrossAxisAlignment.start,
                        nameColor:
                            AppColors.textPrimary.withValues(alpha: 0.6),
                        dateColor:
                            AppColors.textPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    Expanded(
                      child: _DashaStep(
                        name: 'Mercury',
                        date: 'Oct 2026',
                        align: CrossAxisAlignment.center,
                        nameColor: AppColors.gold,
                        dateColor: AppColors.gold.withValues(alpha: 0.5),
                        underline: true,
                        bold: true,
                      ),
                    ),
                    Expanded(
                      child: _DashaStep(
                        name: 'Ketu',
                        date: 'Oct 2026',
                        align: CrossAxisAlignment.end,
                        nameColor:
                            AppColors.textPrimary.withValues(alpha: 0.3),
                        dateColor:
                            AppColors.textPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                      bottom: BorderSide(
                          color: AppColors.textPrimary
                              .withValues(alpha: 0.05)),
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
                                    size: 20,
                                    color: AppColors.textPrimary,
                                    height: 30 / 20)),
                            const SizedBox(height: 3),
                            Text('PLANETARY DEGREES',
                                style: AppText.sans(
                                    size: 9,
                                    color: AppColors.textPrimary
                                        .withValues(alpha: 0.4),
                                    letterSpacing: 0.45)),
                          ],
                        ),
                      ),
                      Icon(Icons.grid_view_outlined,
                          size: 18,
                          color:
                              AppColors.textPrimary.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
                // Header row
                _tableRow(
                  const ['GRAHA', 'RASHI', 'DEGREES', 'NAKSHATRA'],
                  isHeader: true,
                ),
                for (int i = 0; i < _grahaRows.length; i++)
                  _tableRow(_grahaRows[i], last: i == _grahaRows.length - 1),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Weekly Insight (gold) ───────────────────────────────────────
          _WeeklyInsightCard(),
        ],
      ),
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
          : AppText.sans(
              size: 12,
              color: color ?? AppColors.textPrimary,
            );
      return Expanded(
        flex: flex,
        child: Text(
          cells[i],
          textAlign: align,
          style: style,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: isHeader
            ? AppColors.textPrimary.withValues(alpha: 0.02)
            : null,
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.05)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(0, flex: 5),
          cell(1,
              flex: 6,
              color: AppColors.textPrimary.withValues(alpha: 0.6)),
          cell(2, flex: 4, color: AppColors.gold),
          cell(3,
              flex: 6,
              color: AppColors.textPrimary.withValues(alpha: 0.4),
              align: TextAlign.right),
        ],
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
                decoration:
                    underline ? TextDecoration.underline : TextDecoration.none,
                decorationColor: nameColor)),
        Text(date,
            textAlign: _textAlign,
            style: AppText.sans(size: 9, color: dateColor, height: 13.5 / 9)),
      ],
    );
  }
}

/// Solid gold "Weekly Insight" card at the bottom.
class _WeeklyInsightCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final navy = AppColors.navBarBase;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        color: AppColors.gold,
        child: Stack(
          children: [
            // faint decorative star, bottom-right
            Positioned(
              right: 24,
              bottom: 20,
              child: Icon(Icons.star,
                  size: 40, color: navy.withValues(alpha: 0.12)),
            ),
            // glossy sheen, top-right
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
                    BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WEEKLY INSIGHT',
                      style: AppText.sans(
                          size: 10,
                          weight: FontWeight.w700,
                          color: navy.withValues(alpha: 0.6),
                          letterSpacing: 1)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('The Transit of Saturn',
                      style: AppText.serif(
                          size: 28, color: navy, height: 42 / 28)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '"Relationships undergo technical restructuring. '
                    "Use Mercury's precision to communicate complex needs.\"",
                    style: AppText.sans(
                        size: 16,
                        color: navy.withValues(alpha: 0.8),
                        height: 26 / 16),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => goToAstroInsights(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xxl,
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: navy,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('FULL READ',
                                  style: AppText.sans(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(Icons.arrow_forward,
                                  size: 12, color: AppColors.textPrimary),
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

/// North-Indian (diamond) Lagna chart: square + inner diamond + both diagonals,
/// with house numbers 1-12 and planet labels. Reference space is 308×308.
class _RashiChartPainter extends CustomPainter {
  // House-number centres in 308-space (counter-clockwise from top).
  static const _numbers = <String, Offset>{
    '1': Offset(156, 30),
    '2': Offset(94, 46),
    '3': Offset(48, 92),
    '4': Offset(34, 154),
    '5': Offset(48, 215),
    '6': Offset(94, 261),
    '7': Offset(156, 284),
    '8': Offset(218, 261),
    '9': Offset(264, 215),
    '10': Offset(282, 154),
    '11': Offset(264, 92),
    '12': Offset(218, 46),
  };

  // Planet labels: text, centre, size, isGold.
  static const _planets = <(String, Offset, double, bool)>[
    ('Ju, Ve', Offset(175, 71), 15.4, true),
    ('Sa', Offset(76, 66), 10.8, false),
    ('Ra', Offset(38, 135), 10.8, false),
    ('Ma', Offset(85, 235), 10.8, false),
    ('Su, Me', Offset(178, 248), 15.4, true),
    ('Mo', Offset(254, 150), 10.8, false),
    ('Ke', Offset(284, 165), 10.8, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final f = s / 308.0;
    final line = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // outer square
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), line);
    // diagonals
    canvas.drawLine(Offset.zero, Offset(s, s), line);
    canvas.drawLine(Offset(s, 0), Offset(0, s), line);
    // inner diamond (mid-points of the sides)
    final diamond = Path()
      ..moveTo(s / 2, 0)
      ..lineTo(s, s / 2)
      ..lineTo(s / 2, s)
      ..lineTo(0, s / 2)
      ..close();
    canvas.drawPath(diamond, line);

    // house numbers
    _numbers.forEach((n, p) {
      _label(canvas, n, Offset(p.dx * f, p.dy * f), 7.7 * f,
          AppColors.textPrimary.withValues(alpha: 0.3), false);
    });
    // planet glyphs
    for (final pl in _planets) {
      _label(
        canvas,
        pl.$1,
        Offset(pl.$2.dx * f, pl.$2.dy * f),
        pl.$3 * f,
        pl.$4 ? AppColors.gold : AppColors.textPrimary.withValues(alpha: 0.8),
        pl.$4,
      );
    }
  }

  void _label(Canvas canvas, String text, Offset center, double size,
      Color color, bool serif) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: serif
            ? AppText.serif(size: size, color: color)
            : AppText.sans(size: size, color: color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
