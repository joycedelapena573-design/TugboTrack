/// Automatic CSV backups and export helpers.
///
/// The app keeps an automatic CSV snapshot of the class records on the device
/// after every save, plus on-demand full exports. The SQLite database remains
/// the source of truth; these files exist so a teacher can open their records
/// in a spreadsheet or recover them by hand.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'grading.dart';

/// Everything a report or export needs, taken from [AppState.backupData].
class BackupData {
  const BackupData({
    required this.teacherName,
    required this.sections,
    required this.students,
    required this.subjects,
    required this.sheets,
    required this.scores,
    required this.attendance,
    required this.bmi,
    this.activeSchoolYear,
    this.activeTerm = 1,
  });

  final String teacherName;
  final Map<String, Section> sections;
  final Map<String, Student> students;
  final Map<String, Subject> subjects;
  final Map<String, ScoreSheet> sheets;
  final ScoreMap scores;
  final Map<String, AttendanceDay> attendance;
  final Map<String, BmiRecord> bmi;
  final String? activeSchoolYear;
  final int activeTerm;

  Section? section(String id) => sections[id];

  List<Student> rosterOf(String sectionId, {bool includeArchived = false}) {
    final list = students.values
        .where((student) =>
            student.sectionId == sectionId &&
            (includeArchived || !student.archived))
        .toList()
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    return list;
  }

