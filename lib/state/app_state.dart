/// Offline-first app state. The UI renders from this in-memory store, every
/// change is mirrored into the on-device SQLite database (see
/// `data/database.dart`) and every mutation schedules an automatic CSV backup.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../models/models.dart';
import '../services/backup.dart';
import '../services/grading.dart';
import '../utils/format.dart';
import '../utils/ids.dart';

class AppState extends ChangeNotifier {
  AppState({DatabaseService? database})
      : _db = database ?? DatabaseService.instance;

  final DatabaseService _db;

  bool hydrated = false;
  String teacherName = '';
  String? activeSectionId;
  int activeTerm = 1;
  String? activeSchoolYear;

  Map<String, Section> sections = {};
  Map<String, Student> students = {};
  Map<String, Subject> subjects = {};
  Map<String, ScoreSheet> sheets = {};
  ScoreMap scores = {};
  Map<String, AttendanceDay> attendance = {};
  Map<String, BmiRecord> bmi = {};
  Map<String, GradingConfig> gradingConfigs = {};
  Map<String, SchoolYear> schoolYears = {};
  List<AcademicTerm> academicTerms = [];
  Map<String, TermGradeRecord> termGrades = {};
  Map<String, FinalGradeRecord> finalGrades = {};

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
      activeTerm = data.activeTerm.clamp(1, 3);
      activeSchoolYear = data.activeSchoolYear;
      schoolLogoUri = data.schoolLogoUri;
      sections = data.sections;
      students = data.students;
      subjects = data.subjects;
      sheets = data.sheets;
      scores = data.scores;
      attendance = data.attendance;
      bmi = data.bmi;
      gradingConfigs = data.gradingConfigs;
      schoolYears = data.schoolYears;
      academicTerms = data.academicTerms;
      termGrades = data.termGrades;
      finalGrades = data.finalGrades;

