import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/events/domain/event.dart';

class ExportService {
  ExportService._();

  static final _dateFmt = DateFormat('EEEE, MMMM d, yyyy');
  static final _timeFmt = DateFormat('h:mm a');
  static final _fileFmt = DateFormat('yyyy-MM-dd');

  // ── Lineup PDF ──────────────────────────────────────────────────────────────

  /// Generates a PDF of the lineup and opens the system share/print dialog.
  ///
  /// [assignments] maps position → player display name (empty string = unassigned).
  static Future<void> shareLineupPdf({
    required String teamName,
    required String sport,
    required String eventLabel,
    required DateTime eventDate,
    required Map<String, String> assignments,
  }) async {
    final pdf = pw.Document();

    final dateStr = _dateFmt.format(eventDate);
    final timeStr = _timeFmt.format(eventDate);
    final rows = assignments.entries.toList();
    final filled = rows.where((e) => e.value.isNotEmpty).length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(teamName,
                style:
                    pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('$eventLabel — $dateStr at $timeStr',
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text('$filled / ${rows.length} positions filled',
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 12),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell('Position', bold: true),
                    _cell('Player', bold: true),
                  ],
                ),
                // Data rows
                for (final entry in rows)
                  pw.TableRow(children: [
                    _cell(entry.key),
                    _cell(entry.value.isNotEmpty ? entry.value : '—',
                        color: entry.value.isEmpty
                            ? PdfColors.grey500
                            : PdfColors.black),
                  ]),
              ],
            ),

            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Generated ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${_sanitize(teamName)}_lineup_${_fileFmt.format(eventDate)}.pdf',
    );
  }

  // ── Availability CSV ────────────────────────────────────────────────────────

  /// Builds a CSV of availability responses and opens the system share sheet.
  ///
  /// [rows] is a list of (name, response) pairs e.g. ('Alice', 'Yes').
  static Future<void> shareAvailabilityCsv({
    required String teamName,
    required String eventLabel,
    required DateTime eventDate,
    required List<({String name, String response})> rows,
  }) async {
    final buf = StringBuffer();
    buf.writeln('"Team","Event","Date"');
    buf.writeln(
        '"${_escapeCsv(teamName)}","${_escapeCsv(eventLabel)}","${_dateFmt.format(eventDate)}"');
    buf.writeln();
    buf.writeln('"Name","Response"');
    for (final r in rows) {
      buf.writeln('"${_escapeCsv(r.name)}","${_escapeCsv(r.response)}"');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: buf.toString(),
        subject: '$teamName — Availability ($eventLabel)',
      ),
    );
  }

  // ── Boat seating PDF ────────────────────────────────────────────────────────

  /// Generates a boat seating chart PDF and opens the share/print dialog.
  ///
  /// [assignments] maps position key (e.g. 'Boat 1 Row 3 Left') → player name.
  /// [numBoats] / [rowsPerBoat] / [hasDrummer] define the layout.
  static Future<void> shareBoatSeatingPdf({
    required String teamName,
    required String eventLabel,
    required DateTime eventDate,
    required Map<String, String> assignments,
    required int numBoats,
    required int rowsPerBoat,
    required bool hasDrummer,
  }) async {
    final pdf = pw.Document();
    final dateStr = _dateFmt.format(eventDate);
    final timeStr = _timeFmt.format(eventDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          // Header
          pw.Text(teamName,
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Boat Seating — $eventLabel — $dateStr at $timeStr',
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),

          // One section per boat
          for (int b = 1; b <= numBoats; b++) ...[
            pw.Container(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: pw.Text('Boat $b',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800)),
            ),
            pw.SizedBox(height: 6),

            // Drummer row
            if (hasDrummer)
              _boatRow('Drummer', assignments['Boat $b Drummer'] ?? '—', ''),

            // Paddler rows
            for (int r = 1; r <= rowsPerBoat; r++)
              _boatRow(
                'Row $r',
                assignments['Boat $b Row $r Left'] ?? '—',
                assignments['Boat $b Row $r Right'] ?? '—',
              ),

            // Steersperson
            _boatRow(
                'Steersperson', assignments['Boat $b Steersperson'] ?? '—', ''),

            pw.SizedBox(height: 16),
          ],

          pw.Divider(),
          pw.Text(
            'Generated ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${_sanitize(teamName)}_boats_${_fileFmt.format(eventDate)}.pdf',
    );
  }

  static pw.Widget _boatRow(String label, String left, String right) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                color: PdfColors.grey50,
              ),
              child: pw.Text(left, style: const pw.TextStyle(fontSize: 10)),
            ),
          ),
          if (right.isNotEmpty) ...[
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  color: PdfColors.grey50,
                ),
                child: pw.Text(right, style: const pw.TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _cell(String text,
      {bool bold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static String _escapeCsv(String s) => s.replaceAll('"', '""');

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');

  // ── Calendar (.ics) export ──────────────────────────────────────────────────

  static Future<void> shareEventToCalendar({
    required String teamName,
    required Event event,
  }) async {
    final startDate = event.date;
    final endDate = startDate.add(const Duration(hours: 1));
    final now = DateTime.now();

    final dateFormatter = DateFormat('yyyyMMddTHHmmss');

    final uid = '${event.eventId}@sportsrostering.app';
    final summary = '$teamName - ${event.type.label}';
    final description =
        event.notes?.isNotEmpty == true ? event.notes! : 'Sport Rosters event';

    final ics = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Sport Rosters//EN
CALSCALE:GREGORIAN
METHOD:PUBLISH
BEGIN:VEVENT
UID:$uid
DTSTAMP:${dateFormatter.format(now)}Z
DTSTART:${dateFormatter.format(startDate)}
DTEND:${dateFormatter.format(endDate)}
SUMMARY:$summary
LOCATION:${_escapeIcs(event.location)}
DESCRIPTION:$description
STATUS:CONFIRMED
TRANSP:OPAQUE
END:VEVENT
END:VCALENDAR
''';

    await SharePlus.instance.share(
      ShareParams(
        text: ics,
        subject: summary,
      ),
    );
  }

  static String _escapeIcs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }
}
