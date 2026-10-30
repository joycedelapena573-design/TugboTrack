/// Offline-first app state. The UI renders from this in-memory store, every
/// change is mirrored into the on-device SQLite database (see `data/database.dart`)
/// and every mutation schedules an automatic CSV backup.
library;

import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../models/models.dart';
import '../services/backup.dart';
import '../utils/format.dart';
import '../utils/ids.dart';

class AppState extends ChangeNotifier {
  AppState({DatabaseService? database}) : _db = database ?? DatabaseService.instance;

  final DatabaseService _db;

  bool hydrated = false;
  String teacherName = '';
  Map<String, Section> sections = {};
  Map<String, Student> students = {};
  Map<String, Subject> subjects = {};
  Map<String, ScoreSheet> sheets = {};
  ScoreMap scores = {};
  Map<String, AttendanceDay> attendance = {};
  Map<String, BmiRecord> bmi = {};
  String? activeSectionId;

  /// Teacher-chosen school logo file path; null = bundled default.
  String? schoolLogoUri;

  /* --------------------------------- loading -------------------------------- */

  /// Reads the SQLite database back into memory once at launch (importing
  /// anything the earlier build left on the device first). The splash screen
  /// waits on [hydrated], so no screen renders before this finishes.
  Future<void> load() async {
    try {
      await _db.migrateLegacyStorage();
      final data = await _db.loadAll();
      teacherName = data.teacherName;
      activeSectionId = data.activeSectionId;
      schoolLogoUri = data.schoolLogoUri;
      sections = data.sections;
      students = data.students;
      subjects = data.subjects;
      sheets = data.sheets;
      scores = data.scores;
      attendance = data.attendance;
      bmi = data.bmi;
    } catch (error) {
      // ignore: avoid_print
      print('[state] could not read the SQLite database: $error');
    }
    hydrated = true;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _scheduleBackup();
  }

  void _scheduleBackup() {
    scheduleAutoBackup(backupData());
  }

  /* -------------------------------- settings -------------------------------- */

  void setTeacherName(String name) {
    teacherName = name.trim();
    _db.saveSetting(SettingsKey.teacherName, teacherName);
    _changed();
  }

  void setActiveSection(String? id) {
    activeSectionId = id;
    _db.saveSetting(SettingsKey.activeSectionId, id);
    notifyListeners();
  }

  void setSchoolLogo(String? uri) {
    schoolLogoUri = uri;
    _db.saveSetting(SettingsKey.schoolLogoUri, uri);
    notifyListeners();
  }

  /* -------------------------------- sections -------------------------------- */