  List<Subject> subjectsOf(String sectionId) {
    final list = subjects.values
        .where((subject) => subject.sectionId == sectionId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  ScoreSheet? sheetOf(String subjectId, int term) => sheets['$subjectId::t$term'];

  TermGradeResult gradeOf(Subject subject, int term, String studentId) {
    return computeTermGrade(
      subject.weights,
      subject.transmute,
      sheetOf(subject.id, term),
      scores,
      studentId,
    );
  }

  double? finalGradeOf(Subject subject, String studentId) {
    final values = [
      for (final term in subject.activeTerms)
        gradeOf(subject, term, studentId).termGrade,
    ];
    return computeFinalGrade(values);
  }
}

/* ---------------------------------- CSV ----------------------------------- */

/// Escapes a value for CSV output.
String csvCell(Object? value) {
  final text = value == null ? '' : '$value';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String _csvRow(List<Object?> cells) => cells.map(csvCell).join(',');

/// Class record of one subject and term: one row per learner with the per
/// category percentages, initial grade, term grade and descriptor.
String buildClassRecordCsv(
  BackupData data,
  Section section,
  Subject subject,
  int term,
) {
  final buffer = StringBuffer();
  final info = [
    'Subject: ${subject.name}',
    'Class: ${section.title}',
    'School Year: ${section.schoolYear}',
    'Term: $term',
    'Teacher: ${subject.teacherName.isEmpty ? data.teacherName : subject.teacherName}',
  ];
  for (final line in info) {
    buffer.writeln(_csvRow([line]));
  }
  buffer.writeln();
  buffer.writeln(_csvRow([
    'Seat',
    'Student',
    'LRN',
    'WW %',
    'PT %',
    'TE %',
    'Initial Grade',
    'Term Grade',
    'Descriptor',
  ]));
  for (final student in data.rosterOf(section.id)) {
    final result = data.gradeOf(subject, term, student.id);
    String pct(AssessmentCategory category) {
      final value = result.components[category]?.percentage;
      return value == null ? '' : roundTo(value, 2).toString();
    }

    buffer.writeln(_csvRow([
      student.seatNumber,
      student.fullName,
      student.lrn,
      pct(AssessmentCategory.writtenWorks),
      pct(AssessmentCategory.performanceTasks),
      pct(AssessmentCategory.termExam),
      result.initialGrade == null ? '' : roundTo(result.initialGrade!, 2),
      result.termGrade == null ? '' : reportGrade(result.termGrade!),
      gradeDescriptors(result.termGrade),
    ]));
  }
  return buffer.toString();
}

/// Final grades of a class: every subject × learner.
String buildFinalGradesCsv(BackupData data, Section section) {
  final subjects = data.subjectsOf(section.id);
  final buffer = StringBuffer()
    ..writeln(_csvRow(['Final Grades — ${section.title} — SY ${section.schoolYear}']))
    ..writeln();
  buffer.writeln(_csvRow([
    'Seat',
    'Student',
    'LRN',
    for (final subject in subjects) subject.name,
  ]));
  for (final student in data.rosterOf(section.id)) {
    buffer.writeln(_csvRow([
      student.seatNumber,
      student.fullName,
      student.lrn,
      for (final subject in subjects)
        data.finalGradeOf(subject, student.id) == null
            ? ''
            : reportGrade(data.finalGradeOf(subject, student.id)!),
    ]));
  }
  return buffer.toString();
}

/// Attendance summary per learner for a class.
String buildAttendanceCsv(BackupData data, Section section) {
  final days = data.attendance.values
      .where((day) => day.sectionId == section.id)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final buffer = StringBuffer()
    ..writeln(_csvRow(['Attendance — ${section.title} — SY ${section.schoolYear}']))
    ..writeln();
  buffer.writeln(_csvRow([
    'Seat',
    'Student',
    'Days Recorded',
    'Present',
    'Late',
    'Absent',
    'Excused',
    'Attendance %',
  ]));
  for (final student in data.rosterOf(section.id)) {
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
    final rate = recorded == 0 ? 0.0 : (present + late) / recorded * 100;
    buffer.writeln(_csvRow([
      student.seatNumber,
      student.fullName,
      recorded,
      present,
      late,
      absent,
      excused,
      roundTo(rate, 1),
    ]));
  }
  return buffer.toString();
}

/// Every record the app holds, flattened into one CSV for a manual restore.
String buildFullBackupCsv(BackupData data) {
  final buffer = StringBuffer()
    ..writeln('# TugboTrack full backup')
    ..writeln(_csvRow(['record', 'key', 'field', 'value']));

  void record(String type, String key, Map<String, Object?> fields) {
    fields.forEach((field, value) {
      buffer.writeln(_csvRow([type, key, field, value]));
    });
  }

  if (data.teacherName.isNotEmpty) {
    record('teacher', 'local', {'name': data.teacherName});
  }
  for (final section in data.sections.values) {
    record('class', section.id, {
      'gradeLevel': section.gradeLevel,
      'section': section.section,
      'schoolYear': section.schoolYear,
      'curriculum': section.curriculum.label,
      'archived': section.archived,
    });
  }
  for (final student in data.students.values) {
    record('student', student.id, {
      'class': student.sectionId,
      'seat': student.seatNumber,
      'name': student.fullName,
      'lrn': student.lrn,
      'gender': student.gender,
      'birthday': student.birthday,
      'guardian': student.guardianName,
      'contact': student.guardianContact,
    });
  }
  for (final subject in data.subjects.values) {
    record('subject', subject.id, {
      'class': subject.sectionId,
      'name': subject.name,
      'terms': '${subject.termStart}-${subject.termEnd}',
      'weights': [
        for (final category in AssessmentCategory.values)
          '${category.short} ${subject.weights[category] ?? 0}',
      ].join('/'),
      'transmute': subject.transmute,
    });
  }
  for (final sheet in data.sheets.values) {
    for (final category in AssessmentCategory.values) {
      for (final item in sheet.itemsOf(category)) {
        record('assessment', item.id, {
          'subject': sheet.subjectId,
          'term': sheet.term,
          'category': category.short,
          'title': item.title,
          'max': item.max,
        });
      }
    }
  }
  data.scores.forEach((key, value) {
    record('score', key, {'value': value});
  });
  for (final day in data.attendance.values) {
    day.statuses.forEach((studentId, status) {
      record('attendance', '${day.sectionId}|${day.date}|$studentId', {
        'status': status.name,
      });
    });
  }
  for (final record0 in data.bmi.values) {
    record('bmi', record0.id, {
      'height': record0.heightCm,
      'weight': record0.weightKg,
      'recordedAt': record0.recordedAt,
    });
  }
  return buffer.toString();
}

/* --------------------------------- files ---------------------------------- */

/// Folder the automatic backups are written to.
Future<String> autoBackupDirPath() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'TugboTrack', 'backups'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir.path;
}

/// Writes the CSV snapshots (one per class + subject + term).
Future<void> writeAutoBackups(BackupData data) async {
  try {
    final dir = await autoBackupDirPath();
    final stamp = DateTime.now();
    final file = File(
      p.join(
        dir,
        'classtrack-${stamp.year}${_two(stamp.month)}${_two(stamp.day)}.csv',
      ),
    );
    final buffer = StringBuffer()..writeln(buildFullBackupCsv(data));
    for (final section in data.sections.values) {
      buffer
        ..writeln()
        ..writeln('# Class record — ${section.title}')
        ..writeln(buildAttendanceCsv(data, section))
        ..writeln(buildFinalGradesCsv(data, section));
      for (final subject in data.subjectsOf(section.id)) {
        for (final term in subject.activeTerms) {
          buffer.writeln(buildClassRecordCsv(data, section, subject, term));
        }
      }
    }
    await file.writeAsString(buffer.toString(), flush: true);
  } catch (error) {
    // ignore: avoid_print
    print('[backup] automatic CSV backup failed: $error');
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

Timer? _autoBackupTimer;

/// Debounced automatic backup: a burst of score entries writes one file.
void scheduleAutoBackup(BackupData data) {
  _autoBackupTimer?.cancel();
  _autoBackupTimer = Timer(const Duration(seconds: 3), () {
    unawaited(writeAutoBackups(data));
  });
}

/// Writes [contents] to the exports folder and returns the file path.
Future<String> exportCsvFile(String fileName, String contents) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'TugboTrack', 'exports'));
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File(p.join(dir.path, fileName));
  await file.writeAsString(contents, flush: true);
  return file.path;
}

/// Full CSV export, ready to share.
Future<String> exportFullBackupCsv(BackupData data) async {
  final stamp = DateTime.now();
  final name =
      'tugbotrack-backup-${stamp.year}${_two(stamp.month)}${_two(stamp.day)}-${_two(stamp.hour)}${_two(stamp.minute)}.csv';
  return exportCsvFile(name, buildFullBackupCsv(data));
}

/// Opens the platform share sheet for a file on disk.
Future<void> shareFile(String path, {String? title, Rect? origin}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      title: title,
      subject: title,
      // iPad presents the share sheet as a popover anchored to a rectangle.
      sharePositionOrigin: origin,
    ),
  );
}

