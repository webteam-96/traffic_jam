import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Draws the North-Indian diamond (square + both diagonals + midpoint
/// diamond) in thin gold lines, then seats planet labels at fixed house
/// centers. [houses] maps house number (1..12) to a label string (planet
/// abbreviations, newline-joined when several share a house); a label
/// starting with "As" is highlighted gold as the Ascendant.
///
/// The small number in each cell is the RASHI (sign) number, 1=Aries..12=
/// Pisces — the universal North-Indian convention, and the reason
/// [ascendantSign] is needed. The house is already given by the cell's fixed
/// position (house 1 is always the top-centre diamond), so numbering the
/// cells 1..12 by house, as this used to, prints information the layout
/// already carries and drops the one thing it doesn't.
///
/// That made the chart impossible to check against any other astrology app:
/// every cell showed a different number from the same cell elsewhere, so
/// identical placements read as completely wrong. Verified 2026-09-07 against
/// a reference app on the same birth data — D10 agreed on all nine grahas and
/// D60 on eight of nine, while the numbering made them look unrelated.
class NorthChartPainter extends CustomPainter {
  const NorthChartPainter(this.houses, this.ascendantSign, {this.houseSigns});

  final Map<int, String> houses;

  /// 0=Aries..11=Pisces. House 1 holds this sign; each later house holds the
  /// next sign round, since these charts are whole-sign.
  final int ascendantSign;

  /// House number to sign index, for charts whose houses are NOT whole-sign.
  /// KP works in Placidus, where houses are unequal: one sign can hold two
  /// cusps and another none, so the whole-sign walk from [ascendantSign] would
  /// print sign numbers the chart doesn't actually have. Null everywhere else,
  /// which keeps the whole-sign behaviour every Vedic varga chart wants.
  final Map<int, int>? houseSigns;

  int _signNumberFor(int house) =>
      houseSigns != null && houseSigns!.containsKey(house)
          ? houseSigns![house]! + 1
          : (ascendantSign + house - 1) % 12 + 1;

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

    // Every one of the 12 fixed cells gets its sign number, even empty ones —
    // [houses] only carries entries for cells with a label.
    for (var house = 1; house <= 12; house++) {
      final c = _centers[house];
      if (c == null) continue;
      final label = houses[house];
      final isAsc = label?.startsWith('As') ?? false;
      final signNumber = _signNumberFor(house);

      final numberTp = TextPainter(
        text: TextSpan(
          text: '$signNumber',
          style: AppText.sans(
            size: 9,
            weight: FontWeight.w600,
            color: AppColors.gold.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (label == null) {
        numberTp.paint(canvas, Offset(c.dx * w - numberTp.width / 2, c.dy * h - numberTp.height / 2));
        continue;
      }

      final labelTp = TextPainter(
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

      final totalHeight = numberTp.height + 1 + labelTp.height;
      final top = c.dy * h - totalHeight / 2;
      numberTp.paint(canvas, Offset(c.dx * w - numberTp.width / 2, top));
      labelTp.paint(canvas, Offset(c.dx * w - labelTp.width / 2, top + numberTp.height + 1));
    }
  }

  @override
  bool shouldRepaint(covariant NorthChartPainter old) =>
      old.houses != houses ||
      old.ascendantSign != ascendantSign ||
      !mapEquals(old.houseSigns, houseSigns);
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

    for (var house = 1; house <= 12; house++) {
      final sign = (ascendantSign + house - 1) % 12;
      final rc = _signCell[sign];
      if (rc == null) continue;
      final center = Offset((rc.$2 + 0.5) * cell, (rc.$1 + 0.5) * cell);
      final label = houses[house];
      final isAsc = label?.startsWith('As') ?? false;

      final numberTp = TextPainter(
        text: TextSpan(
          text: '$house',
          style: AppText.sans(
            size: 9,
            weight: FontWeight.w600,
            color: AppColors.gold.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      if (label == null) {
        numberTp.paint(canvas, center - Offset(numberTp.width / 2, numberTp.height / 2));
        continue;
      }

      final labelTp = TextPainter(
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

      final totalHeight = numberTp.height + 1 + labelTp.height;
      final top = center.dy - totalHeight / 2;
      numberTp.paint(canvas, Offset(center.dx - numberTp.width / 2, top));
      labelTp.paint(canvas, Offset(center.dx - labelTp.width / 2, top + numberTp.height + 1));
    }
  }

  @override
  bool shouldRepaint(covariant SouthChartPainter old) =>
      old.houses != houses || old.ascendantSign != ascendantSign;
}

const planetAbbr = {
  'Sun': 'Su', 'Moon': 'Mo', 'Mars': 'Ma', 'Mercury': 'Me', 'Jupiter': 'Ju',
  'Venus': 'Ve', 'Saturn': 'Sa', 'Rahu': 'Ra', 'Ketu': 'Ke',
  // Outer planets. Three letters, not two, so nobody reads "Ur" as a graha
  // abbreviation they half-recognise — these are not grahas and no classical
  // rule in this app touches them.
  'Uranus': 'Ura', 'Neptune': 'Nep', 'Pluto': 'Plu',
};

/// Builds a house→label map (house 1 always includes "As") from any `/chart`
/// response planet array that carries a `house` field — `d1`, or any of
/// `d9`/`d10`/`d60` once that chart's own Lagna is known — for feeding to
/// [NorthChartPainter]/[SouthChartPainter]. Accumulates every planet sharing
/// a house (rather than overwriting) before prefixing house 1 with the
/// Ascendant marker, so two+ planets conjunct with the Ascendant don't
/// clobber each other.
Map<int, String> housesFromPlanets(List<dynamic> planets) {
  final houses = <int, String>{};
  for (final planet in planets) {
    final p = planet as Map<String, dynamic>;
    final house = p['house'] as int?;
    if (house == null) continue;
    final abbr = planetAbbr[p['planet'] as String] ?? (p['planet'] as String).substring(0, 2);
    houses[house] = houses.containsKey(house) ? '${houses[house]}\n$abbr' : abbr;
  }
  houses[1] = houses.containsKey(1) ? 'As\n${houses[1]}' : 'As';
  return houses;
}

/// The North Indian chart's outline at icon size — outer square, both
/// diagonals, inner diamond on the side midpoints.
///
/// Its own painter rather than a shrunken [NorthChartPainter]: that one also
/// draws twelve sign numbers and any planets in each house, which at 20px
/// would be an unreadable smudge. This is the silhouette alone, which is what
/// makes the chart recognisable.
class NorthChartGlyph extends StatelessWidget {
  const NorthChartGlyph({super.key, this.size = 20, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _NorthChartGlyphPainter(color)),
      );
}

class _NorthChartGlyphPainter extends CustomPainter {
  const _NorthChartGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Scales with the glyph so it stays crisp at any size rather than going
      // spidery when drawn large or muddy when drawn small.
      ..strokeWidth = size.width / 14
      ..strokeJoin = StrokeJoin.round;

    // Inset by half the stroke so the outer square isn't clipped at the edge.
    final inset = line.strokeWidth / 2;
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    final rect = Rect.fromLTWH(inset, inset, w, h);

    canvas.drawRect(rect, line);
    canvas.drawLine(rect.topLeft, rect.bottomRight, line);
    canvas.drawLine(rect.topRight, rect.bottomLeft, line);

    canvas.drawPath(
      Path()
        ..moveTo(rect.center.dx, rect.top)
        ..lineTo(rect.right, rect.center.dy)
        ..lineTo(rect.center.dx, rect.bottom)
        ..lineTo(rect.left, rect.center.dy)
        ..close(),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _NorthChartGlyphPainter old) => old.color != color;
}
