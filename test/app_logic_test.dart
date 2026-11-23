import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tugbotrack/data/database.dart';
import 'package:tugbotrack/models/models.dart';
import 'package:tugbotrack/services/backup.dart';
import 'package:tugbotrack/services/bmi.dart';
import 'package:tugbotrack/services/grading.dart';
import 'package:tugbotrack/services/reports.dart' as reports;

const _subjectId = 'sub-1';

ScoreSheet sheetWith({
  List<AssessmentItem> ww = const [],
  List<AssessmentItem> pt = const [],
  List<AssessmentItem> te = const [],
}) {
  return ScoreSheet(
    id: '$_subjectId::t1',
    subjectId: _subjectId,
    term: 1,
    items: {
      AssessmentCategory.writtenWorks: ww,
      AssessmentCategory.performanceTasks: pt,
      AssessmentCategory.termExam: te,
    },
  );
}

AssessmentItem item(String id, double max, AssessmentCategory category) =>
    AssessmentItem(id: id, title: id, max: max, category: category);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('grade computation', () {
    test('weights WW/PT/TE and transmutes the initial grade', () {
      final sheet = sheetWith(
        ww: [item('ww1', 20, AssessmentCategory.writtenWorks)],
        pt: [item('pt1', 50, AssessmentCategory.performanceTasks)],
        te: [item('te1', 100, AssessmentCategory.termExam)],
      );
      final scores = {
        '$_subjectId::t1|st1|ww1': 18.0, // 90%
        '$_subjectId::t1|st1|pt1': 40.0, // 80%
        '$_subjectId::t1|st1|te1': 85.0, // 85%
      };
      final result = computeTermGrade(
        depedAcademicWeights,
        true,
        sheet,
        scores,
        'st1',
      );

      // 90*0.25 + 80*0.50 + 85*0.25 = 83.75
      expect(result.initialGrade, closeTo(83.75, 0.001));
      expect(result.components[AssessmentCategory.writtenWorks]!.percentage,
          closeTo(90, 0.001));
      expect(result.termGrade, 89); // 83.75 falls in the 89 band
      expect(result.displayGrade, 89);
    });

    test('missing categories redistribute their weight', () {
      final sheet = sheetWith(
        ww: [item('ww1', 10, AssessmentCategory.writtenWorks)],
        pt: [item('pt1', 10, AssessmentCategory.performanceTasks)],
      );
      final scores = {
        '$_subjectId::t1|st1|ww1': 10.0,
        '$_subjectId::t1|st1|pt1': 5.0,
      };
      final result = computeTermGrade(
        depedAcademicWeights,
        false,
        sheet,
        scores,
        'st1',
      );
      // (100*25 + 50*50) / 75 = 66.666…
      expect(result.initialGrade, closeTo(66.67, 0.001));
      expect(result.termGrade, closeTo(66.67, 0.001));
      expect(result.usedWeights[AssessmentCategory.termExam], 0);
    });

    test('no scores yields no grade', () {
      final result = computeTermGrade(
        depedAcademicWeights,
        true,
        sheetWith(),
        {},
        'st1',
      );
      expect(result.initialGrade, isNull);
      expect(result.termGrade, isNull);
      expect(result.hasGrade, isFalse);
    });

    test('custom weights are honoured per subject', () {
      final sheet = sheetWith(
        pt: [item('pt1', 100, AssessmentCategory.performanceTasks)],
      );
      final result = computeTermGrade(
        depedTvlWeights,
        false,
        sheet,
        {'$_subjectId::t1|st1|pt1': 70.0},
        'st1',
      );
      expect(result.initialGrade, closeTo(70, 0.001));
    });
  });

  group('transmutation (DO 8, s. 2015)', () {
    test('bands map 60 -> 75 and step every 1.6 points', () {
      expect(transmuteGrade(60), 75);
      expect(transmuteGrade(61.59), 75);
      expect(transmuteGrade(61.6), 76);
      expect(transmuteGrade(75.99), 84);
      expect(transmuteGrade(76), 85);
      expect(transmuteGrade(98.4), 99);
      expect(transmuteGrade(99.99), 99);
      expect(transmuteGrade(100), 100);
    });

    test('a failing initial grade is never rounded into a pass', () {
      expect(transmuteGrade(59.9), 59.9);
      expect(transmuteGrade(40), 40);
    });

    test('the published table runs 75..100', () {
      final table = transmutationTable();
      expect(table.first.grade, 100);
      expect(table.last.grade, 75);
      expect(table.length, 26);
    });
  });

  group('rounding and final grades', () {
    test('half-up rounding avoids float drift', () {
      expect(roundTo(83.749999999, 2), closeTo(83.75, 0.0001));
      expect(reportGrade(87.5), 88);
      expect(reportGrade(86.49), 86);
      expect(reportGrade(75.0), 75);
    });

    test('final grade averages the available terms only', () {
      expect(computeFinalGrade([88, 90, null]), closeTo(89, 0.001));
      expect(computeFinalGrade([null, null, null]), isNull);
      expect(computeFinalGrade([85]), 85);
    });

    test('descriptors follow the DepEd bands', () {
      expect(gradeDescriptors(91), 'Outstanding');
      expect(gradeDescriptors(86), 'Very Satisfactory');
      expect(gradeDescriptors(81), 'Satisfactory');
      expect(gradeDescriptors(76), 'Fairly Satisfactory');
      expect(gradeDescriptors(70), 'Did Not Meet Expectations');
    });

    test('weights must total 100', () {
      expect(validateWeights(depedAcademicWeights), isNull);
      expect(
        validateWeights({
          AssessmentCategory.writtenWorks: 30,
          AssessmentCategory.performanceTasks: 30,
          AssessmentCategory.termExam: 30,
        }),
        isNotNull,
      );
    });
  });

  group('three-term calendar', () {
    test('a subject reports the terms it is offered in', () {
      const wholeYear = Subject(
        id: 's1',
        sectionId: 'c1',
        name: 'General Mathematics',
        teacherName: '',
        weights: depedAcademicWeights,
        transmute: true,
        createdAt: 0,
      );
      final elective = wholeYear.copyWith(termStart: 2, termEnd: 2);

      expect(wholeYear.activeTerms, [1, 2, 3]);
      expect(wholeYear.termSpanLabel, 'Whole year');
      expect(elective.activeTerms, [2]);
      expect(elective.covers(1), isFalse);
      expect(elective.covers(2), isTrue);
      expect(elective.termSpanLabel, 'Term 2');
    });

    test('the school year helper follows the August start', () {
      expect(currentSchoolYear(DateTime(2026, 9, 1)), '2026-2027');
      expect(currentSchoolYear(DateTime(2027, 3, 1)), '2026-2027');
    });
  });

  group('attendance and BMI', () {
    test('attendance summary counts every status', () {
      const sectionId = 'c1';
      final day = AttendanceDay(
        id: '$sectionId::2026-08-03',
        sectionId: sectionId,
        date: '2026-08-03',
        statuses: {
          'a': AttendanceStatus.present,
          'b': AttendanceStatus.present,
          'c': AttendanceStatus.late,
          'd': AttendanceStatus.absent,
          'e': AttendanceStatus.excused,
        },
        markedAt: 0,
      );
      expect(day.countOf(AttendanceStatus.present), 2);
      expect(day.countOf(AttendanceStatus.late), 1);
      expect(day.countOf(AttendanceStatus.absent), 1);
      expect(day.countOf(AttendanceStatus.excused), 1);
    });

    test('BMI uses the age and sex specific reference', () {
      final normal = interpretBmi(21, ageYears: 16, sex: 'Male');
      expect(normal?.category, 'Normal');
      expect(normal?.reference, contains('16 y'));

      final obese = interpretBmi(27, ageYears: 16, sex: 'Male');
      expect(obese?.category, 'Obese');

      final thin = interpretBmi(12, ageYears: 10, sex: 'Female');
      expect(thin?.category, 'Thinness');

      // Without age/sex the adult cut-offs apply.
      final adult = interpretBmi(27);
      expect(adult?.category, 'Overweight');
      expect(adult?.reference, contains('adult'));
    });

    test('BMI ignores invalid measurements', () {
      expect(computeBmi(0, 50), isNull);
      expect(computeBmi(160, 0), isNull);
      expect(interpretBmi(null), isNull);
      expect(computeBmi(160, 60), closeTo(23.4375, 0.0001));
    });
  });

  group('CSV export', () {
    test('class record CSV lists the learner with term grade', () {
      const section = Section(
        id: 'c1',
        gradeLevel: 'Grade 11',
        section: 'Sampaguita',
        schoolYear: '2026-2027',
        createdAt: 0,
      );
      const subject = Subject(
        id: _subjectId,
        sectionId: 'c1',
        name: 'General Mathematics',
        teacherName: 'Ms. Cruz',
        weights: depedAcademicWeights,
        transmute: true,
        createdAt: 0,
      );
      final sheet = sheetWith(
        ww: [item('ww1', 10, AssessmentCategory.writtenWorks)],
        pt: [item('pt1', 10, AssessmentCategory.performanceTasks)],
        te: [item('te1', 10, AssessmentCategory.termExam)],
      );
      const student = Student(
        id: 'st1',
        sectionId: 'c1',
        seatNumber: 1,
        fullName: 'Juan Dela Cruz',
        lrn: '123456789012',
        gender: 'Male',
        birthday: '2010-01-01',
        guardianName: '',
        guardianContact: '',
        createdAt: 0,
      );
      final data = BackupData(
        teacherName: 'Ms. Cruz',
        sections: {section.id: section},
        students: {student.id: student},
        subjects: {subject.id: subject},
        sheets: {sheet.id: sheet},
        scores: {
          '$_subjectId::t1|st1|ww1': 10.0,
          '$_subjectId::t1|st1|pt1': 9.0,
          '$_subjectId::t1|st1|te1': 8.0,
        },
        attendance: const {},
        bmi: const {},
      );

      final csv = buildClassRecordCsv(data, section, subject, 1);
      expect(csv, contains('Juan Dela Cruz'));
      expect(csv, contains('Subject: General Mathematics'));
      expect(csv, contains('100.0')); // WW percentage
      // initial = 100*.25 + 90*.5 + 80*.25 = 90
      expect(csv, contains('90.0'));
      expect(buildFinalGradesCsv(data, section), contains('General Mathematics'));
    });
  });

  group('report card PDF', () {
    test('builds one learner sheet with grades, attendance and BMI', () async {
      const section = Section(
        id: 'c1',
        gradeLevel: 'Grade 11',
        section: 'Sampaguita',
        schoolYear: '2026-2027',
        createdAt: 0,
      );
      final subject = Subject(
        id: _subjectId,
        sectionId: 'c1',
        name: 'General Mathematics',
        teacherName: 'Ms. Cruz',
        weights: depedAcademicWeights,
        transmute: true,
        createdAt: 0,
      );
      final sheet = sheetWith(
        ww: [item('ww1', 10, AssessmentCategory.writtenWorks)],
        pt: [item('pt1', 10, AssessmentCategory.performanceTasks)],
        te: [item('te1', 10, AssessmentCategory.termExam)],
      );
      const student = Student(
        id: 'st1',
        sectionId: 'c1',
        seatNumber: 1,
        fullName: 'Juan Dela Cruz',
        lrn: '123456789012',
        gender: 'Male',
        birthday: '2010-01-01',
        guardianName: '',
        guardianContact: '',
        createdAt: 0,
      );
      final data = BackupData(
        teacherName: 'Ms. Cruz',
        sections: {section.id: section},
        students: {student.id: student},
        subjects: {subject.id: subject},
        sheets: {sheet.id: sheet},
        scores: {
          '$_subjectId::t1|st1|ww1': 10.0,
          '$_subjectId::t1|st1|pt1': 9.0,
          '$_subjectId::t1|st1|te1': 8.0,
        },
        attendance: const {
          'c1::2026-08-03': AttendanceDay(
            id: 'c1::2026-08-03',
            sectionId: 'c1',
            date: '2026-08-03',
            statuses: {'st1': AttendanceStatus.present},
            markedAt: 0,
          ),
        },
        bmi: const {
          'st1::2026-08-03': BmiRecord(
            id: 'st1::2026-08-03',
            studentId: 'st1',
            date: '2026-08-03',
            heightCm: 160,
            weightKg: 55,
            recordedAt: 0,
          ),
        },
      );

      final bytes = await reports.buildReportCardPdfBytes(data, section, student);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('SQLite', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('migrates the quarterly database to three terms', () async {
      final dir = await Directory.systemTemp.createTemp('tugbotrack-test');
      final path = p.join(dir.path, 'legacy.db');

      // Build a version-1 database exactly as the previous build wrote it.
      final legacy = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE kv (key TEXT PRIMARY KEY NOT NULL, value TEXT)',
            );
            await db.execute(
              'CREATE TABLE sections (id TEXT PRIMARY KEY NOT NULL, '
              'grade_level TEXT NOT NULL, section TEXT NOT NULL, '
              'school_year TEXT NOT NULL, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE students (id TEXT PRIMARY KEY NOT NULL, '
              'section_id TEXT NOT NULL, seat_number INTEGER, full_name TEXT NOT NULL, '
              "lrn TEXT NOT NULL DEFAULT '', gender TEXT NOT NULL DEFAULT '', "
              "birthday TEXT NOT NULL DEFAULT '', guardian_name TEXT NOT NULL DEFAULT '', "
              "guardian_contact TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)",
            );
            await db.execute(
              'CREATE TABLE subjects (id TEXT PRIMARY KEY NOT NULL, '
              'section_id TEXT NOT NULL, name TEXT NOT NULL, '
              "teacher_name TEXT NOT NULL DEFAULT '', weights TEXT NOT NULL, "
              'transmute INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE sheets (id TEXT PRIMARY KEY NOT NULL, '
              'subject_id TEXT NOT NULL, quarter INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE sheet_items (id TEXT PRIMARY KEY NOT NULL, '
              'sheet_id TEXT NOT NULL, component TEXT NOT NULL, title TEXT NOT NULL, '
              'max_score INTEGER NOT NULL, position INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE scores (sheet_id TEXT NOT NULL, student_id TEXT NOT NULL, '
              'item_id TEXT NOT NULL, value REAL NOT NULL, '
              'PRIMARY KEY (sheet_id, student_id, item_id))',
            );
            await db.execute(
              'CREATE TABLE attendance_days (id TEXT PRIMARY KEY NOT NULL, '
              'section_id TEXT NOT NULL, date TEXT NOT NULL, marked_at INTEGER NOT NULL)',
            );
            await db.execute(
              'CREATE TABLE attendance_marks (day_id TEXT NOT NULL, '
              'student_id TEXT NOT NULL, status TEXT NOT NULL, '
              'PRIMARY KEY (day_id, student_id))',
            );
            await db.execute(
              'CREATE TABLE bmi (student_id TEXT NOT NULL, date TEXT NOT NULL, '
              'height_cm REAL NOT NULL, weight_kg REAL NOT NULL, '
              'recorded_at INTEGER NOT NULL, PRIMARY KEY (student_id, date))',
            );
          },
        ),
      );

      await legacy.insert('sections', {
        'id': 'c1',
        'grade_level': 'Grade 11',
        'section': 'Sampaguita',
        'school_year': '2026-2027',
        'created_at': 1,
      });
      await legacy.insert('students', {
        'id': 'st1',
        'section_id': 'c1',
        'seat_number': 1,
        'full_name': 'Juan Dela Cruz',
        'lrn': '123',
        'created_at': 1,
      });
      await legacy.insert('subjects', {
        'id': 'sub1',
        'section_id': 'c1',
        'name': 'General Mathematics',
        'teacher_name': 'Ms. Cruz',
        'weights': '{"quizzes":10,"assignments":10,"activities":10,'
            '"performanceTasks":30,"examinations":40}',
        'transmute': 1,
        'created_at': 1,
      });
      await legacy.insert('sheets', {
        'id': 'sub1::q1',
        'subject_id': 'sub1',
        'quarter': 1,
      });
      await legacy.insert('sheet_items', {
        'id': 'it1',
        'sheet_id': 'sub1::q1',
        'component': 'quizzes',
        'title': 'Quiz 1',
        'max_score': 20,
        'position': 0,
      });
      await legacy.insert('sheet_items', {
        'id': 'it2',
        'sheet_id': 'sub1::q1',
        'component': 'examinations',
        'title': 'Exam 1',
        'max_score': 50,
        'position': 1,
      });
      await legacy.insert('scores', {
        'sheet_id': 'sub1::q1',
        'student_id': 'st1',
        'item_id': 'it1',
        'value': 18.0,
      });
      await legacy.insert('scores', {
        'sheet_id': 'sub1::q1',
        'student_id': 'st1',
        'item_id': 'it2',
        'value': 40.0,
      });
      await legacy.insert('attendance_days', {
        'id': 'c1::2026-08-03',
        'section_id': 'c1',
        'date': '2026-08-03',
        'marked_at': 5,
      });
      await legacy.insert('attendance_marks', {
        'day_id': 'c1::2026-08-03',
        'student_id': 'st1',
        'status': 'present',
      });
      await legacy.insert('bmi', {
        'student_id': 'st1',
        'date': '2026-08-03',
        'height_cm': 160.0,
        'weight_kg': 55.0,
        'recorded_at': 5,
      });
      await legacy.close();

      // Opening through the app upgrades it to the three-term schema.
      final service = DatabaseService(path);
      final data = await service.loadAll();

      expect(data.sections['c1']?.gradeLevel, 'Grade 11');
      expect(data.students['st1']?.fullName, 'Juan Dela Cruz');
      final subject = data.subjects['sub1']!;
      expect(subject.termStart, 1);
      expect(subject.termEnd, 3);
      // The old five components collapse into WW/PT/TE.
      expect(subject.weights[AssessmentCategory.writtenWorks], 30);
      expect(subject.weights[AssessmentCategory.performanceTasks], 30);
      expect(subject.weights[AssessmentCategory.termExam], 40);
      expect(subject.transmute, isTrue);

      final sheet = data.sheets['sub1::t1']!;
      expect(sheet.term, 1);
      expect(sheet.itemsOf(AssessmentCategory.writtenWorks), hasLength(1));
      expect(sheet.itemsOf(AssessmentCategory.termExam), hasLength(1));
      expect(
        data.scores['sub1::t1|st1|it1'],
        18.0,
      );
      expect(data.attendance['c1::2026-08-03']?.statuses['st1'],
          AttendanceStatus.present);
      expect(data.bmi['st1::2026-08-03']?.weightKg, 55.0);
      // Calendar seeded with the three terms.
      final yearTerms =
          data.academicTerms.where((term) => term.schoolYear == '2026-2027');
      expect(yearTerms.map((term) => term.term), [1, 2, 3]);

      // A second open (already at v2) must not lose anything.
      final reopened = DatabaseService(path);
      final again = await reopened.loadAll();
      expect(again.students, hasLength(1));
      expect(again.subjects, hasLength(1));

      // Close every connection so the temp folder can be removed.
      await service.close();
      await reopened.close();
      await deleteTempDir(Directory(p.dirname(path)));
    });

    test('a fresh database is created with the calendar and presets',
        () async {
      final dir = await Directory.systemTemp.createTemp('tugbotrack-fresh');
      final path = p.join(dir.path, 'fresh.db');
      final service = DatabaseService(path);
      final data = await service.loadAll();

      expect(data.schoolYears.values.map((year) => year.name),
          contains(defaultSchoolYear));
      expect(data.academicTerms.where((term) => term.schoolYear == '2026-2027'),
          hasLength(3));
      expect(data.gradingConfigs, isNotEmpty);
      expect(
        data.gradingConfigs.values
            .where((config) => config.isDefault)
            .map((config) => config.curriculum),
        containsAll([Curriculum.existingShs, Curriculum.strengthenedShs]),
      );

      await service.close();
      await deleteTempDir(dir);
    });
  });
}

/// Deletes a temporary database folder, retrying briefly: Windows keeps the
/// SQLite file handle for a moment after the connection closes.
Future<void> deleteTempDir(Directory dir) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
