/// Class record reports (requirements 4.2–4.3): formal PDF sheets that can be
/// printed or saved, plus the spreadsheet-ready class record CSV (4.4).
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/backup.dart';
import '../services/grading.dart';

const _navy = PdfColor.fromInt(0xFF0A3A8C);
const _ink = PdfColor.fromInt(0xFF0B2E6E);
const _soft = PdfColor.fromInt(0xFF5A6E96);
const _head = PdfColor.fromInt(0xFFEAF2FD);
const _totalBg = PdfColor.fromInt(0xFFF4F8FF);

String _fmt(double? value, [int digits = 2]) =>
    value == null || value.isNaN ? '—' : value.toStringAsFixed(digits);

List<Student> _studentsOfSection(BackupData data, String sectionId) =>
    data.students.values.where((s) => s.sectionId == sectionId).toList()
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

/// One student's row for a subject + quarter, shared by PDF and CSV.
class _Row {
  _Row(this.student, this.pcts, this.finalGrade);

  final Student student;

  /// Percentage earned per component (null when nothing recorded).
  final Map<ComponentKey, double?> pcts;
  final double? finalGrade;
}

List<_Row> _rowsFor(BackupData data, Subject subject, int quarter) {
  final sheet = data.sheets['${subject.id}::q$quarter'];
  return [
    for (final student in _studentsOfSection(data, subject.sectionId))
      _Row(
        student,
        {
          for (final key in ComponentKey.values)
            key: sheet == null
                ? null
                : computeComponent(sheet, data.scores, student.id, key)
                    .percentage,
        },
        sheet == null
            ? null
            : computeQuarterGrade(
                subject.weights,
                subject.transmute,
                sheet,
                data.scores,
                student.id,
              ).finalGrade,
      ),
  ];
}

double? _average(List<double?> values) {
  final usable = values.whereType<double>().toList();
  if (usable.isEmpty) return null;
  return usable.reduce((a, b) => a + b) / usable.length;
}

double? _wwOf(Map<ComponentKey, double?> pcts) => _average([
      pcts[ComponentKey.quizzes],
      pcts[ComponentKey.assignments],
      pcts[ComponentKey.activities],
    ]);

/* --------------------------------- PDF ------------------------------------ */

pw.Widget _heading(String title, String subtitle) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 11, color: _soft),
        ),
        pw.SizedBox(height: 10),
      ],
    );

pw.Widget _metaRow(String label, String value, {String? label2, String? value2}) {
  pw.Widget cell(String text, {bool bold = false, bool labelCell = false}) =>
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 10,
              color: labelCell ? _soft : _ink,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      );

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(width: 78, child: cell(label, labelCell: true)),
      cell(value, bold: true),
      if (label2 != null) pw.SizedBox(width: 70, child: cell(label2, labelCell: true)),
      if (value2 != null) cell(value2, bold: true),
    ],
  );
}

