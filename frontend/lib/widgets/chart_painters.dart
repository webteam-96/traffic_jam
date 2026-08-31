import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Draws the North-Indian diamond (square + both diagonals + midpoint
/// diamond) in thin gold lines, then seats planet labels at fixed house
/// centers. [houses] maps house number (1..12) to a label string (planet
/// abbreviations, newline-joined when several share a house); a label
/// starting with "As" is highlighted gold as the Ascendant.
class NorthChartPainter extends CustomPainter {
  const NorthChartPainter(this.houses);

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
  bool shouldRepaint(covariant NorthChartPainter old) => old.houses != houses;
}

/// Draws the South-Indian fixed 4x4 grid — signs sit in fixed cells; each
/// house's label is placed by converting house→sign via [ascendantSign]
/// (0=Aries..11=Pisces).
class SouthChartPainter extends CustomPainter {
  const SouthChartPainter(this.houses, this.ascendantSign);

  final Map<int, String> houses;
  final int ascendantSign;

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
  bool shouldRepaint(covariant SouthChartPainter old) =>
      old.houses != houses || old.ascendantSign != ascendantSign;
}

const planetAbbr = {
  'Sun': 'Su', 'Moon': 'Mo', 'Mars': 'Ma', 'Mercury': 'Me', 'Jupiter': 'Ju',
  'Venus': 'Ve', 'Saturn': 'Sa', 'Rahu': 'Ra', 'Ketu': 'Ke',
};

/// Builds a house→label map (house 1 always includes "As") from a `/chart`
/// response's `d1` planet array, for feeding to [NorthChartPainter]/
/// [SouthChartPainter]. Accumulates every planet sharing a house (rather than
/// overwriting) before prefixing house 1 with the Ascendant marker, so two+
/// planets conjunct with the Ascendant don't clobber each other.
Map<int, String> housesFromD1(List<dynamic> d1Planets) {
  final houses = <int, String>{};
  for (final planet in d1Planets) {
    final p = planet as Map<String, dynamic>;
    final house = p['house'] as int?;
    if (house == null) continue;
    final abbr = planetAbbr[p['planet'] as String] ?? (p['planet'] as String).substring(0, 2);
    houses[house] = houses.containsKey(house) ? '${houses[house]}\n$abbr' : abbr;
  }
  houses[1] = houses.containsKey(1) ? 'As\n${houses[1]}' : 'As';
  return houses;
}
