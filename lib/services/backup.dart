/// CSV backups. Every save/change in the app schedules an automatic local CSV
/// backup (requirement 4.4); teachers can also export a shareable backup.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../utils/format.dart';
import 'csv.dart';

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
  });

  final String teacherName;
  final Map<String, Section> sections;
  final Map<String, Student> students;
  final Map<String, Subject> subjects;
  final Map<String, ScoreSheet> sheets;
  final ScoreMap scores;
  final Map<String, AttendanceDay> attendance;
  final Map<String, BmiRecord> bmi;
}

const String _autoDir = 'auto-backups';

List<Student> _sortedStudents(BackupData data) {
  final list = data.students.values.toList()
    ..sort((a, b) {
      final bySection = a.sectionId.compareTo(b.sectionId);
      if (bySection != 0) return bySection;
      return a.seatNumber.compareTo(b.seatNumber);
    });
  return list;
}

List<Student> _studentsOfSection(BackupData data, String sectionId) {
  final list = data.students.values.where((s) => s.sectionId == sectionId).toList()
    ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
  return list;
}

String buildStudentsCsv(BackupData data) {
  final rows = <List<Object?>>[
    const [
      'Seat', 'Name', 'LRN', 'Gender', 'Birthday', 'Age', 'Guardian',
      'Contact', 'Grade Level', 'Section', 'School Year',
    ],
  ];
  for (final s in _sortedStudents(data)) {
    final sec = data.sections[s.sectionId];
    rows.add([
      s.seatNumber,
      s.fullName,
      s.lrn,
      s.gender,
      s.birthday,
      ageFromBirthday(s.birthday) ?? '',
      s.guardianName,
      s.guardianContact,
      sec?.gradeLevel ?? '',
      sec?.section ?? '',
      sec?.schoolYear ?? '',
    ]);
  }
  return toCsv(rows);
}

String buildGradesCsv(BackupData data) {
  final rows = <List<Object?>>[
    const [
      'Grade Level', 'Section', 'School Year', 'Subject', 'Quarter',
      'Student', 'Component', 'Item', 'Score', 'Highest',
    ],
  ];
  for (final sheet in data.sheets.values) {
    final subject = data.subjects[sheet.subjectId];
    if (subject == null) continue;
    final section = data.sections[subject.sectionId];
    for (final component in ComponentKey.values) {
      for (final item in sheet.items[component] ?? const <AssessmentItem>[]) {
        for (final st in _studentsOfSection(data, subject.sectionId)) {
          final score = data.scores[scoreKeyOf(sheet.id, st.id, item.id)];
          if (score == null) continue;
          rows.add([
            section?.gradeLevel ?? '',
            section?.section ?? '',
            section?.schoolYear ?? '',
            subject.name,
            'Q${sheet.quarter}',
            st.fullName,
            component.label,
            item.title,
            score,
            item.max,
          ]);
        }
      }
    }
  }
  return toCsv(rows);
}

String buildAttendanceCsv(BackupData data) {
  final rows = <List<Object?>>[
    const ['Date', 'Grade Level', 'Section', 'School Year', 'Seat', 'Student', 'Status'],
  ];
  final days = data.attendance.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final day in days) {
    final section = data.sections[day.sectionId];
    for (final st in _studentsOfSection(data, day.sectionId)) {
      final status = day.statuses[st.id];
      rows.add([
        day.date,
        section?.gradeLevel ?? '',
        section?.section ?? '',
        section?.schoolYear ?? '',
        st.seatNumber,
        st.fullName,
        status?.name ?? '',
      ]);
    }
  }
  return toCsv(rows);
}

String buildBmiCsv(BackupData data) {
  final rows = <List<Object?>>[
    const ['Date', 'Student', 'Height (cm)', 'Weight (kg)', 'BMI'],
  ];
  final records = data.bmi.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final r in records) {
    final st = data.students[r.studentId];
    final bmi = r.heightCm > 0 ? r.weightKg / _squaredCm(r.heightCm) : null;
    rows.add([
      r.date,
      st?.fullName ?? '',
      r.heightCm,
      r.weightKg,
      bmi == null ? '' : bmi.toStringAsFixed(1),
    ]);
  }
  return toCsv(rows);
}