pw.Widget _signatures() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 40),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          for (final label in ["Teacher's Signature", 'Head of School'])
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  pw.Container(height: 1, color: _ink),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    label,
                    style: const pw.TextStyle(fontSize: 10, color: _ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

/// Full class record sheet for one subject + quarter (landscape A4).
Future<Uint8List> buildClassRecordPdfBytes(
  BackupData data,
  Section section,
  Subject subject,
  int quarter,
) async {
  final doc = pw.Document();
  final students = _studentsOfSection(data, subject.sectionId);
  final sheet = data.sheets['${subject.id}::q$quarter'];
  final rows = _rowsFor(data, subject, quarter);

  // Column headers: No., Name, then each component's items + its % column.
  final headers = <String>['No.', 'Name of Student'];
  final groups = <ComponentKey>[];
  for (final key in ComponentKey.values) {
    final items = sheet?.items[key] ?? const <AssessmentItem>[];
    for (final item in items) {
      headers.add('${key.short}\n${item.title}\n/${item.max.round()}');
    }
    headers.add('${key.short}\n%');
    groups.add(key);
  }
  headers.addAll(['WW\n%', 'PT\n%', 'QA\n%', 'FINAL\nGRADE', 'REMARKS']);

  final dataRows = <List<String>>[
    for (var i = 0; i < rows.length; i++)
      [
        '${i + 1}',
        rows[i].student.fullName,
        for (final key in ComponentKey.values)
          ...[
            for (final item in sheet?.items[key] ?? const <AssessmentItem>[])
              _scoreText(data, sheet, rows[i].student, item),
            _fmt(rows[i].pcts[key], 1),
          ],
        _fmt(_wwOf(rows[i].pcts), 1),
        _fmt(rows[i].pcts[ComponentKey.performanceTasks], 1),
        _fmt(rows[i].pcts[ComponentKey.examinations], 1),
        _fmt(rows[i].finalGrade, 1),
        gradeRemarks(rows[i].finalGrade),
      ],
  ];

  // Class average row.
  final avgRow = <String>[
    '',
    'CLASS AVERAGE',
    for (final key in ComponentKey.values)
      ...[
        for (final item in sheet?.items[key] ?? const <AssessmentItem>[])
          _fmt(
            _average([
              for (final student in students)
                double.tryParse(_scoreText(data, sheet, student, item)
                    .replaceAll('—', '')),
            ].cast<double?>()),
            1,
          ),
        _fmt(_average([for (final row in rows) row.pcts[key]]), 1),
      ],
    _fmt(_average([for (final row in rows) _wwOf(row.pcts)]), 1),
    _fmt(_average([for (final row in rows) row.pcts[ComponentKey.performanceTasks]]), 1),
    _fmt(_average([for (final row in rows) row.pcts[ComponentKey.examinations]]), 1),
    '',
    '',
  ];

  final finals = [for (final row in rows) row.finalGrade].whereType<double>().toList();
  final classAvg = finals.isEmpty ? null : finals.reduce((a, b) => a + b) / finals.length;
  final highest = finals.isEmpty ? null : finals.reduce((a, b) => a > b ? a : b);
  final lowest = finals.isEmpty ? null : finals.reduce((a, b) => a < b ? a : b);
  final passed = finals.where((f) => f >= passingGrade).length;

  final weights = subject.weights;
  String pct(ComponentKey key) => '${(weights[key] ?? 0).round()}%';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _heading(
            'CLASS RECORD',
            'Tugbo Integrated School — ${section.gradeLevel}, ${section.section}',
          ),
          _metaRow('Subject', subject.name, label2: 'Quarter', value2: 'Q$quarter'),
          _metaRow('School Year', section.schoolYear,
              label2: 'Teacher',
              value2: subject.teacherName.isEmpty
                  ? data.teacherName
                  : subject.teacherName),
          _metaRow(
            'Weights',
            'Quiz ${pct(ComponentKey.quizzes)} · Assign ${pct(ComponentKey.assignments)} · '
                'Act ${pct(ComponentKey.activities)} · PT ${pct(ComponentKey.performanceTasks)} · '
                'Exam ${pct(ComponentKey.examinations)}'
                '${subject.transmute ? ' · transmuted (DO 8, s. 2015)' : ''}',
          ),
          pw.SizedBox(height: 8),
          if (rows.isEmpty)
            pw.Text(
              'No students in this class.',
              style: const pw.TextStyle(fontSize: 11, color: _soft),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: [...dataRows, avgRow],
              headerCount: 1,
              headerStyle: pw.TextStyle(
                fontSize: 6.5,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7, color: _ink),
              oddCellStyle: const pw.TextStyle(fontSize: 7, color: _ink),
              cellPadding: const pw.EdgeInsets.all(3),
              headerPadding: const pw.EdgeInsets.all(3),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.center,
              headerDecoration: const pw.BoxDecoration(color: _head),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: _totalBg),
              cellAlignments: {
                1: pw.Alignment.centerLeft,
                headers.length - 1: pw.Alignment.centerLeft,
              },
              defaultColumnWidth: const pw.FlexColumnWidth(),
            ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const ['Class Average', 'Highest', 'Lowest', 'Passed (≥75)'],
            data: [
              [
                _fmt(classAvg),
                _fmt(highest),
                _fmt(lowest),
                '$passed / ${students.length}',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
            cellStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: _head),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
            },
          ),
          _signatures(),
        ],
      ),
    ),
  );
  return doc.save();
}

String _scoreText(
  BackupData data,
  ScoreSheet? sheet,
  Student student,
  AssessmentItem item,
) {
  if (sheet == null) return '—';
  final value = data.scores['${sheet.id}|${student.id}|${item.id}'];
  if (value == null) return '—';
  return value == value.roundToDouble()
      ? '${value.round()}'
      : value.toString();
}

