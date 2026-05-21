import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bush_track/core/models/artifact.dart';
import 'package:bush_track/core/utils/web_helpers.dart';

class ArtifactPdfService {
  /// Generate and download a PDF field report for the given artifacts.
  static Future<void> exportReport(List<Artifact> artifacts) async {
    final doc = pw.Document();

    // ── Cover page ──────────────────────────────────────────────────────────
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: const pw.BoxDecoration(
              color: PdfColor(0.047, 0.059, 0.118), // #0C0F1E
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BushTrack',
                    style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('Heritage Artifact Field Report',
                    style: const pw.TextStyle(
                        fontSize: 16, color: PdfColors.grey300)),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          _row('Report generated', _fmt(DateTime.now())),
          _row('Total artifacts', '${artifacts.length}'),
          _row('Signed-off', '${artifacts.where((a) => a.signedOff).length}'),
          _row('GPS-pinned',
              '${artifacts.where((a) => a.latitude != null).length}'),
        ],
      ),
    ));

    // ── One page per artifact ────────────────────────────────────────────────
    for (final a in artifacts) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const pw.BoxDecoration(
                color: PdfColor(0.482, 0.184, 1.0), // #7B2FFF
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(a.label,
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                  if (a.signedOff)
                    pw.Text('✓ SIGNED OFF',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.green300)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Core fields table
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                _tableRow('ID', '${a.id ?? '—'}'),
                _tableRow('Material', a.materialType ?? '—'),
                _tableRow('Dimensions', a.dimensions ?? '—'),
                _tableRow('Condition', a.condition ?? '—'),
                _tableRow(
                    'GPS',
                    a.latitude != null
                        ? '${a.latitude!.toStringAsFixed(6)}, ${a.longitude!.toStringAsFixed(6)}'
                        : 'Not recorded'),
                if (a.altitude != null)
                  _tableRow('Altitude', '${a.altitude!.toStringAsFixed(1)} m'),
                _tableRow('Geologist', a.geologist ?? '—'),
                _tableRow('Signed Off', a.signedOff ? 'Yes' : 'No'),
                _tableRow('Logged', _fmt(a.createdAt)),
              ],
            ),

            if (a.fieldNotes?.isNotEmpty == true) ...[
              pw.SizedBox(height: 16),
              pw.Text('Field Notes',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius:
                      pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(a.fieldNotes!,
                    style: const pw.TextStyle(fontSize: 10)),
              ),
            ],

            if (a.photoPaths.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Photos: ${a.photoPaths.length} attached',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ],

            // Footer
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Text('BushTrack Heritage Logger — Confidential Field Record',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ));
    }

    final bytes = await doc.save();
    final filename =
        'artifact_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await downloadBytes(filename, bytes);
    debugPrint('ArtifactPdfService: exported $filename (${bytes.length} bytes)');
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.SizedBox(
              width: 160,
              child: pw.Text(label,
                  style: const pw.TextStyle(color: PdfColors.grey700,
                      fontSize: 11))),
          pw.Text(value,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ]),
      );

  static pw.TableRow _tableRow(String label, String value) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.white),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColors.grey800)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      );

  static String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