/// Full machine-readable backup (one row per record type, importable in
/// spreadsheets).
String buildFullBackupCsv(BackupData data) {
  final rows = <List<Object?>>[
    const ['record_type', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9'],
  ];
  rows.add([
    'meta', 'TIS ClassTrack backup',
    formatShortDate(todayIso()), data.teacherName,
  ]);
  for (final sec in data.sections.values) {
    rows.add(['section', sec.id, sec.gradeLevel, sec.section, sec.schoolYear]);
  }
  for (final st in data.students.values) {
    rows.add([
      'student', st.id, st.sectionId, st.seatNumber, st.fullName, st.lrn,
      st.gender, st.birthday, st.guardianName, st.guardianContact,
    ]);
  }
  for (final sub in data.subjects.values) {
    final w = sub.weights;
    rows.add([
      'subject', sub.id, sub.sectionId, sub.name, sub.teacherName,
      '${_w(w, ComponentKey.quizzes)}/${_w(w, ComponentKey.assignments)}/${_w(w, ComponentKey.activities)}/${_w(w, ComponentKey.performanceTasks)}/${_w(w, ComponentKey.examinations)}',
      sub.transmute ? 'transmute' : 'raw',
    ]);
  }
  for (final sheet in data.sheets.values) {
    for (final component in ComponentKey.values) {
      for (final item in sheet.items[component] ?? const <AssessmentItem>[]) {
        rows.add([
          'item', sheet.id, sheet.subjectId, 'Q${sheet.quarter}',
          component.name, item.id, item.title, item.max,
        ]);
      }
    }
  }
  data.scores.forEach((key, score) {
    rows.add(['score', key, score]);
  });
  for (final day in data.attendance.values) {
    day.statuses.forEach((studentId, status) {
      rows.add(['attendance', day.sectionId, day.date, studentId, status.name]);
    });
  }
  for (final r in data.bmi.values) {
    rows.add(['bmi', r.studentId, r.date, r.heightCm, r.weightKg]);
  }
  return toCsv(rows);
}

double _w(Weights weights, ComponentKey key) => weights[key] ?? 0;

double _squaredCm(double heightCm) {
  final m = heightCm / 100;
  return m * m;
}

/// Same key format the scoring engine uses.
String scoreKeyOf(String sheetId, String studentId, String itemId) =>
    '$sheetId|$studentId|$itemId';

Future<Directory> _autoBackupDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, _autoDir));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Write the rolling on-device CSV backup set (called on every app save).
Future<void> writeAutoBackups(BackupData data) async {
  final dir = await _autoBackupDir();
  final files = <String, String>{
    'students.csv': buildStudentsCsv(data),
    'grades.csv': buildGradesCsv(data),
    'attendance.csv': buildAttendanceCsv(data),
    'bmi.csv': buildBmiCsv(data),
    'full-backup.csv': buildFullBackupCsv(data),
  };
  for (final entry in files.entries) {
    await File(p.join(dir.path, entry.key))
        .writeAsString(entry.value, flush: true);
  }
}

Timer? _backupTimer;
DateTime? _lastRunAt;

/// Debounced auto-backup so rapid edits (typing scores) batch into one write.
void scheduleAutoBackup(BackupData data) {
  _backupTimer?.cancel();
  final sinceLast = _lastRunAt == null
      ? 0
      : DateTime.now().difference(_lastRunAt!).inMilliseconds;
  final delay = math.max(400, 1200 - sinceLast);
  _backupTimer = Timer(Duration(milliseconds: delay), () async {
    _backupTimer = null;
    try {
      await writeAutoBackups(data);
      _lastRunAt = DateTime.now();
    } catch (err) {
      // ignore: avoid_print
      print('Auto-backup failed: $err');
    }
  });
}

Future<String> autoBackupDirPath() async => (await _autoBackupDir()).path;

/// Write a timestamped full backup and return its path for sharing/saving.
Future<String> exportFullBackupCsv(BackupData data) async {
  final stamp = DateTime.now()
      .toIso8601String()
      .substring(0, 16)
      .replaceAll(RegExp(r'[-:T]'), '');
  return exportCsvFile('classtrack-backup-$stamp', buildFullBackupCsv(data));
}

/// Write an arbitrary CSV (e.g. a class record sheet) and return its path.
Future<String> exportCsvFile(String name, String csv) async {
  final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9-_]+'), '_');
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, '$safe.csv'));
  await file.writeAsString(csv, flush: true);
  return file.path;
}