      // Seed the built-in presets in memory as well, so a fresh install shows
      // them even before the first settings change is written.
      for (final config in builtInGradingConfigs) {
        gradingConfigs.putIfAbsent(config.id, () => config);
      }
      activeSchoolYear ??= currentSchoolYear();
      if (sections.isEmpty && activeSectionId != null) activeSectionId = null;
      if (activeSectionId != null && !sections.containsKey(activeSectionId)) {
        activeSectionId = null;
      }
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
    _db.saveTeacherName(teacherName);
    _changed();
  }

  void setActiveSection(String? id) {
    activeSectionId = id;
    _db.saveSetting(SettingsKey.activeSectionId, id);
    notifyListeners();
  }

  void setActiveTerm(int term) {
    activeTerm = term.clamp(1, 3);
    _db.saveSetting(SettingsKey.activeTerm, '$activeTerm');
    notifyListeners();
  }

  void setActiveSchoolYear(String year) {
    activeSchoolYear = year;
    _db.saveSetting(SettingsKey.activeSchoolYear, year);
    notifyListeners();
  }

  void setSchoolLogo(String? uri) {
    schoolLogoUri = uri;
    _db.saveSetting(SettingsKey.schoolLogoUri, uri);
    notifyListeners();
  }

  /* ------------------------------ school calendar --------------------------- */

  List<String> get schoolYearNames {
    final names = schoolYears.values.map((year) => year.name).toList()..sort();
    if (names.isEmpty) names.add(currentSchoolYear());
    return names.reversed.toList();
  }

  List<AcademicTerm> termsOf(String? schoolYear) {
    final year = schoolYear ?? activeSchoolYear ?? currentSchoolYear();
    return academicTerms.where((term) => term.schoolYear == year).toList()
      ..sort((a, b) => a.term.compareTo(b.term));
  }

  AcademicTerm? termInfo(int term, [String? schoolYear]) {
    final year = schoolYear ?? activeSchoolYear ?? currentSchoolYear();
    for (final value in academicTerms) {
      if (value.schoolYear == year && value.term == term) return value;
    }
    return null;
  }

  void addSchoolYear(String name, {bool makeActive = false}) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final value = SchoolYear(
      id: 'sy-$clean',
      name: clean,
      isActive: makeActive,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    schoolYears[value.id] = value;
    _db.putSchoolYear(value);
    if (makeActive) setActiveSchoolYear(clean);
    _changed();
  }

  void updateTermDates(int term, {String? start, String? end}) {
    final year = activeSchoolYear ?? currentSchoolYear();
    final existing = termInfo(term);
    final updated = AcademicTerm(
      id: existing?.id ?? 'sy-$year::t$term',
      schoolYear: year,
      term: term,
      start: start ?? existing?.start ?? '',
      end: end ?? existing?.end ?? '',
    );
    academicTerms = [
      for (final value in academicTerms)
        if (!(value.schoolYear == year && value.term == term)) value,
      updated,
    ];
    _db.putAcademicTerms([updated]);
    _changed();
  }

  /* -------------------------------- sections -------------------------------- */

  Section addSection({
    required String gradeLevel,
    required String section,
    required String schoolYear,
    Curriculum curriculum = Curriculum.existingShs,
  }) {
    final value = Section(
      id: newId(),
      gradeLevel: gradeLevel,
      section: section,
      schoolYear: schoolYear,
      curriculum: curriculum,
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
    String id, {
    String? gradeLevel,
    String? section,
    String? schoolYear,
    Curriculum? curriculum,
  }) {
    final prev = sections[id];
    if (prev == null) return;
    sections[id] = prev.copyWith(
      gradeLevel: gradeLevel,
      section: section,
      schoolYear: schoolYear,
      curriculum: curriculum,
    );
    _db.putSection(sections[id]!);
    _changed();
  }

  /// Archives a class (records are kept) or restores it to the active list.
  void archiveSection(String id, {bool archived = true}) {
    final prev = sections[id];
    if (prev == null) return;
    sections[id] = prev.copyWith(archived: archived);
    _db.putSection(sections[id]!);
    if (archived && activeSectionId == id) {
      activeSectionId = null;
      _db.saveSetting(SettingsKey.activeSectionId, null);
    }
    _changed();
  }

  /// Permanently deletes a class and every record that belongs to it. The UI
  /// asks for confirmation before calling this.
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
    scores.removeWhere(
      (key, _) => removedSubjectIds.contains(key.split('|').first),
    );
    attendance.removeWhere((_, day) => day.sectionId == id);
    bmi.removeWhere((_, record) => removedStudentIds.contains(record.studentId));
    termGrades.removeWhere(
      (_, record) => removedSubjectIds.contains(record.subjectId),
    );
    finalGrades.removeWhere(
      (_, record) => removedSubjectIds.contains(record.subjectId),
    );

    if (activeSectionId == id) activeSectionId = null;

    _db.removeSection(id); // cascades to every child row
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
    final now = DateTime.now().millisecondsSinceEpoch;
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
    students[id] = prev.copyWith(
      seatNumber: seatNumber,
      fullName: fullName,
      lrn: lrn,
      gender: gender,
      birthday: nextBirthday,
      guardianName: guardianName,
      guardianContact: guardianContact,
    );
    _db.putStudent(students[id]!);
    _changed();
  }

  /// Archives a learner (records preserved) or restores them to the roster.
  void archiveStudent(String id, {bool archived = true}) {
    final prev = students[id];
    if (prev == null) return;
    students[id] = prev.copyWith(archived: archived);
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
    _db.removeStudent(id); // cascades to scores, attendance, grades, BMI
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
    bool transmute = true,
    int termStart = 1,
    int termEnd = 3,
    String configId = '',
  }) {
    final value = Subject(
      id: newId(),
      sectionId: sectionId,
      name: name.trim(),
      teacherName: teacherName.trim(),
      weights: weights ??
          Map<AssessmentCategory, double>.from(depedAcademicWeights),
      transmute: transmute,
      termStart: termStart.clamp(1, 3),
      termEnd: termEnd.clamp(1, 3),
      configId: configId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final fixed = value.termEnd < value.termStart
        ? value.copyWith(termEnd: value.termStart)
        : value;
    subjects[fixed.id] = fixed;
    _db.putSubject(fixed);
    _changed();
    return fixed;
  }

  void updateSubject(
    String id, {
    String? name,
    String? teacherName,
    Weights? weights,
    bool? transmute,
    int? termStart,
    int? termEnd,
    String? configId,
  }) {
    final prev = subjects[id];
    if (prev == null) return;
    var next = prev.copyWith(
      name: name,
      teacherName: teacherName,
      weights: weights,
      transmute: transmute,
      termStart: termStart,
      termEnd: termEnd,
      configId: configId,
    );
    if (next.termEnd < next.termStart) {
      next = next.copyWith(termEnd: next.termStart);
    }
    subjects[id] = next;
    _db.putSubject(next);
    _changed();
  }

  void deleteSubject(String id) {
    subjects.remove(id);
    final removedSheetIds =
        sheets.values.where((s) => s.subjectId == id).map((s) => s.id).toSet();
    sheets.removeWhere((_, sheet) => sheet.subjectId == id);
    scores.removeWhere(
      (key, _) => removedSheetIds.contains(key.split('|').first),
    );
    termGrades.removeWhere((_, record) => record.subjectId == id);
    finalGrades.removeWhere((_, record) => record.subjectId == id);

    _db.removeSubject(id); // cascades to assessments, scores and grades
    _changed();
  }

  /* ------------------------------- score sheets ----------------------------- */

  String sheetIdOf(String subjectId, int term) => '$subjectId::t$term';

  ScoreSheet ensureSheet(String subjectId, int term) {
    final id = sheetIdOf(subjectId, term);
    final existing = sheets[id];
    if (existing != null) return existing;
    final value = ScoreSheet(
      id: id,
      subjectId: subjectId,
      term: term,
      items: {
        for (final category in AssessmentCategory.values)
          category: <AssessmentItem>[],
      },
    );
    sheets[id] = value;
    return value;
  }

  ScoreSheet? sheetOf(String subjectId, int term) =>
      sheets[sheetIdOf(subjectId, term)];

  AssessmentItem addItem(
    String subjectId,
    int term,
    AssessmentCategory category,
    String title,
    double max,
  ) {
    final sheet = ensureSheet(subjectId, term);
    final items = List<AssessmentItem>.from(sheet.itemsOf(category))
      ..add(AssessmentItem(
        id: newId(),
        title: title.trim(),
        max: max > 0 ? max : 100,
        category: category,
      ));
    final updated = sheet.copyWith(items: {...sheet.items, category: items});
    sheets[sheet.id] = updated;
    _db.putAssessment(subjectId, term, items.last, items.length - 1);
    _changed();
    return items.last;
  }

  void updateItem(
    String subjectId,
    int term,
    AssessmentCategory category,
    String itemId, {
    String? title,
    double? max,
  }) {
    final sheet = sheetOf(subjectId, term);
    if (sheet == null) return;
    var position = 0;
    final items = <AssessmentItem>[];
    for (final item in sheet.itemsOf(category)) {
      if (item.id == itemId) {
        final next = item.copyWith(
          title: title,
          max: (max != null && max > 0) ? max : null,
        );
        items.add(next);
        _db.putAssessment(subjectId, term, next, position);
      } else {
        items.add(item);
      }
      position += 1;
    }
    sheets[sheet.id] = sheet.copyWith(items: {...sheet.items, category: items});
    _changed();
  }

  void deleteItem(
    String subjectId,
    int term,
    AssessmentCategory category,
    String itemId,
  ) {
    final sheet = sheetOf(subjectId, term);
    if (sheet == null) return;
    final items = sheet.itemsOf(category)
        .where((item) => item.id != itemId)
        .toList();
    sheets[sheet.id] = sheet.copyWith(items: {...sheet.items, category: items});

    final prefix = '${sheet.id}|';
    final removedKeys =
        scores.keys.where((key) => key.startsWith(prefix) && key.endsWith('|$itemId'));
    for (final key in removedKeys.toList()) {
      scores.remove(key);
    }
    _db.removeAssessment(itemId); // cascades to its scores
    _changed();
  }

  void setScore(
    String sheetId,
    String studentId,
    String itemId,
    double? value, {
    int? term,
    String? subjectId,
  }) {
    final key = '$sheetId|$studentId|$itemId';
    if (value == null || value.isNaN) {
      scores.remove(key);
    } else {
      scores[key] = value;
    }
    _db.saveScore(key, value);

    // Keep the stored term grades in step with the scores.
    final sheet = sheets[sheetId];
    final t = term ?? sheet?.term;
    final s = subjectId ?? sheet?.subjectId;
    if (s != null && t != null) _persistGrades(s, t);

    _changed();
  }

  /* --------------------------------- grades --------------------------------- */

  TermGradeResult gradeOf(Subject subject, int term, String studentId) {
    return computeTermGrade(
      subject.weights,
      subject.transmute,
      sheetOf(subject.id, term),
      scores,
      studentId,
    );
  }

  /// Average of the subject's term grades for the terms it is offered in.
  double? finalGradeOf(Subject subject, String studentId) {
    final values = <double?>[
      for (final term in subject.activeTerms)
        gradeOf(subject, term, studentId).termGrade,
    ];
    return computeFinalGrade(values);
  }

  /// Recomputes and stores the term grades of a subject (and its final grade)
  /// so reports and historical records keep their values.
  void _persistGrades(String subjectId, int term) {
    final subject = subjects[subjectId];
    if (subject == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final roster = studentsOf(subject.sectionId);
    final records = <TermGradeRecord>[];
    for (final student in roster) {
      final result = gradeOf(subject, term, student.id);
      if (!result.hasGrade) continue;
      records.add(TermGradeRecord(
        subjectId: subjectId,
        term: term,
        studentId: student.id,
        initialGrade: result.initialGrade!,
        termGrade: result.termGrade!,
        computedAt: now,
      ));
      termGrades['$subjectId|$term|${student.id}'] = records.last;
    }
    _db.saveTermGrades(records, term: term, subjectId: subjectId);

    final finals = <FinalGradeRecord>[];
    for (final student in roster) {
      final value = finalGradeOf(subject, student.id);
      if (value == null) continue;
      finals.add(FinalGradeRecord(
        subjectId: subjectId,
        studentId: student.id,
        grade: value,
        computedAt: now,
      ));
      finalGrades['$subjectId|${student.id}'] = finals.last;
    }
    _db.saveFinalGrades(finals, subjectId: subjectId);
  }

  /// Recomputes every stored grade (used after imports or a restore).
  void recomputeAllGrades() {
    for (final subject in subjects.values) {
      for (final term in subject.activeTerms) {
        _persistGrades(subject.id, term);
      }
    }
  }

  TermGradeRecord? storedTermGrade(String subjectId, int term, String studentId) =>
      termGrades['$subjectId|$term|$studentId'];

  FinalGradeRecord? storedFinalGrade(String subjectId, String studentId) =>
      finalGrades['$subjectId|$studentId'];

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
        if (s.sectionId == sectionId && !s.archived) s.id: status,
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

  /// Attendance totals of a class, optionally limited to one term.
  AttendanceSummary attendanceSummary(String sectionId, {int? term}) {
    var present = 0, late = 0, absent = 0, excused = 0, days = 0;
    final ranges = term == null ? null : termsOf(activeSchoolYear);
    final info = ranges?.where((t) => t.term == term).firstOrNull;
    for (final day in attendance.values) {
      if (day.sectionId != sectionId) continue;
      if (info != null && info.start.isNotEmpty && info.end.isNotEmpty) {
        if (day.date.compareTo(info.start) < 0 ||
            day.date.compareTo(info.end) > 0) {
          continue;
        }
      }
      days += 1;
      present += day.countOf(AttendanceStatus.present);
      late += day.countOf(AttendanceStatus.late);
      absent += day.countOf(AttendanceStatus.absent);
      excused += day.countOf(AttendanceStatus.excused);
    }
    return AttendanceSummary(
      days: days,
      present: present,
      late: late,
      absent: absent,
      excused: excused,
    );
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

  List<Student> studentsOf(String? sectionId, {bool includeArchived = false}) {
    if (sectionId == null) return const [];
    final list = students.values
        .where((s) => s.sectionId == sectionId &&
            (includeArchived || !s.archived))
        .toList()
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
    return list;
  }

  /// Classes for the active school year (archived ones excluded by default).
  List<Section> classesOf(String? schoolYear, {bool includeArchived = false}) {
    final year = schoolYear ?? activeSchoolYear;
    final list = sections.values
        .where((s) =>
            (year == null || s.schoolYear == year) &&
            (includeArchived || !s.archived))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<Section> archivedClasses() => sections.values
      .where((section) => section.archived)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<Subject> subjectsOf(String? sectionId) {
    if (sectionId == null) return const [];
    final list = subjects.values.where((s) => s.sectionId == sectionId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Subjects of a class that are offered in [term].
  List<Subject> subjectsInTerm(String? sectionId, int term) =>
      subjectsOf(sectionId).where((subject) => subject.covers(term)).toList();

  Section? section(String? id) => id == null ? null : sections[id];

  Student? student(String? id) => id == null ? null : students[id];

  Subject? subject(String? id) => id == null ? null : subjects[id];

  GradingConfig? config(String? id) => id == null ? null : gradingConfigs[id];

  List<GradingConfig> configsFor(Curriculum curriculum) => gradingConfigs.values
      .where((config) => config.curriculum == curriculum)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  /// Latest BMI record for a student (most recent first).
  BmiRecord? latestBmi(String studentId) {
    BmiRecord? best;
    for (final record in bmi.values) {
      if (record.studentId != studentId) continue;
      if (best == null ||
          record.recordedAt > best.recordedAt ||
          (record.recordedAt == best.recordedAt &&
              record.date.compareTo(best.date) > 0)) {
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

  /// Total learners across the active school year.
  int get totalStudents => students.values
      .where((student) => !student.archived && sections[student.sectionId] != null)
      .length;

  int get totalClasses => classesOf(activeSchoolYear).length;

  /// Full snapshot for exports.
  BackupData backupData() => BackupData(
        teacherName: teacherName,
        sections: sections,
        students: students,
        subjects: subjects,
        sheets: sheets,
        scores: scores,
        attendance: attendance,
        bmi: bmi,
        activeSchoolYear: activeSchoolYear,
        activeTerm: activeTerm,
      );

  /* --------------------------------- backup --------------------------------- */

  /// Writes a copy of the SQLite database to [destination].
  Future<File> backupDatabase(String destination) =>
      _db.backupTo(destination);

  /// Restores [source] over the live database and reloads the store.
  Future<void> restoreDatabase(String source) async {
    await _db.restoreFrom(source);
    await load();
  }

  Future<String> databasePath() => _db.databaseFilePath;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.days,
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
  });

  final int days;
  final int present;
  final int late;
  final int absent;
  final int excused;

  int get total => present + late + absent + excused;

  /// Share of marks that count as present (present + late).
  double get attendanceRate => total == 0 ? 0 : (present + late) / total * 100;
}

int mathMax(int a, int b) => a > b ? a : b;