/// Opens the platform share sheet for several files at once.
Future<void> shareFiles(
  List<String> paths, {
  String? title,
  Rect? origin,
}) async {
  if (paths.isEmpty) return;
  await SharePlus.instance.share(
    ShareParams(
      files: [for (final path in paths) XFile(path)],
      title: title,
      subject: title,
      sharePositionOrigin: origin,
    ),
  );
}

/* --------------------------- whole school year ---------------------------- */

/// One CSV per class (roster, attendance, final grades, every class record)
/// written to the exports folder. Returns the file paths, newest first.
Future<List<String>> exportSchoolYear(
  BackupData data,
  String schoolYear,
) async {
  final paths = <String>[];
  final classes = data.sections.values
      .where((section) => section.schoolYear == schoolYear)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (final section in classes) {
    final buffer = StringBuffer()
      ..writeln(buildFinalGradesCsv(data, section))
      ..writeln()
      ..writeln(buildAttendanceCsv(data, section));
    for (final subject in data.subjectsOf(section.id)) {
      for (final term in subject.activeTerms) {
        buffer
          ..writeln()
          ..writeln(buildClassRecordCsv(data, section, subject, term));
      }
    }
    final slug = _slug('${section.gradeLevel}-${section.section}');
    paths.add(
      await exportCsvFile('$schoolYear-$slug.csv', buffer.toString()),
    );
  }

  paths.add(await exportCsvFile(
    '$schoolYear-full-backup.csv',
    buildFullBackupCsv(data),
  ));
  return paths;
}

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/* ------------------------------- auto backup ------------------------------ */

/// Directory holding the rolling automatic database copies.
Future<String> databaseBackupDirPath() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'TugboTrack', 'database-backups'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir.path;
}

/// Timestamp used in automatic backup file names.
String backupStamp([DateTime? now]) {
  final stamp = now ?? DateTime.now();
  return '${stamp.year}${_two(stamp.month)}${_two(stamp.day)}'
      '-${_two(stamp.hour)}${_two(stamp.minute)}';
}

/// Deletes the oldest `.db` backups, keeping [keep] of them.
/// Returns the number of files removed.
Future<int> pruneDatabaseBackups({int keep = 7}) async {
  try {
    final dir = Directory(await databaseBackupDirPath());
    if (!await dir.exists()) return 0;
    final files = await dir
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.db'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    var removed = 0;
    for (final file in files.skip(keep)) {
      await file.delete();
      removed += 1;
    }
    return removed;
  } catch (error) {
    // ignore: avoid_print
    print('[backup] could not prune old backups: $error');
    return 0;
  }
}

/// Newest automatic database backup, or null when none exists yet.
Future<File?> latestDatabaseBackup() async {
  try {
    final dir = Directory(await databaseBackupDirPath());
    if (!await dir.exists()) return null;
    final files = await dir
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.db'))
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.path.compareTo(a.path));
    return files.first;
  } catch (_) {
    return null;
  }
}
