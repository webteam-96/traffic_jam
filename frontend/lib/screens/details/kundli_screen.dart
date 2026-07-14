import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';
import '../../nav.dart';

/// Kundli viewer — a pushed (non-tab) detail screen. A PillToggle swaps between
/// three vargas (Lagna D1 / Moon / Navamsha D9); each renders a North-Indian
/// diamond chart via CustomPainter with planet labels seated in their houses.
/// All placements are mocked inline. Stateful only for the toggle.
class KundliScreen extends StatefulWidget {
  const KundliScreen({super.key});

  @override
  State<KundliScreen> createState() => _KundliScreenState();
}

class _KundliScreenState extends State<KundliScreen> {
  int _index = 0;

  static const List<String> _tabs = ['Lagna D1', 'Moon', 'Navamsha D9'];
  static const List<String> _titles = [
    'Lagna Chart · D1',
    'Moon Chart · Chandra',
    'Navamsha · D9',
  ];
  static const List<String> _notes = [
    'The rising sign and the frame of the whole life — houses counted from '
        'your ascendant.',
    'Emotional weather read from the Moon, seated as the first house.',
    'The ninth harmonic — marriage, dharma and the ripened fruit of each '
        'planet.',
  ];

  // House (1..12) → planet abbreviations seated there. "As" flags the lagna.
  static const List<Map<int, String>> _charts = [
    {1: 'As', 3: 'Ra', 4: 'Mo', 5: 'Ju', 7: 'Sa', 9: 'Ke', 10: 'Su\nMa',
        11: 'Me\nVe'},
    {1: 'As', 2: 'Ra', 4: 'Mo', 7: 'Ju', 8: 'Ke', 9: 'Sa', 10: 'Ve',
        11: 'Su\nMe'},
    {1: 'As\nJu', 2: 'Ra', 3: 'Ma', 5: 'Su\nMe', 7: 'Sa', 8: 'Ke', 9: 'Mo',
        11: 'Ve'},
  ];

  static const List<List<String>> _legend = [
    ['As', 'Ascendant'], ['Su', 'Sun'], ['Mo', 'Moon'], ['Ma', 'Mars'],
    ['Me', 'Mercury'], ['Ju', 'Jupiter'], ['Ve', 'Venus'], ['Sa', 'Saturn'],
    ['Ra', 'Rahu'], ['Ke', 'Ketu'],
  ];

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Kundli',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SectionLabel('BIRTH CHART')),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(_titles[_index],
                style: AppText.serif(size: 24, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: AppSpacing.xl),
          PillToggle(
            options: _tabs,
            selectedIndex: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            fill: AppColors.surfaceRaised,
            fillOpacity: 0.5,
            radius: AppRadius.md,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(painter: _NorthChartPainter(_charts[_index])),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(_notes[_index],
              textAlign: TextAlign.center,
              style: AppText.sans(
                  size: 14, color: AppColors.textTan, height: 1.55)),
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
          const SizedBox(height: AppSpacing.section),
          GoldButton(
              label: 'View planetary details',
              icon: Icons.auto_awesome,
              outlined: true,
              onPressed: () => goToPlanetStrengths(context)),
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
        Text(name,
            style: AppText.sans(size: 13, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Draws the North-Indian diamond (square + both diagonals + midpoint diamond)
/// in thin gold lines on transparent, then seats planet labels at house centers.
class _NorthChartPainter extends CustomPainter {
  const _NorthChartPainter(this.houses);

  final Map<int, String> houses;

  // Approx. house-center positions as fractions of the box (standard layout).
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
    canvas.drawPath(
        diamond, line..color = AppColors.gold.withValues(alpha: 0.32));

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
      tp.paint(canvas,
          Offset(c.dx * w - tp.width / 2, c.dy * h - tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _NorthChartPainter old) =>
      old.houses != houses;
}
