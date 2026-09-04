import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/chart_painters.dart' show housesFromPlanets;

/// Builds a downloadable PDF of a Kundli — cover page, birth details, every
/// divisional chart the app itself computes (D1/D9/D10/D60) as a diamond +
/// table, Vimshottari Dasha, KP cuspal sub-lords, and Doshas. Deliberately
/// limited to what this app actually computes — no Shadbala/Bhavbala/
/// Ashtakvarga/Yogini Dasha/predictions/Rudraksha/gemstones, none of which
/// exist in this codebase yet (see the Kundli-report scoping discussion).
/// Laid out to read like the reference AstroTalk report — light paper
/// background, gold/brown accents, numbered section badges — rather than
/// the app's own dark in-app theme, since this is meant to be saved/printed.
class KundliPdfService {
  KundliPdfService._();

  static final _gold = PdfColor.fromInt(0xFFB8860B);
  static final _goldPale = PdfColor.fromInt(0xFFF6EEDD);
  static final _ink = PdfColor.fromInt(0xFF2A2A2A);
  static final _muted = PdfColor.fromInt(0xFF8A8A8A);
  static final _border = PdfColor.fromInt(0xFFE3DCC8);
  static final _paper = PdfColor.fromInt(0xFFFFFDF8);

  static Future<Uint8List> generate({
    required String name,
    required String dobDisplay,
    required String tobDisplay,
    required String place,
    required Map<String, dynamic>? chart,
    required Map<String, dynamic>? dasha,
    required Map<String, dynamic>? doshas,
  }) async {
    final doc = pw.Document();
    final generatedOn = _formatDate(DateTime.now());

    doc.addPage(_coverPage(name, dobDisplay, tobDisplay, place, generatedOn));

    doc.addPage(_sectionPage(
      badge: '01',
      title: 'Birth Details',
      children: [
        _kvGrid([
          ['Name', name],
          ['Date of Birth', dobDisplay],
          ['Time of Birth', tobDisplay.isEmpty ? 'Unknown' : tobDisplay],
          ['Place of Birth', place],
          if (chart != null) ...[
            ['Ascendant', (chart['ascendant'] as Map<String, dynamic>)['sign'] as String? ?? '—'],
            ['Moon Nakshatra', chart['nakshatra'] as String? ?? '—'],
            ['Ayanamsa', chart['ayanamsa'] as String? ?? '—'],
          ],
        ]),
      ],
    ));

    if (chart != null) {
      const charts = [
        ('d1', 'ascendant', 'Lagna Chart · D1', 'The rising sign and the frame of the whole life.'),
        ('d9', 'd9AscendantSignIndex', 'Navamsha · D9', 'The ninth harmonic — marriage, dharma and the ripened fruit of each planet.'),
        ('d10', 'd10AscendantSignIndex', 'Dashamsha · D10', 'The tenth harmonic — career and professional recognition.'),
        ('d60', 'd60AscendantSignIndex', 'Shastiamsha · D60', 'The finest divisional chart — a detailed read of karma and life fortune.'),
      ];
      for (var i = 0; i < charts.length; i++) {
        final (key, ascKey, title, note) = charts[i];
        final planets = chart[key] as List<dynamic>?;
        if (planets == null || planets.isEmpty) continue;
        final ascendantSign = ascKey == 'ascendant'
            ? (chart['ascendant'] as Map<String, dynamic>)['signIndex'] as int?
            : chart[ascKey] as int?;
        doc.addPage(_chartPage(
          badge: '0${i + 2}',
          title: title,
          note: note,
          planets: planets,
          ascendantSign: ascendantSign,
        ));
      }
    }

    if (dasha != null) {
      doc.addPage(_dashaPage(dasha));
    }

    if (chart?['cusps'] != null && (chart!['cusps'] as List).isNotEmpty) {
      doc.addPage(_kpPage(chart['cusps'] as List<dynamic>));
    }

    if (doshas != null) {
      doc.addPage(_doshaPage(doshas));
    }

    doc.addPage(_closingPage());

    return doc.save();
  }

  // ── Shared chrome ─────────────────────────────────────────────────────

  static pw.Widget _footer(pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'TrafficJam.Life · Vedic Astrology Report',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      );

