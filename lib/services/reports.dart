/// Formal PDF reports: class records, term grade sheets, final grades,
/// learner rosters, attendance summaries and per-learner report cards —
/// printable or shareable.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import 'backup.dart';
import 'bmi.dart';
import 'grading.dart';

const _navy = PdfColor.fromInt(0xFF0A3A8C);
const _ink = PdfColor.fromInt(0xFF0B2E6E);
const _soft = PdfColor.fromInt(0xFF5A6E96);
const _head = PdfColor.fromInt(0xFFEAF2FD);
const _alt = PdfColor.fromInt(0xFFF7FAFF);

String _num(double? value, [int digits = 2]) =>
    value == null || value.isNaN ? '—' : value.toStringAsFixed(digits);

String _grade(double? value) => value == null ? '—' : '${reportGrade(value)}';

/// ASCII-safe placeholder for blank cells: the built-in PDF font cannot draw
/// the em dash, so report-card tables use a hyphen instead.
String _mark(double? value) => value == null ? '-' : '${reportGrade(value)}';

pw.Widget _header(String title, List<(String, String)> meta) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TUGBO INTEGRATED SCHOOL',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    letterSpacing: 1.1,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Mobile-Based Offline Class Record System',
                  style: const pw.TextStyle(fontSize: 8.5, color: _soft),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TugboTrack',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.Text(
                DateFormat.yMMMMd().format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 8, color: _soft),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(height: 2, color: _navy),
      pw.SizedBox(height: 10),
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 18,
        runSpacing: 4,
        children: [
          for (final entry in meta)
            pw.Text(
              '${entry.$1}: ${entry.$2}',
              style: const pw.TextStyle(fontSize: 8.5, color: _soft),
            ),
        ],
      ),
      pw.SizedBox(height: 12),
    ],
  );
}

pw.Widget _table(
  List<String> headers,
  List<List<String>> rows, {
  List<double>? widths,
  List<int> numericColumns = const [],
}) {
  if (rows.isEmpty) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _alt,
        border: pw.Border.all(color: _head),
      ),
      child: pw.Text(
        'No records yet.',
        style: const pw.TextStyle(fontSize: 9, color: _soft),
      ),
    );
  }
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    headerDecoration: const pw.BoxDecoration(color: _head),
    headerStyle: pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
    cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      for (final index in numericColumns) index: pw.Alignment.center,
    },
    columnWidths: widths == null
        ? null
        : {
            for (var index = 0; index < widths.length; index++)
              index: pw.FixedColumnWidth(widths[index]),
          },
    oddRowDecoration: const pw.BoxDecoration(color: _alt),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  );
}

