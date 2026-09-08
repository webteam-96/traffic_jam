import 'package:flutter/material.dart';
import 'package:traffic_jam/theme/app_theme.dart';
import 'package:traffic_jam/widgets/glass_card.dart';

/// The standard KP reference table: one row per planet or per cusp, showing
/// the position and its four-level lordship chain.
///
/// Every KP tool lays this out the same way — `Degree | SL | NL | SB | SS` —
/// and practitioners read across the row. The chain is the whole point of the
/// system, so showing only part of it (this app previously showed the star and
/// sub lords but not the sign or sub-sub) makes the table unusable for the
/// people who ask for a KP view in the first place.
///
/// Six columns don't fit a phone at a legible size, so the table scrolls
/// sideways with the first column pinned — that's the row's identity (planet
/// name or house number) and losing it while scrolling makes the rest
/// meaningless.
class KpTable extends StatelessWidget {
  const KpTable({
    super.key,
    required this.firstColumnLabel,
    required this.rows,
  });

  /// Header over the pinned column — "Pla" for planets, "Hos" for cusps, as
  /// the KP convention abbreviates them.
  final String firstColumnLabel;

  final List<KpTableRow> rows;

  static const _degreeWidth = 108.0;
  static const _lordWidth = 52.0;
  static const _firstWidth = 74.0;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned identity column.
            Column(
              children: [
                _cell(firstColumnLabel, _firstWidth, isHeader: true),
                for (var i = 0; i < rows.length; i++)
                  _cell(rows[i].label, _firstWidth,
                      striped: i.isOdd,
                      color: AppColors.gold,
                      weight: FontWeight.w600),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(children: [
                      _cell('Degree', _degreeWidth, isHeader: true),
                      _cell('SL', _lordWidth, isHeader: true),
                      _cell('NL', _lordWidth, isHeader: true),
                      _cell('SB', _lordWidth, isHeader: true),
                      _cell('SS', _lordWidth, isHeader: true),
                    ]),
                    for (var i = 0; i < rows.length; i++)
                      Row(children: [
                        _cell(rows[i].degree, _degreeWidth,
                            striped: i.isOdd, feature: FontFeature.tabularFigures()),
                        _cell(rows[i].signLord, _lordWidth,
                            striped: i.isOdd, color: AppColors.textTan),
                        _cell(rows[i].starLord, _lordWidth,
                            striped: i.isOdd, color: AppColors.textTan),
                        // The sub lord is KP's decision-maker for a house, so
                        // it's the one column worth picking out of the four.
                        _cell(rows[i].subLord, _lordWidth,
                            striped: i.isOdd,
                            color: AppColors.amber,
                            weight: FontWeight.w600),
                        _cell(rows[i].subSubLord, _lordWidth,
                            striped: i.isOdd, color: AppColors.textTan),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    String text,
    double width, {
    bool isHeader = false,
    bool striped = false,
    Color? color,
    FontWeight? weight,
    FontFeature? feature,
  }) {
    return Container(
      width: width,
      height: isHeader ? 38 : 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: isHeader
            ? AppColors.textPrimary.withValues(alpha: 0.04)
            : striped
                ? AppColors.textPrimary.withValues(alpha: 0.02)
                : null,
        border: Border(
          bottom: BorderSide(
              color: AppColors.textPrimary.withValues(alpha: 0.05)),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isHeader
            ? AppText.sans(
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.textPrimary.withValues(alpha: 0.45),
                letterSpacing: 0.6)
            : AppText.sans(
                size: 13,
                weight: weight ?? FontWeight.w400,
                color: color ?? AppColors.textPrimary,
              ).copyWith(fontFeatures: feature == null ? null : [feature]),
      ),
    );
  }
}

class KpTableRow {
  const KpTableRow({
    required this.label,
    required this.degree,
    required this.signLord,
    required this.starLord,
    required this.subLord,
    required this.subSubLord,
  });

  final String label;
  final String degree;
  final String signLord;
  final String starLord;
  final String subLord;
  final String subSubLord;
}

/// Zodiac longitude as KP writes it: absolute 0-360°, degrees/minutes/seconds.
///
/// Not degrees-within-sign. KP tables place a position on the whole circle so
/// two rows can be compared directly, and the sign is implied by the range —
/// which is also what makes the Ascendant row and cusp 1 visibly identical.
String formatKpDegree(int signIndex, double degreeInSign) {
  final absolute = signIndex * 30.0 + degreeInSign;
  final d = absolute.floor();
  final minutesTotal = (absolute - d) * 60.0;
  var m = minutesTotal.floor();
  var s = ((minutesTotal - m) * 60.0).round();
  // Rounding seconds can carry: 59.6" becomes 60", which is the next minute.
  if (s == 60) {
    s = 0;
    m += 1;
  }
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return "$d°$mm'$ss\"";
}

/// KP tables abbreviate every lord to two letters, because the four lordship
/// columns have to sit side by side on one row.
String kpAbbreviation(String planet) => switch (planet) {
      'Sun' => 'Su',
      'Moon' => 'Mo',
      'Mars' => 'Ma',
      'Mercury' => 'Me',
      'Jupiter' => 'Ju',
      'Venus' => 'Ve',
      'Saturn' => 'Sa',
      'Rahu' => 'Ra',
      'Ketu' => 'Ke',
      // Outer planets appear only in the KP planets table — they aren't
      // grahas and take no part in any classical calculation in this app.
      'Uranus' => 'Ura',
      'Neptune' => 'Nep',
      'Pluto' => 'Plu',
      'Ascendant' => 'Asc',
      _ => planet.length <= 3 ? planet : planet.substring(0, 3),
    };