  static pw.Widget _badge(String text) => pw.Container(
        width: 22,
        height: 22,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: _gold, shape: pw.BoxShape.circle),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: _paper, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _sectionHeader(String badge, String title) => pw.Row(
        children: [
          _badge(badge),
          pw.SizedBox(width: 10),
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Divider(color: _border, thickness: 1)),
        ],
      );

  static pw.Page _coverPage(String name, String dob, String tob, String place, String generatedOn) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
      build: (ctx) => pw.Container(
        color: _paper,
        alignment: pw.Alignment.center,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(
              width: 56,
              height: 56,
              decoration: pw.BoxDecoration(color: _goldPale, shape: pw.BoxShape.circle, border: pw.Border.all(color: _gold, width: 1.5)),
            ),
            pw.SizedBox(height: 18),
            pw.Text('TrafficJam.Life', style: pw.TextStyle(fontSize: 12, letterSpacing: 1, color: _gold, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('VEDIC ASTROLOGY REPORT', style: pw.TextStyle(fontSize: 10, letterSpacing: 2, color: _muted)),
            pw.SizedBox(height: 24),
            pw.Text("$name's Kundli", style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 10),
            pw.Text(
              '$dob${tob.isEmpty ? "" : " · $tob"} · $place',
              style: pw.TextStyle(fontSize: 12, color: _muted),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: pw.BoxDecoration(color: _goldPale, borderRadius: pw.BorderRadius.circular(20)),
              child: pw.Text('GENERATED $generatedOn', style: pw.TextStyle(fontSize: 9, letterSpacing: 1, color: _gold, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Page _sectionPage({required String badge, required String title, required List<pw.Widget> children}) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader(badge, title),
          pw.SizedBox(height: 20),
          ...children,
          pw.Spacer(),
          _footer(ctx),
        ],
      ),
    );
  }

  static pw.Widget _kvGrid(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: _border, width: 0.5)),
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: pw.Text(r[0].toUpperCase(), style: pw.TextStyle(fontSize: 9, color: _muted, letterSpacing: 0.5)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: pw.Text(r[1], style: pw.TextStyle(fontSize: 11, color: _ink, fontWeight: pw.FontWeight.bold)),
              ),
            ]),
        ],
      );

  // ── Charts (diamond + table) ─────────────────────────────────────────

  static pw.Page _chartPage({
    required String badge,
    required String title,
    required String note,
    required List<dynamic> planets,
    required int? ascendantSign,
  }) {
    final houses = housesFromPlanets(planets);
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader(badge, title),
          pw.SizedBox(height: 6),
          pw.Text(note, style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.SizedBox(height: 16),
          if (ascendantSign != null)
            pw.Center(child: pw.SizedBox(width: 230, height: 230, child: _diamond(houses)))
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: _goldPale, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(
                'This chart needs an exact birth time to place houses — shown here as signs only.',
                style: pw.TextStyle(fontSize: 9, color: _gold),
              ),
            ),
          pw.SizedBox(height: 18),
          _planetTable(planets),
          pw.Spacer(),
          _footer(ctx),
        ],
      ),
    );
  }

  static const _centers = {
    1: (0.50, 0.25), 2: (0.25, 0.11), 3: (0.11, 0.25),
    4: (0.25, 0.50), 5: (0.11, 0.75), 6: (0.25, 0.89),
    7: (0.50, 0.75), 8: (0.75, 0.89), 9: (0.89, 0.75),
    10: (0.75, 0.50), 11: (0.89, 0.25), 12: (0.75, 0.11),
  };

  /// North-Indian diamond — ported from chart_painters.dart's
  /// NorthChartPainter (same geometry/centers) to the pdf package's own
  /// PdfGraphics canvas, since Flutter's dart:ui Canvas isn't usable here.
  static pw.Widget _diamond(Map<int, String> houses) {
    return pw.CustomPaint(
      size: const PdfPoint(230, 230),
      painter: (canvas, size) {
        canvas
          ..setStrokeColor(_gold)
          ..setLineWidth(1)
          ..drawRect(0, 0, size.x, size.y)
          ..strokePath()
          ..drawLine(0, 0, size.x, size.y)
          ..drawLine(size.x, 0, 0, size.y)
          ..strokePath()
          ..moveTo(size.x / 2, 0)
          ..lineTo(size.x, size.y / 2)
          ..lineTo(size.x / 2, size.y)
          ..lineTo(0, size.y / 2)
          ..closePath()
          ..strokePath();
      },
      child: pw.Stack(
        children: [
          for (var house = 1; house <= 12; house++)
            if (_centers[house] case final c?)
              pw.Positioned(
                left: c.$1 * 230 - 22,
                top: c.$2 * 230 - 12,
                child: pw.SizedBox(
                  width: 44,
                  child: pw.Column(
                    children: [
                      pw.Text('$house', style: pw.TextStyle(fontSize: 6, color: _gold)),
                      pw.Text(
                        houses[house] ?? '',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: (houses[house] ?? '').startsWith('As') ? _gold : _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static pw.Widget _planetTable(List<dynamic> planets) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
        top: pw.BorderSide(color: _border, width: 0.5),
        bottom: pw.BorderSide(color: _border, width: 0.5),
      ),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(3), 2: pw.FlexColumnWidth(3), 3: pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _goldPale),
          children: [
            for (final h in ['GRAHA', 'RASHI', 'DEG', 'H'])
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 8, color: _gold, letterSpacing: 0.5)),
              ),
          ],
        ),
        for (final planet in planets)
          _planetRow(planet as Map<String, dynamic>),
      ],
    );
  }

  static pw.TableRow _planetRow(Map<String, dynamic> p) {
    final retro = p['retrograde'] as bool? ?? false;
    final degree = _formatDeg(p['degreeInSign'] as double);
    final house = p['house'] as int?;
    return pw.TableRow(children: [
      _cell(p['planet'] as String),
      _cell(p['sign'] as String),
      _cell('$degree${retro ? ' R' : ''}'),
      _cell(house?.toString() ?? '—'),
    ]);
  }

  static pw.Widget _cell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _ink)),
      );

  // ── Dasha ─────────────────────────────────────────────────────────────

  static pw.Page _dashaPage(Map<String, dynamic> dasha) {
    final maha = (dasha['maha'] as List<dynamic>).cast<Map<String, dynamic>>();
    final antar = (dasha['antar'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader('06', 'Vimshottari Dasha'),
          pw.SizedBox(height: 6),
          pw.Text('The planetary periods a life passes through, in sequence.', style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.SizedBox(height: 14),
          pw.Text('MAHADASHA', style: pw.TextStyle(fontSize: 9, color: _gold, letterSpacing: 1, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _border, width: 0.5)),
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3), 2: pw.FlexColumnWidth(3)},
            children: [
              for (final p in maha)
                pw.TableRow(
                  decoration: (p['current'] as bool? ?? false) ? pw.BoxDecoration(color: _goldPale) : null,
                  children: [
                    _cell('${p['lord']}${(p['current'] as bool? ?? false) ? ' (Active)' : ''}'),
                    _cell(_formatIso(p['start'] as String)),
                    _cell(_formatIso(p['end'] as String)),
                  ],
                ),
            ],
          ),
          if (antar.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('ANTARDASHA (WITHIN THE ACTIVE MAHADASHA)',
                style: pw.TextStyle(fontSize: 9, color: _gold, letterSpacing: 1, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _border, width: 0.5)),
              columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3), 2: pw.FlexColumnWidth(3)},
              children: [
                for (final p in antar)
                  pw.TableRow(
                    decoration: (p['current'] as bool? ?? false) ? pw.BoxDecoration(color: _goldPale) : null,
                    children: [
                      _cell('${p['lord']}${(p['current'] as bool? ?? false) ? ' (Active)' : ''}'),
                      _cell(_formatIso(p['start'] as String)),
                      _cell(_formatIso(p['end'] as String)),
                    ],
                  ),
              ],
            ),
          ],
          pw.Spacer(),
          _footer(ctx),
        ],
      ),
    );
  }

  // ── KP cusps ──────────────────────────────────────────────────────────

  static pw.Page _kpPage(List<dynamic> cusps) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader('07', 'KP Cuspal Sub-Lords'),
          pw.SizedBox(height: 6),
          pw.Text('Krishnamurti Paddhati — each house cusp with its Sign, Star and Sub Lord.',
              style: pw.TextStyle(fontSize: 10, color: _muted)),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _border, width: 0.5),
              top: pw.BorderSide(color: _border, width: 0.5),
              bottom: pw.BorderSide(color: _border, width: 0.5),
            ),
            columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(2)},
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _goldPale),
                children: [
                  for (final h in ['HOUSE', 'SIGN', 'STAR LORD', 'SUB LORD'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      child: pw.Text(h, style: pw.TextStyle(fontSize: 8, color: _gold, letterSpacing: 0.5)),
                    ),
                ],
              ),
              for (final c in cusps.cast<Map<String, dynamic>>())
                pw.TableRow(children: [
                  _cell('${c['house']}'),
                  _cell(c['sign'] as String),
                  _cell((c['lordship'] as Map<String, dynamic>)['starLord'] as String),
                  _cell((c['lordship'] as Map<String, dynamic>)['subLord'] as String),
                ]),
            ],
          ),
          pw.Spacer(),
          _footer(ctx),
        ],
      ),
    );
  }

  // ── Doshas ────────────────────────────────────────────────────────────

  static pw.Page _doshaPage(Map<String, dynamic> doshas) {
    final mangal = doshas['mangal'] as Map<String, dynamic>?;
    final kaalSarp = doshas['kaalSarp'] as Map<String, dynamic>?;
    final sadeSati = doshas['sadeSati'] as Map<String, dynamic>?;
    final isManglik = mangal?['fromLagna'] as bool? ?? false;
    final hasKaalSarp = kaalSarp?['isPresent'] as bool? ?? false;
    final sadeSatiActive = sadeSati?['isActive'] as bool? ?? false;

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader('08', 'Dosha Analysis'),
          pw.SizedBox(height: 18),
          _doshaRow('Manglik Dosha', isManglik ? 'Manglik' : 'Non-Manglik', isManglik),
          pw.SizedBox(height: 10),
          _doshaRow('Kaal Sarp Dosha', hasKaalSarp ? 'Present' : 'Not Present', hasKaalSarp),
          pw.SizedBox(height: 10),
          _doshaRow('Sade Sati', sadeSatiActive ? 'Active${sadeSati?['phase'] != null ? " — ${sadeSati!['phase']}" : ""}' : 'Not Active', sadeSatiActive),
          pw.Spacer(),
          _footer(ctx),
        ],
      ),
    );
  }

  static pw.Widget _doshaRow(String label, String status, bool flagged) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: flagged ? PdfColor.fromInt(0xFFFCEEEE) : PdfColor.fromInt(0xFFEFF7EF),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 12, color: _ink, fontWeight: pw.FontWeight.bold)),
            pw.Text(status,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: flagged ? PdfColor.fromInt(0xFFB33A3A) : PdfColor.fromInt(0xFF3A8A4A),
                  fontWeight: pw.FontWeight.bold,
                )),
          ],
        ),
      );

  static pw.Page _closingPage() {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Container(
        color: _paper,
        alignment: pw.Alignment.center,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('THANK YOU FOR READING', style: pw.TextStyle(fontSize: 9, letterSpacing: 2, color: _muted)),
            pw.SizedBox(height: 8),
            pw.Text('Generated with TrafficJam.Life', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 16),
            pw.Text('— END OF REPORT —', style: pw.TextStyle(fontSize: 9, color: _gold)),
          ],
        ),
      ),
    );
  }

  // ── Formatting helpers ────────────────────────────────────────────────

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _formatDate(DateTime d) => '${_months[d.month - 1].substring(0, 3).toUpperCase()} ${d.day}, ${d.year}';

  static String _formatIso(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day} ${_months[d.month - 1].substring(0, 3)} ${d.year}';
  }

  static String _formatDeg(double deg) {
    final wholeDeg = deg.floor();
    final minutes = ((deg - wholeDeg) * 60).round();
    if (minutes == 60) return "${(wholeDeg + 1).toString().padLeft(2, '0')}°00'";
    return "${wholeDeg.toString().padLeft(2, '0')}°${minutes.toString().padLeft(2, '0')}'";
  }
}