pw.Widget _signature(String teacherName) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 26),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 170, height: 0.8, color: PdfColors.grey600),
                pw.SizedBox(height: 3),
                pw.Text(
                  teacherName.isEmpty ? 'Subject Teacher' : teacherName,
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Subject Teacher',
                  style: const pw.TextStyle(fontSize: 7.5, color: _soft),
                ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(width: 170, height: 0.8, color: PdfColors.grey600),
                pw.SizedBox(height: 3),
                pw.Text(
                  'School Head / Principal',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Tugbo Integrated School',
                  style: const pw.TextStyle(fontSize: 7.5, color: _soft),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Document _document(String title, BackupData data) {
  final doc = pw.Document(title: title, author: 'TugboTrack');
  return doc;
}

Future<Uint8List> _finish(pw.Document doc) async => await doc.save();

/* ------------------------------ class record ------------------------------ */

/// One subject, one term: WW / PT / TE percentages, initial grade, term grade.
Future<Uint8List> buildClassRecordPdfBytes(
  BackupData data,
  Section section,
  Subject subject,
  int term,
) async {
  final doc = _document('Class Record', data);
  final roster = data.rosterOf(section.id);
  final rows = <List<String>>[];
  final finals = <double>[];
  for (final student in roster) {
    final result = data.gradeOf(subject, term, student.id);
    String pct(AssessmentCategory category) =>
        _num(result.components[category]?.percentage, 1);
    if (result.termGrade != null) finals.add(result.termGrade!);
    rows.add([
      '${student.seatNumber}',
      student.fullName,
      pct(AssessmentCategory.writtenWorks),
      pct(AssessmentCategory.performanceTasks),
      pct(AssessmentCategory.termExam),
      _num(result.initialGrade),
      _grade(result.termGrade),
      gradeDescriptors(result.termGrade),
    ]);
  }
  final average = finals.isEmpty
      ? null
      : finals.reduce((a, b) => a + b) / finals.length;
  final passed = finals.where((grade) => grade >= passingGrade).length;

  final sheet = data.sheetOf(subject.id, term);
  final assessmentRows = <List<String>>[];
  if (sheet != null) {
    for (final category in AssessmentCategory.values) {
      for (final item in sheet.itemsOf(category)) {
        assessmentRows.add([
          category.short,
          item.title,
          _num(item.max, 0),
          _num(subject.weights[category] ?? 0, 0),
        ]);
      }
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: _soft),
        ),
      ),
      build: (context) => [
        _header('CLASS RECORD', [
          ('Class', section.title),
          ('School Year', section.schoolYear),
          ('Term', termLabel(term)),
          ('Subject', subject.name),
          ('Curriculum', section.curriculum.label),
          (
            'Weights',
            [
              for (final category in AssessmentCategory.values)
                '${category.short} ${_num(subject.weights[category] ?? 0, 0)}%',
            ].join(' · '),
          ),
        ]),
        _table(
          const ['#', 'Learner', 'WW %', 'PT %', 'TE %', 'Initial', 'Term', 'Descriptor'],
          rows,
          widths: [22, 148, 42, 42, 42, 48, 40, 96],
          numericColumns: [0, 2, 3, 4, 5, 6],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Text(
              'Class average: ${average == null ? '—' : _num(average, 2)}   ·   '
              'Passed: $passed / ${roster.length}',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
        if (assessmentRows.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Text(
            'Assessments recorded (${termLabel(term)})',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 6),
          _table(
            const ['Category', 'Title', 'Highest Score', 'Weight %'],
            assessmentRows,
            widths: [60, 260, 90, 80],
            numericColumns: [2, 3],
          ),
        ],
        _signature(
          subject.teacherName.isEmpty ? data.teacherName : subject.teacherName,
        ),
      ],
    ),
  );
  return _finish(doc);
}

/* ---------------------------- term grade sheet ---------------------------- */

/// All subjects of a class in one term: the term grade per learner.
Future<Uint8List> buildTermGradesPdfBytes(
  BackupData data,
  Section section,
  int term,
) async {
  final doc = _document('Term Grades', data);
  final subjects = data.subjectsOf(section.id)
      .where((subject) => subject.covers(term))
      .toList();
  final roster = data.rosterOf(section.id);

  final rows = <List<String>>[];
  for (final student in roster) {
    final grades = <String>[
      for (final subject in subjects)
        _grade(data.gradeOf(subject, term, student.id).termGrade),
    ];
    final values = [
      for (final subject in subjects) data.gradeOf(subject, term, student.id).termGrade,
    ].whereType<double>().toList();
    final general = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    rows.add([
      '${student.seatNumber}',
      student.fullName,
      ...grades,
      _grade(general),
      gradeDescriptors(general),
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 22),
      build: (context) => [
        _header('TERM GRADE REPORT', [
          ('Class', section.title),
          ('School Year', section.schoolYear),
          ('Term', termLabel(term)),
          ('Learners', '${roster.length}'),
        ]),
        if (subjects.isEmpty)
          pw.Text(
            'No subjects are offered in ${termLabel(term)}.',
            style: const pw.TextStyle(fontSize: 9, color: _soft),
          )
        else
          _table(
            ['#', 'Learner', for (final subject in subjects) subject.name, 'General Average', 'Descriptor'],
            rows,
            numericColumns: [
              for (var index = 2; index <= subjects.length + 3; index++) index,
            ],
          ),
        _signature(data.teacherName),
      ],
    ),
  );
  return _finish(doc);
}

/* ------------------------------ final grades ------------------------------ */

/// Final grades of the class: term averages per subject.
Future<Uint8List> buildFinalGradesPdfBytes(
  BackupData data,
  Section section,
) async {
  final doc = _document('Final Grades', data);
  final subjects = data.subjectsOf(section.id);
  final roster = data.rosterOf(section.id);

  final rows = <List<String>>[];
  for (final student in roster) {
    final finals = <String>[
      for (final subject in subjects) _grade(data.finalGradeOf(subject, student.id)),
    ];
    final values = [
      for (final subject in subjects) data.finalGradeOf(subject, student.id),
    ].whereType<double>().toList();
    final general =
        values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    rows.add([
      '${student.seatNumber}',
      student.fullName,
      ...finals,
      _grade(general),
      gradeRemarks(general).isEmpty ? gradeDescriptors(general) : gradeRemarks(general),
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 22),
      build: (context) => [
        _header('FINAL GRADE REPORT', [
          ('Class', section.title),
          ('School Year', section.schoolYear),
          ('Subjects', '${subjects.length}'),
          ('Learners', '${roster.length}'),
        ]),
        if (subjects.isEmpty)
          pw.Text(
            'Add subjects to this class to compute final grades.',
            style: const pw.TextStyle(fontSize: 9, color: _soft),
          )
        else
          _table(
            ['#', 'Learner', for (final subject in subjects) subject.name, 'General Average', 'Remarks'],
            rows,
            numericColumns: [
              for (var index = 2; index <= subjects.length + 3; index++) index,
            ],
          ),
        _signature(data.teacherName),
      ],
    ),
  );
  return _finish(doc);
}

/* --------------------------------- roster --------------------------------- */

/// Learner profile sheet of a class.
Future<Uint8List> buildRosterPdfBytes(BackupData data, Section section) async {
  final doc = _document('Learner Roster', data);
  final roster = data.rosterOf(section.id);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      build: (context) => [
        _header('LEARNER ROSTER', [
          ('Class', section.title),
          ('School Year', section.schoolYear),
          ('Curriculum', section.curriculum.label),
          ('Learners', '${roster.length}'),
        ]),
        _table(
          const ['#', 'Name', 'LRN', 'Sex', 'Birthday', 'Guardian', 'Contact'],
          [
            for (final student in roster)
              [
                '${student.seatNumber}',
                student.fullName,
                student.lrn.isEmpty ? '—' : student.lrn,
                student.gender.isEmpty
                    ? '—'
                    : student.gender.substring(0, 1).toUpperCase(),
                student.birthday.isEmpty ? '—' : student.birthday,
                student.guardianName.isEmpty ? '—' : student.guardianName,
                student.guardianContact.isEmpty ? '—' : student.guardianContact,
              ],
          ],
          widths: [22, 120, 66, 26, 62, 96, 76],
          numericColumns: [0, 3],
        ),
        _signature(data.teacherName),
      ],
    ),
  );
  return _finish(doc);
}