  Section addSection({
    required String gradeLevel,
    required String section,
    required String schoolYear,
  }) {
    final value = Section(
      id: newId(),
      gradeLevel: gradeLevel,
      section: section,
      schoolYear: schoolYear,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    sections[value.id] = value;
    activeSectionId = value.id;
    _db.putSection(value);
    _db.saveSetting(SettingsKey.activeSectionId, value.id);
    _changed();
    return value;
  }

  void updateSection(
    String id,
    {String? gradeLevel, String? section, String? schoolYear}) {
    final prev = sections[id];
    if (prev == null) return;
    sections[id] = prev.copyWith(
      gradeLevel: gradeLevel,
      section: section,
      schoolYear: schoolYear,
    );
    _db.putSection(sections[id]!);
    _changed();
  }

  void deleteSection(String id) {
    final removedStudentIds = students.values
        .where((s) => s.sectionId == id)
        .map((s) => s.id)
        .toSet();
    final removedSubjectIds = subjects.values
        .where((s) => s.sectionId == id)
        .map((s) => s.id)
        .toSet();

    sections.remove(id);
    students.removeWhere((_, s) => s.sectionId == id);
    subjects.removeWhere((_, s) => s.sectionId == id);
    sheets.removeWhere((_, sheet) => removedSubjectIds.contains(sheet.subjectId));
    scores.removeWhere((key, _) => removedSubjectIds.contains(key.split('|').first));
    final removedDays = attendance.values.where((d) => d.sectionId == id).toList();
    for (final day in removedDays) {
      attendance.remove(day.id);
      _db.removeAttendanceDay(day.id);
    }
    bmi.removeWhere((_, record) => removedStudentIds.contains(record.studentId));

    if (activeSectionId == id) activeSectionId = null;

    _db.removeSection(id);
    for (final studentId in removedStudentIds) {
      _db.removeStudent(studentId);
    }
    for (final subjectId in removedSubjectIds) {
      _db.removeSubject(subjectId);
    }
    for (final key in scores.keys.toList()) {
      if (removedSubjectIds.contains(key.split('|').first)) {
        _db.saveScore(key, null);
      }
    }
    for (final record in bmi.values) {
      _db.removeBmi(record.studentId, record.date);
    }
    _db.saveSetting(SettingsKey.activeSectionId, activeSectionId);
    _changed();
  }

  /* -------------------------------- students -------------------------------- */

  Student addStudent(Student draft) {
    final value = Student(
      id: newId(),
      sectionId: draft.sectionId,
      seatNumber: draft.seatNumber,
      fullName: draft.fullName,
      lrn: draft.lrn,
      gender: draft.gender,
      birthday: draft.birthday,
      guardianName: draft.guardianName,
      guardianContact: draft.guardianContact,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    students[value.id] = value;
    _db.putStudent(value);
    _changed();
    return value;
  }

  /// Bulk import: keeps requested seat numbers when free, otherwise assigns
  /// the next free seat in the section.
  int bulkAddStudents(List<Student> drafts) {
    if (drafts.isEmpty) return 0;
    final taken = <String>{
      for (final s in students.values) '${s.sectionId}#${s.seatNumber}',
    };
    var now = DateTime.now().millisecondsSinceEpoch;
    var added = 0;
    for (final draft in drafts) {
      var seat = draft.seatNumber;
      while (seat > 0 && taken.contains('${draft.sectionId}#$seat')) {
        seat += 1;
      }
      final finalSeat = seat > 0 ? seat : nextSeat(draft.sectionId);
      final value = Student(
        id: newId(),
        sectionId: draft.sectionId,
        seatNumber: finalSeat,
        fullName: draft.fullName,
        lrn: draft.lrn,
        gender: draft.gender,
        birthday: draft.birthday,
        guardianName: draft.guardianName,
        guardianContact: draft.guardianContact,
        createdAt: now + added,
      );
      taken.add('${value.sectionId}#$finalSeat');
      students[value.id] = value;
      _db.putStudent(value);
      added += 1;
    }
    _changed();
    return added;
  }

  void updateStudent(
    String id, {
    int? seatNumber,
    String? fullName,
    String? lrn,
    String? gender,
    String? birthday,
    String? guardianName,
    String? guardianContact,
  }) {
    final prev = students[id];
    if (prev == null) return;
    var nextBirthday = prev.birthday;
    if (birthday != null) {
      nextBirthday = normalizeBirthday(birthday) ?? prev.birthday;
    }
    students[id] = Student(
      id: prev.id,
      sectionId: prev.sectionId,
      seatNumber: seatNumber ?? prev.seatNumber,
      fullName: fullName ?? prev.fullName,
      lrn: lrn ?? prev.lrn,
      gender: gender ?? prev.gender,
      birthday: nextBirthday,
      guardianName: guardianName ?? prev.guardianName,
      guardianContact: guardianContact ?? prev.guardianContact,
      createdAt: prev.createdAt,
    );
    _db.putStudent(students[id]!);
    _changed();
  }

  void deleteStudent(String id) {
    students.remove(id);
    scores.removeWhere((key, _) => key.contains('|$id|'));
    for (final entry in attendance.entries.toList()) {
      if (!entry.value.statuses.containsKey(id)) continue;
      final statuses = Map<String, AttendanceStatus>.from(entry.value.statuses)
        ..remove(id);
      final updated = entry.value.copyWith(
        statuses: statuses,
        markedAt: DateTime.now().millisecondsSinceEpoch,
      );
      attendance[entry.key] = updated;
      _db.putAttendanceDay(updated);
    }
    final removedBmi = bmi.values.where((r) => r.studentId == id).toList();
    for (final record in removedBmi) {
      bmi.remove(record.id);
    }

    _db.removeStudent(id);
    for (final key in scores.keys.toList()) {
      if (key.contains('|$id|')) _db.saveScore(key, null);
    }
    for (final record in removedBmi) {
      _db.removeBmi(record.studentId, record.date);
    }
    _changed();
  }

  /// Next free seat number in a section (1-based).
  int nextSeat(String sectionId) {
    final seats = students.values
        .where((s) => s.sectionId == sectionId)
        .map((s) => s.seatNumber);
    return seats.isEmpty ? 1 : seats.reduce(mathMax) + 1;
  }

  /* -------------------------------- subjects -------------------------------- */

  Subject addSubject({
    required String sectionId,
    required String name,
    required String teacherName,
    Weights? weights,
    bool transmute = false,
  }) {
    final value = Subject(
      id: newId(),
      sectionId: sectionId,
      name: name.trim(),
      teacherName: teacherName.trim(),
      weights: weights ?? Map<ComponentKey, double>.from(defaultWeights),
      transmute: transmute,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    subjects[value.id] = value;
    _db.putSubject(value);
    _changed();
    return value;
  }

  void updateSubject(
    String id, {
    String? name,
    String? teacherName,
    Weights? weights,
    bool? transmute,
  }) {
    final prev = subjects[id];
    if (prev == null) return;
    subjects[id] = prev.copyWith(
      name: name,
      teacherName: teacherName,
      weights: weights,
      transmute: transmute,
    );
    _db.putSubject(subjects[id]!);
    _changed();
  }

  void deleteSubject(String id) {
    subjects.remove(id);
    final removedSheetIds =
        sheets.values.where((s) => s.subjectId == id).map((s) => s.id).toSet();
    sheets.removeWhere((_, sheet) => sheet.subjectId == id);
    scores.removeWhere((key, _) => removedSheetIds.contains(key.split('|').first));

    _db.removeSubject(id);
    for (final sheetId in removedSheetIds) {
      _db.removeSheet(sheetId);
      for (final key in scores.keys.toList()) {
        if (key.startsWith('$sheetId|')) _db.saveScore(key, null);
      }
    }
    _changed();
  }

  /* ------------------------------- score sheets ----------------------------- */

  String sheetIdOf(String subjectId, int quarter) => '$subjectId::q$quarter';

  ScoreSheet ensureSheet(String subjectId, int quarter) {
    final id = sheetIdOf(subjectId, quarter);
    final existing = sheets[id];
    if (existing != null) return existing;
    final value = ScoreSheet(
      id: id,
      subjectId: subjectId,
      quarter: quarter,
      items: {
        for (final component in ComponentKey.values) component: <AssessmentItem>[],
      },
    );
    sheets[id] = value;
    _db.putSheet(value);
    return value;
  }

  void addItem(
    String subjectId,
    int quarter,
    ComponentKey component,
    String title,
    double max,
  ) {
    final sheet = ensureSheet(subjectId, quarter);
    final items = List<AssessmentItem>.from(sheet.items[component] ?? const [])
      ..add(AssessmentItem(
        id: newId(),
        title: title.trim(),
        max: max > 0 ? max : 100,
      ));
    sheets[sheet.id] = sheet.copyWith(items: {
      ...sheet.items,
      component: items,
    });
    _db.putSheet(sheets[sheet.id]!);
    _changed();
  }

  void updateItem(
    String subjectId,
    int quarter,
    ComponentKey component,
    String itemId, {
    String? title,
    double? max,
  }) {
    final id = sheetIdOf(subjectId, quarter);
    final sheet = sheets[id];
    if (sheet == null) return;
    final items = (sheet.items[component] ?? const <AssessmentItem>[])
        .map((item) => item.id == itemId
            ? item.copyWith(
                title: title,
                max: (max != null && max > 0) ? max : null,
              )
            : item)
        .toList();
    sheets[id] = sheet.copyWith(items: {...sheet.items, component: items});
    _db.putSheet(sheets[id]!);
    _changed();
  }

  void deleteItem(
    String subjectId,
    int quarter,
    ComponentKey component,
    String itemId,
  ) {
    final id = sheetIdOf(subjectId, quarter);
    final sheet = sheets[id];
    if (sheet == null) return;
    final items = (sheet.items[component] ?? const <AssessmentItem>[])
        .where((item) => item.id != itemId)
        .toList();
    sheets[id] = sheet.copyWith(items: {...sheet.items, component: items});

    final prefix = '$id|';
    final removedKeys = scores.keys
        .where((key) => key.startsWith(prefix) && key.endsWith('|$itemId'))
        .toList();
    for (final key in removedKeys) {
      scores.remove(key);
      _db.saveScore(key, null);
    }

    _db.putSheet(sheets[id]!);
    _changed();
  }

  void setScore(String sheetId, String studentId, String itemId, double? value) {
    final key = '$sheetId|$studentId|$itemId';
    if (value == null || value.isNaN) {
      scores.remove(key);
    } else {
      scores[key] = value;
    }
    _db.saveScore(key, value);
    _changed();
  }

  /* -------------------------------- attendance ------------------------------- */

  void setAttendance(
    String sectionId,
    String date,
    String studentId,
    AttendanceStatus status,
  ) {
    final id = '$sectionId::$date';
    final day = attendance[id] ??
        AttendanceDay(
          id: id,
          sectionId: sectionId,
          date: date,
          statuses: {},
          markedAt: 0,
        );
    final updated = day.copyWith(
      statuses: {...day.statuses, studentId: status},
      markedAt: DateTime.now().millisecondsSinceEpoch,
    );
    attendance[id] = updated;
    _db.putAttendanceDay(updated);
    _changed();
  }

  void clearAttendanceSeat(String sectionId, String date, String studentId) {
    final id = '$sectionId::$date';
    final day = attendance[id];
    if (day == null || !day.statuses.containsKey(studentId)) return;
    final statuses = Map<String, AttendanceStatus>.from(day.statuses)
      ..remove(studentId);
    final updated = day.copyWith(
      statuses: statuses,
      markedAt: DateTime.now().millisecondsSinceEpoch,
    );
    attendance[id] = updated;
    _db.putAttendanceDay(updated);
    _changed();
  }

  void markAllAttendance(
    String sectionId,
    String date,
    AttendanceStatus status,
  ) {
    final id = '$sectionId::$date';
    final statuses = <String, AttendanceStatus>{
      for (final s in students.values)
        if (s.sectionId == sectionId) s.id: status,
    };
    final day = AttendanceDay(
      id: id,
      sectionId: sectionId,
      date: date,
      statuses: statuses,
      markedAt: DateTime.now().millisecondsSinceEpoch,
    );
    attendance[id] = day;
    _db.putAttendanceDay(day);
    _changed();
  }

  void clearAttendanceDay(String sectionId, String date) {
    final id = '$sectionId::$date';
    if (attendance.remove(id) == null) return;
    _db.removeAttendanceDay(id);
    _changed();
  }

  /* ----------------------------------- BMI ---------------------------------- */

  void setBmi(String studentId, String date, double heightCm, double weightKg) {
    final id = '$studentId::$date';
    final value = BmiRecord(
      id: id,
      studentId: studentId,
      date: date,
      heightCm: heightCm,
      weightKg: weightKg,
      recordedAt: DateTime.now().millisecondsSinceEpoch,
    );
    bmi[id] = value;
    _db.putBmi(value);
    _changed();
  }

  void deleteBmi(String recordId) {
    final record = bmi.remove(recordId);
    if (record == null) return;
    _db.removeBmi(record.studentId, record.date);
    _changed();
  }

  /* -------------------------------- selectors -------------------------------- */

  List<Student> studentsOf(String? sectionId) {
    if (sectionId == null) return const [];
    final list = students.values.where((s) => s.sectionId == sectionId).toList()
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    return list;
  }

  List<Subject> subjectsOf(String? sectionId) {
    if (sectionId == null) return const [];
    final list = subjects.values.where((s) => s.sectionId == sectionId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Section? section(String? id) => id == null ? null : sections[id];

  Student? student(String? id) => id == null ? null : students[id];

  Subject? subject(String? id) => id == null ? null : subjects[id];

  /// Latest BMI record for a student (most recent first).
  BmiRecord? latestBmi(String studentId) {
    BmiRecord? best;
    for (final record in bmi.values) {
      if (record.studentId != studentId) continue;
      if (best == null ||
          record.recordedAt > best.recordedAt ||
          (record.recordedAt == best.recordedAt && record.date.compareTo(best.date) > 0)) {
        best = record;
      }
    }
    return best;
  }

  /// BMI records for one student, newest first.
  List<BmiRecord> bmiHistory(String studentId) {
    final list = bmi.values.where((r) => r.studentId == studentId).toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.recordedAt.compareTo(a.recordedAt);
      });
    return list;
  }

  /// Full CSV snapshot for exports.
  BackupData backupData() => BackupData(
        teacherName: teacherName,
        sections: sections,
        students: students,
        subjects: subjects,
        sheets: sheets,
        scores: scores,
        attendance: attendance,
        bmi: bmi,
      );
}

int mathMax(int a, int b) => a > b ? a : b;