/// Roster-only sheet (names, LRN, guardian) for documentation (portrait A4).
Future<Uint8List> buildRosterPdfBytes(
  BackupData data,
  String sectionId,
  Section section,
) async {
  final doc = pw.Document();
  final students = _studentsOfSection(data, sectionId);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _heading(
            'CLASS ROSTER',
            'Tugbo Integrated School — ${section.gradeLevel}, ${section.section} · '
                'SY ${section.schoolYear}',
          ),
          if (students.isEmpty)
            pw.Text(
              'No students.',
              style: const pw.TextStyle(fontSize: 11, color: _soft),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Seat',
                'Name',
                'LRN',
                'Gender',
                'Birthday',
                'Guardian',
                'Contact',
              ],
              data: [
                for (final student in students)
                  [
                    '${student.seatNumber}',
                    student.fullName,
                    student.lrn.isEmpty ? '—' : student.lrn,
                    student.gender.isEmpty ? '—' : student.gender,
                    student.birthday.isEmpty ? '—' : student.birthday,
                    student.guardianName.isEmpty ? '—' : student.guardianName,
                    student.guardianContact.isEmpty
                        ? '—'
                        : student.guardianContact,
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
              cellPadding: const pw.EdgeInsets.all(5),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: _head),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: _totalBg),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(2.4),
                2: pw.FlexColumnWidth(1.6),
                3: pw.FlexColumnWidth(0.9),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.8),
                6: pw.FlexColumnWidth(1.3),
              },
            ),
          pw.Spacer(),
          pw.Center(
            child: pw.Text(
              'Generated by TIS ClassTrack · '
              '${DateFormat('MMMM d, y').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: _soft),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Open the system print dialog with the class record.
Future<bool> printClassRecord(
  BackupData data,
  Section section,
  Subject subject,
  int quarter,
) async {
  final bytes = await buildClassRecordPdfBytes(data, section, subject, quarter);
  return Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: 'Class Record ${subject.name} Q$quarter',
  );
}

/// Open the system share sheet with the class record as a PDF.
Future<bool> shareClassRecordPdf(
  BackupData data,
  Section section,
  Subject subject,
  int quarter,
) async {
  final bytes = await buildClassRecordPdfBytes(data, section, subject, quarter);
  return Printing.sharePdf(
    bytes: bytes,
    filename: '${_safeName('class-record-${subject.name}-Q$quarter')}.pdf',
  );
}

/// Open the system share sheet with the roster as a PDF.
Future<bool> shareRosterPdf(
  BackupData data,
  String sectionId,
  Section section,
) async {
  final bytes = await buildRosterPdfBytes(data, sectionId, section);
  return Printing.sharePdf(
    bytes: bytes,
    filename: '${_safeName('roster-${section.gradeLevel}-${section.section}')}.pdf',
  );
}

/// Share an arbitrary file (CSV exports) with the system share sheet.
Future<void> shareFile(String path, {String? title}) {
  return SharePlus.instance.share(
    ShareParams(files: [XFile(path)], title: title),
  );
}

String _safeName(String value) => value.replaceAll(RegExp(r'[^a-zA-Z0-9-_]+'), '-');

/* ---------------------------------- CSV ------------------------------------ */

String _csvCell(String value) => RegExp(r'[",\n]').hasMatch(value)
    ? '"${value.replaceAll('"', '""')}"'
    : value;

/// Wide CSV of computed grades for a subject + quarter (spreadsheet-ready).
String buildClassRecordCsv(
  BackupData data,
  Section section,
  Subject subject,
  int quarter,
) {
  final rows = _rowsFor(data, subject, quarter);

  final header = <String>[
    'Seat',
    'Student',
    'LRN',
    'Birthday',
    'Guardian',
    'Contact',
    for (final key in ComponentKey.values) '${key.short} %',
    'Final Grade',
    'Remarks',
  ];

  final lines = <String>[
    header.map(_csvCell).join(','),
    for (final row in rows)
      [
        '${row.student.seatNumber}',
        row.student.fullName,
        row.student.lrn,
        row.student.birthday,
        row.student.guardianName,
        row.student.guardianContact,
        for (final key in ComponentKey.values)
          row.pcts[key] == null ? '' : row.pcts[key]!.toStringAsFixed(1),
        row.finalGrade == null ? '' : row.finalGrade!.toStringAsFixed(2),
        gradeRemarks(row.finalGrade),
      ].map(_csvCell).join(','),
  ];

  final finals = [for (final row in rows) row.finalGrade].whereType<double>().toList();
  lines
    ..add('')
    ..add([
      'CLASS AVERAGE',
      '', '', '', '', '',
      for (final key in ComponentKey.values)
        _fmt(_average([for (final row in rows) row.pcts[key]]), 1),
      finals.isEmpty
          ? ''
          : (finals.reduce((a, b) => a + b) / finals.length).toStringAsFixed(2),
      '',
    ].map(_csvCell).join(','));

  return lines.join('\r\n');
}