/* ------------------------------- attendance ------------------------------- */

/// Attendance summary of a class.
Future<Uint8List> buildAttendancePdfBytes(
  BackupData data,
  Section section,
) async {
  final doc = _document('Attendance', data);
  final roster = data.rosterOf(section.id);
  final days = data.attendance.values
      .where((day) => day.sectionId == section.id)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final rows = <List<String>>[];
  for (final student in roster) {
    var present = 0, late = 0, absent = 0, excused = 0, recorded = 0;
    for (final day in days) {
      final status = day.statuses[student.id];
      if (status == null) continue;
      recorded += 1;
      switch (status) {
        case AttendanceStatus.present:
          present += 1;
        case AttendanceStatus.late:
          late += 1;
        case AttendanceStatus.absent:
          absent += 1;
        case AttendanceStatus.excused:
          excused += 1;
      }
    }
    final rate = recorded == 0 ? null : (present + late) / recorded * 100;
    rows.add([
      '${student.seatNumber}',
      student.fullName,
      '$recorded',
      '$present',
      '$late',
      '$absent',
      '$excused',
      rate == null ? '—' : '${_num(rate, 1)}%',
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      build: (context) => [
        _header('ATTENDANCE REPORT', [
          ('Class', section.title),
          ('School Year', section.schoolYear),
          ('Days recorded', '${days.length}'),
          ('Learners', '${roster.length}'),
        ]),
        _table(
          const ['#', 'Learner', 'Days', 'Present', 'Late', 'Absent', 'Excused', 'Rate'],
          rows,
          widths: [22, 170, 40, 46, 36, 44, 48, 46],
          numericColumns: [0, 2, 3, 4, 5, 6, 7],
        ),
        _signature(data.teacherName),
      ],
    ),
  );
  return _finish(doc);
}

/* -------------------------------- report card ------------------------------ */

/// One learner's report card: every subject with its term grades and final
/// grade, the general average, attendance totals and BMI measurements.
Future<Uint8List> buildReportCardPdfBytes(
  BackupData data,
  Section section,
  Student student,
) async {
  final doc = _document('Report Card', data);
  final subjects = data.subjectsOf(section.id);

  final rows = <List<String>>[];
  final finals = <double>[];
  for (final subject in subjects) {
    final finalGrade = data.finalGradeOf(subject, student.id);
    if (finalGrade != null) finals.add(finalGrade);
        rows.add([
      subject.name,
      for (final term in terms)
        !subject.covers(term)
            ? '-'
            : _mark(data.gradeOf(subject, term, student.id).termGrade),
      finalGrade == null ? '-' : _mark(finalGrade),
      finalGrade == null ? '-' : gradeDescriptors(finalGrade),
    ]);
  }
  final general = finals.isEmpty
      ? null
      : finals.reduce((a, b) => a + b) / finals.length;
  final passed = finals.where((grade) => grade >= passingGrade).length;

  // Attendance of this learner in this class.
  var present = 0, late = 0, absent = 0, excused = 0, recorded = 0;
  for (final day in data.attendance.values) {
    if (day.sectionId != section.id) continue;
    final status = day.statuses[student.id];
    if (status == null) continue;
    recorded += 1;
    switch (status) {
      case AttendanceStatus.present:
        present += 1;
      case AttendanceStatus.late:
        late += 1;
      case AttendanceStatus.absent:
        absent += 1;
      case AttendanceStatus.excused:
        excused += 1;
    }
  }
  final rate = recorded == 0 ? null : (present + late) / recorded * 100;

  // BMI measurements, oldest first, screened at the learner's age on the
  // measurement date (the same reference the BMI screen uses).
  final measurements = data.bmi.values
      .where((record) => record.studentId == student.id)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final bmiRows = <List<String>>[];
  for (final record in measurements) {
    final bmi = computeBmi(record.heightCm, record.weightKg);
    final reading = interpretBmi(
      bmi,
      ageYears: student.ageAt(DateTime.tryParse(record.date)),
      sex: student.gender,
    );
    bmiRows.add([
      record.date,
      _num(record.heightCm, 1),
      _num(record.weightKg, 1),
      bmi == null ? '-' : _num(bmi, 1),
      reading?.category ?? '-',
    ]);
  }

  final age = student.ageAt();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 24),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: _soft),
        ),
      ),
      build: (context) => [
        _header('LEARNER REPORT CARD', [
          ('Learner', student.fullName),
          ('LRN', student.lrn.isEmpty ? '-' : student.lrn),
          // ASCII hyphen: the built-in PDF font cannot draw the em dash in
          // [Section.title], so the report card spells the class out.
          ('Class', '${section.gradeLevel} - ${section.section}'),
          ('School Year', section.schoolYear),
          ('Sex', student.gender.isEmpty ? '-' : student.gender),
          ('Age', age == null ? '-' : '$age'),
        ]),
        if (subjects.isEmpty)
          pw.Text(
            'No subjects have been added to this class yet.',
            style: const pw.TextStyle(fontSize: 9, color: _soft),
          )
        else
          _table(
            const ['Subject', 'T1', 'T2', 'T3', 'Final', 'Remarks'],
            rows,
            widths: [158, 42, 42, 42, 46, 156],
            numericColumns: [1, 2, 3, 4],
          ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _head,
            border: pw.Border.all(color: _navy, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'General average: ${general == null ? '-' : _num(general, 2)}',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
              pw.Text(
                general == null
                    ? 'No grades recorded yet'
                    : '${gradeDescriptors(general)}  |  '
                        'Passed $passed of ${finals.length} subjects',
                style: const pw.TextStyle(fontSize: 8.5, color: _ink),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Attendance',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 6),
        _table(
          const ['Days Recorded', 'Present', 'Late', 'Absent', 'Excused', 'Rate'],
          [
            [
              '$recorded',
              '$present',
              '$late',
              '$absent',
              '$excused',
              rate == null ? '-' : '${_num(rate, 1)}%',
            ],
          ],
          widths: [90, 70, 60, 65, 70, 70],
          numericColumns: [0, 1, 2, 3, 4, 5],
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'BMI Monitoring',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 6),
        _table(
          const ['Date', 'Height (cm)', 'Weight (kg)', 'BMI', 'Interpretation'],
          bmiRows,
          widths: [72, 78, 78, 60, 196],
          numericColumns: [1, 2, 3],
        ),
        if (bmiRows.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            "Screened against the WHO 2007 BMI-for-age reference using the "
            "learner's age and sex on each measurement date. Results are a "
            'screening aid, not a medical diagnosis.',
            style: const pw.TextStyle(fontSize: 7.5, color: _soft),
          ),
        ],
        _signature(data.teacherName),
      ],
    ),
  );
  return _finish(doc);
}

/* -------------------------------- printing -------------------------------- */

/// Opens the platform print dialog for [bytes].
Future<void> printPdfBytes(Uint8List bytes, {required String name}) async {
  await Printing.layoutPdf(
    name: name,
    onLayout: (format) async => bytes,
  );
}

/// Opens the share sheet with the PDF attached.
Future<void> sharePdfBytes(
  Uint8List bytes, {
  required String name,
  String? subject,
}) async {
  await Printing.sharePdf(bytes: bytes, filename: name);
}
