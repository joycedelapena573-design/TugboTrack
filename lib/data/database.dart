/// SQLite storage layer for TugboTrack.
///
/// One on-device database file (`tugbotrack.db`) holds every record the app
/// needs offline. The schema is relational, with primary keys, foreign keys,
/// indexes, versioning and migrations:
///
///   kv                      app settings (active class, term, logo)
///   teachers                the teacher using this device
///   school_years            e.g. 2026-2027
///   academic_terms          Term 1..3 of each school year
///   classes                 grade level + section + school year
///   subjects                subjects of a class with their term span
///   students                learners (LRN, birthday, guardian, ...)
///   class_students          enrolment history (class <-> student)
///   assessments             WW / PT / TE items of a subject in a term
///   student_scores          one score per student per assessment
///   attendance              one row per class + date + student
///   term_grades             computed term grade per subject/term/student
///   final_grades            average of the term grades per subject/student
///   bmi_records             height/weight measurements
///   grading_configurations  weight sets (built-in presets or per subject)
///   grading_components      the WW/PT/TE weights of a configuration
///
/// Every write is queued so it runs after the write before it, and the
/// multi-row operations run inside a transaction: a failure leaves the previous
/// state intact instead of a half-saved record.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Settings stored under the `kv` table.
abstract final class SettingsKey {
  static const teacherName = 'teacherName';
  static const activeSectionId = 'activeSectionId';
  static const activeTerm = 'activeTerm';
  static const activeSchoolYear = 'activeSchoolYear';
  static const schoolLogoUri = 'schoolLogoUri';
  static const legacyMigrated = 'legacyMigrated';
  static const schemaVersion = 'schemaVersion';
  static const largeText = 'largeText';
  static const tipsSeen = 'tipsSeen';
  static const lastBackupAt = 'lastBackupAt';
  static const lastWeights = 'lastWeights';

  /// Per-learner report-card remark: `comment:<studentId>`.
  static const commentPrefix = 'comment:';

  /// Last attendance date worked on: `attendanceDate:<sectionId>`.
  static const attendanceDatePrefix = 'attendanceDate:';
}

/// Current schema version. Version 1 was the quarterly build; version 2 is the
/// three-term calendar with WW/PT/TE grading.
const int schemaVersion = 2;

/// Key under which the earlier React Native build stored the whole state.
const String _legacyKey = 'tis-classtrack';

/// Everything the store persists, read back from the database.
class PersistedData {
  const PersistedData({
    required this.teacherName,
    required this.activeSectionId,
    required this.activeTerm,
    required this.activeSchoolYear,
    required this.schoolLogoUri,
    required this.sections,
    required this.students,
    required this.subjects,
    required this.sheets,
    required this.scores,
    required this.attendance,
    required this.bmi,
    required this.gradingConfigs,
    required this.schoolYears,
    required this.academicTerms,
    required this.termGrades,
    required this.finalGrades,
    this.kv = const {},
  });

  /// Raw settings rows (preferences, report-card comments, ...).
  final Map<String, String> kv;

  final String teacherName;
  final String? activeSectionId;
  final int activeTerm;
  final String? activeSchoolYear;
  final String? schoolLogoUri;
  final Map<String, Section> sections;
  final Map<String, Student> students;
  final Map<String, Subject> subjects;
  final Map<String, ScoreSheet> sheets;
  final ScoreMap scores;
  final Map<String, AttendanceDay> attendance;
  final Map<String, BmiRecord> bmi;
  final Map<String, GradingConfig> gradingConfigs;
  final Map<String, SchoolYear> schoolYears;
  final List<AcademicTerm> academicTerms;
  final Map<String, TermGradeRecord> termGrades;
  final Map<String, FinalGradeRecord> finalGrades;
}

/// Summary of a backup file shown before it is restored.
class BackupPreview {
  const BackupPreview({required this.schemaVersion, required this.counts});

  final int schemaVersion;
  final Map<String, int> counts;

  int get classes => counts['classes'] ?? 0;
  int get students => counts['students'] ?? 0;
  int get subjects => counts['subjects'] ?? 0;
  int get attendanceDays => counts['attendance'] ?? 0;
  int get bmiRecords => counts['bmi_records'] ?? 0;

  /// True when the file was written by a newer app version than this build.
  bool get isNewerThanApp => schemaVersion > schemaVersionOfApp;
}

/// Schema version this build understands (mirrors [schemaVersion]).
const int schemaVersionOfApp = schemaVersion;

class DatabaseService {
  DatabaseService([this._databasePath]);

  static final DatabaseService instance = DatabaseService();

  final String? _databasePath;
  Future<Database>? _future;
  Future<dynamic> _queue = Future<dynamic>.value();

  /// Path of the live database file (used by backup/restore).
  Future<String> get databaseFilePath async =>
      _databasePath ?? p.join(await getDatabasesPath(), 'tugbotrack.db');

  Future<Database> get _database async {
    if (_future != null) return _future!;
    final future = () async {
      final path = await databaseFilePath;
      final db = await openDatabase(
        path,
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createSchema(db);
          await _seed(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await _migrateV1ToV2(db);
          await _seed(db);
        },
      );
      return db;
    }();
    _future = future;
    try {
      return await future;
    } catch (_) {
      _future = null; // retry on the next operation
      rethrow;
    }
  }

  /// Run one operation after everything queued before it.
  ///
  /// Errors are reported but never thrown at fire-and-forget callers: the
  /// in-memory store already holds the data the user just saved, so a failed
  /// write must not break the screen.
  Future<T> _enqueue<T>(
    Future<T> Function(Database db) task, {
    bool reportErrors = true,
  }) {
    final run = _queue.then((_) => _database).then(task);
    _queue = run.then<dynamic>(
      (value) => null,
      onError: reportErrors
          ? (Object error) {
              // ignore: avoid_print
              print('[sqlite] database operation failed: $error');
            }
          : null,
    );
    return run;
  }

  /* --------------------------------- schema -------------------------------- */

  static const List<String> _schema = [
    '''
    CREATE TABLE IF NOT EXISTS kv (
      key   TEXT PRIMARY KEY NOT NULL,
      value TEXT
    )''',
    '''
    CREATE TABLE IF NOT EXISTS teachers (
      id         TEXT PRIMARY KEY NOT NULL,
      name       TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS school_years (
      id         TEXT PRIMARY KEY NOT NULL,
      name       TEXT NOT NULL UNIQUE,
      is_active  INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS academic_terms (
      id          TEXT PRIMARY KEY NOT NULL,
      school_year TEXT NOT NULL,
      term        INTEGER NOT NULL,
      start_date  TEXT NOT NULL DEFAULT '',
      end_date    TEXT NOT NULL DEFAULT '',
      UNIQUE (school_year, term)
    )''',
    'CREATE INDEX IF NOT EXISTS idx_terms_year ON academic_terms(school_year)',
    '''
    CREATE TABLE IF NOT EXISTS classes (
      id          TEXT PRIMARY KEY NOT NULL,
      grade_level TEXT NOT NULL,
      section     TEXT NOT NULL,
      school_year TEXT NOT NULL,
      curriculum  TEXT NOT NULL DEFAULT 'existingShs',
      archived    INTEGER NOT NULL DEFAULT 0,
      created_at  INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_classes_year ON classes(school_year)',
    'CREATE INDEX IF NOT EXISTS idx_classes_archived ON classes(archived)',
    '''
    CREATE TABLE IF NOT EXISTS grading_configurations (
      id          TEXT PRIMARY KEY NOT NULL,
      name        TEXT NOT NULL,
      curriculum  TEXT NOT NULL DEFAULT 'existingShs',
      transmute   INTEGER NOT NULL DEFAULT 1,
      is_default  INTEGER NOT NULL DEFAULT 0,
      is_builtin  INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE IF NOT EXISTS grading_components (
      config_id TEXT NOT NULL,
      category  TEXT NOT NULL,
      weight    REAL NOT NULL DEFAULT 0,
      PRIMARY KEY (config_id, category),
      FOREIGN KEY (config_id) REFERENCES grading_configurations(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE IF NOT EXISTS subjects (
      id          TEXT PRIMARY KEY NOT NULL,
      class_id    TEXT NOT NULL,
      name        TEXT NOT NULL,
      teacher_name TEXT NOT NULL DEFAULT '',
      term_start  INTEGER NOT NULL DEFAULT 1,
      term_end    INTEGER NOT NULL DEFAULT 3,
      config_id   TEXT NOT NULL DEFAULT '',
      created_at  INTEGER NOT NULL,
      FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_subjects_class ON subjects(class_id)',
    '''
    CREATE TABLE IF NOT EXISTS students (
      id               TEXT PRIMARY KEY NOT NULL,
      class_id         TEXT NOT NULL,
      seat_number      INTEGER,
      full_name        TEXT NOT NULL,
      lrn              TEXT NOT NULL DEFAULT '',
      gender           TEXT NOT NULL DEFAULT '',
      birthday         TEXT NOT NULL DEFAULT '',
      guardian_name    TEXT NOT NULL DEFAULT '',
      guardian_contact TEXT NOT NULL DEFAULT '',
      archived         INTEGER NOT NULL DEFAULT 0,
      created_at       INTEGER NOT NULL,
      FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_students_class ON students(class_id)',
    'CREATE INDEX IF NOT EXISTS idx_students_name ON students(full_name)',
    '''
    CREATE TABLE IF NOT EXISTS class_students (
      class_id    TEXT NOT NULL,
      student_id  TEXT NOT NULL,
      enrolled_at INTEGER NOT NULL,
      PRIMARY KEY (class_id, student_id),
      FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_enrolments_student ON class_students(student_id)',
    '''
    CREATE TABLE IF NOT EXISTS assessments (
      id         TEXT PRIMARY KEY NOT NULL,
      subject_id TEXT NOT NULL,
      term       INTEGER NOT NULL,
      category   TEXT NOT NULL,
      title      TEXT NOT NULL,
      max_score  REAL NOT NULL DEFAULT 100,
      position   INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_assessments_subject ON assessments(subject_id, term)',
    '''
    CREATE TABLE IF NOT EXISTS student_scores (
      assessment_id TEXT NOT NULL,
      student_id    TEXT NOT NULL,
      value         REAL NOT NULL,
      PRIMARY KEY (assessment_id, student_id),
      FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_scores_student ON student_scores(student_id)',
    '''
    CREATE TABLE IF NOT EXISTS attendance (
      class_id   TEXT NOT NULL,
      date       TEXT NOT NULL,
      student_id TEXT NOT NULL,
      status     TEXT NOT NULL,
      marked_at  INTEGER NOT NULL,
      PRIMARY KEY (class_id, date, student_id),
      FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(class_id, date)',
    '''
    CREATE TABLE IF NOT EXISTS term_grades (
      subject_id    TEXT NOT NULL,
      term          INTEGER NOT NULL,
      student_id    TEXT NOT NULL,
      initial_grade REAL NOT NULL,
      term_grade    REAL NOT NULL,
      computed_at   INTEGER NOT NULL,
      PRIMARY KEY (subject_id, term, student_id),
      FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE IF NOT EXISTS final_grades (
      subject_id  TEXT NOT NULL,
      student_id  TEXT NOT NULL,
      grade       REAL NOT NULL,
      computed_at INTEGER NOT NULL,
      PRIMARY KEY (subject_id, student_id),
      FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
    )''',
    '''
    CREATE TABLE IF NOT EXISTS bmi_records (
      student_id  TEXT NOT NULL,
      date        TEXT NOT NULL,
      height_cm   REAL NOT NULL,
      weight_kg   REAL NOT NULL,
      recorded_at INTEGER NOT NULL,
      PRIMARY KEY (student_id, date),
      FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
    )''',
    'CREATE INDEX IF NOT EXISTS idx_bmi_records_student ON bmi_records(student_id)',
  ];

  Future<void> _createSchema(DatabaseExecutor db) async {
    for (final statement in _schema) {
      await db.execute(statement);
    }
  }

  /// First-launch data: the teacher row, the default school year with its three
  /// terms, and the built-in grading configurations.
  Future<void> _seed(DatabaseExecutor db) async {
    await db.insert(
      'teachers',
      {
        'id': 'local',
        'name': '',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    for (final config in builtInGradingConfigs) {
      await _writeConfig(db, config, isBuiltin: true);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final activeYear = currentSchoolYear();
    final years = <String>{defaultSchoolYear, activeYear};
    for (final year in years) {
      await db.insert(
        'school_years',
        {
          'id': 'sy-$year',
          'name': year,
          'is_active': year == activeYear ? 1 : 0,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final term in terms) {
        await db.insert(
          'academic_terms',
          {
            'id': 'sy-$year::t$term',
            'school_year': year,
            'term': term,
            'start_date': _defaultTermStart(year, term),
            'end_date': _defaultTermEnd(year, term),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await db.insert(
      'kv',
      {'key': SettingsKey.schemaVersion, 'value': '$schemaVersion'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Rough term boundaries for a Philippine school year (Aug–May).
  static String _defaultTermStart(String schoolYear, int term) {
    final startYear = int.tryParse(schoolYear.split('-').first) ?? 2026;
    return switch (term) {
      1 => '$startYear-08-01',
      2 => '${startYear + 1}-01-05',
      _ => '${startYear + 1}-04-01',
    };
  }

  static String _defaultTermEnd(String schoolYear, int term) {
    final startYear = int.tryParse(schoolYear.split('-').first) ?? 2026;
    return switch (term) {
      1 => '${startYear + 1}-01-04',
      2 => '${startYear + 1}-03-31',
      _ => '${startYear + 1}-05-31',
    };
  }

  /* -------------------------------- migration ------------------------------- */

  /// Upgrade the quarterly (v1) database to the three-term schema.
  ///
  /// Every record is carried over: sections become classes, quarterly sheets
  /// become term assessments (Q1–Q3 map to Terms 1–3; Q4 items are kept under
  /// Term 3 so no score is lost), the five old components collapse into the
  /// WW/PT/TE categories, and each subject keeps the weights it was graded
  /// with. The old tables are dropped only after the copy inside the same
  /// upgrade transaction succeeds.
  /// Tables written by the quarterly (v1) build.
  static const List<String> _legacyTables = [
    'sections',
    'students',
    'subjects',
    'sheets',
    'sheet_items',
    'scores',
    'attendance_days',
    'attendance_marks',
    'bmi',
  ];

  Future<void> _migrateV1ToV2(Database db) async {
    // Move the old tables aside first so the new schema (and its indexes) can
    // be created cleanly, then copy every row across and drop the old tables
    // at the end of the same upgrade transaction.
    final hasOldSections = await _tableExists(db, 'sections');
    if (hasOldSections) {
      for (final table in _legacyTables) {
        if (await _tableExists(db, table)) {
          await db.execute('ALTER TABLE $table RENAME TO _v1_$table');
        }
      }
    }

    await _createSchema(db);

    if (!hasOldSections) {
      await db.insert(
        'kv',
        {'key': SettingsKey.schemaVersion, 'value': '$schemaVersion'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // classes <- sections
    for (final row in await db.rawQuery('SELECT * FROM _v1_sections')) {
      await db.insert(
        'classes',
        {
          'id': row['id'],
          'grade_level': row['grade_level'],
          'section': row['section'],
          'school_year': row['school_year'],
          'curriculum': Curriculum.existingShs.name,
          'archived': 0,
          'created_at': row['created_at'] ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _ensureYear(db, row['school_year']! as String, now);
    }

    // students <- students (+ enrolment rows)
    for (final row in await db.rawQuery('SELECT * FROM _v1_students')) {
      await db.insert(
        'students',
        {
          'id': row['id'],
          'class_id': row['section_id'],
          'seat_number': row['seat_number'] ?? 0,
          'full_name': row['full_name'] ?? '',
          'lrn': row['lrn'] ?? '',
          'gender': row['gender'] ?? '',
          'birthday': row['birthday'] ?? '',
          'guardian_name': row['guardian_name'] ?? '',
          'guardian_contact': row['guardian_contact'] ?? '',
          'archived': 0,
          'created_at': row['created_at'] ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'class_students',
        {
          'class_id': row['section_id'],
          'student_id': row['id'],
          'enrolled_at': row['created_at'] ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // subjects <- subjects, keeping their own weights as a private config
    for (final row in await db.rawQuery('SELECT * FROM _v1_subjects')) {
      final subjectId = row['id']! as String;
      final configId = _subjectConfigId(subjectId);
      final weights = _decodeWeights(row['weights'] as String?);
      await _writeConfig(
        db,
        GradingConfig(
          id: configId,
          name: 'Migrated — ${row['name']}',
          curriculum: Curriculum.existingShs,
          weights: weights,
          transmute: (row['transmute'] as num? ?? 0) == 1,
        ),
      );
      await db.insert(
        'subjects',
        {
          'id': subjectId,
          'class_id': row['section_id'],
          'name': row['name'] ?? '',
          'teacher_name': row['teacher_name'] ?? '',
          'term_start': 1,
          'term_end': 3,
          'config_id': configId,
          'created_at': row['created_at'] ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // assessments <- sheets + sheet_items
    if (await _tableExists(db, '_v1_sheets') &&
        await _tableExists(db, '_v1_sheet_items')) {
      final sheets = await db.rawQuery('SELECT * FROM _v1_sheets');
      final subjectBySheet = <String, String>{
        for (final row in sheets)
          row['id']! as String: row['subject_id']! as String,
      };
      final termBySheet = <String, int>{
        for (final row in sheets)
          row['id']! as String: _termForQuarter((row['quarter'] as num).toInt()),
      };
      final items = await db.rawQuery(
        'SELECT * FROM _v1_sheet_items ORDER BY sheet_id, position',
      );
      for (final row in items) {
        final sheetId = row['sheet_id']! as String;
        final subjectId = subjectBySheet[sheetId];
        if (subjectId == null) continue;
        final category = AssessmentCategory.fromName(
              row['component'] as String?,
            ) ??
            AssessmentCategory.writtenWorks;
        await db.insert(
          'assessments',
          {
            'id': row['id'],
            'subject_id': subjectId,
            'term': termBySheet[sheetId] ?? 1,
            'category': category.name,
            'title': row['title'] ?? '',
            'max_score': (row['max_score'] as num? ?? 100).toDouble(),
            'position': row['position'] ?? 0,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // student_scores <- scores
      if (await _tableExists(db, '_v1_scores')) {
        for (final row in await db.rawQuery('SELECT * FROM _v1_scores')) {
          final itemId = row['item_id']! as String;
          try {
            await db.insert(
              'student_scores',
              {
                'assessment_id': itemId,
                'student_id': row['student_id'],
                'value': (row['value'] as num).toDouble(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (_) {
            // orphan score whose assessment no longer exists: skip it
          }
        }
      }
    }

    // attendance <- attendance_days + attendance_marks
    if (await _tableExists(db, '_v1_attendance_days') &&
        await _tableExists(db, '_v1_attendance_marks')) {
      final days = await db.rawQuery('SELECT * FROM _v1_attendance_days');
      final dayInfo = <String, (String, String, int)>{
        for (final row in days)
          row['id']! as String: (
            row['section_id']! as String,
            row['date']! as String,
            (row['marked_at'] as num? ?? 0).toInt(),
          ),
      };
      for (final row in await db.rawQuery('SELECT * FROM _v1_attendance_marks')) {
        final day = dayInfo[row['day_id']! as String];
        if (day == null) continue;
        try {
          await db.insert(
            'attendance',
            {
              'class_id': day.$1,
              'date': day.$2,
              'student_id': row['student_id'],
              'status': row['status'] ?? AttendanceStatus.present.name,
              'marked_at': day.$3,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {
          // mark for a student that no longer exists: skip it
        }
      }
    }

    // bmi_records <- bmi
    if (await _tableExists(db, '_v1_bmi')) {
      for (final row in await db.rawQuery('SELECT * FROM _v1_bmi')) {
        try {
          await db.insert(
            'bmi_records',
            {
              'student_id': row['student_id'],
              'date': row['date'],
              'height_cm': row['height_cm'] ?? 0,
              'weight_kg': row['weight_kg'] ?? 0,
              'recorded_at': row['recorded_at'] ?? now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {
          // measurement for a student that no longer exists: skip it
        }
      }
    }

    // Keep the teacher's settings that lived in kv.
    for (final row in await db.rawQuery('SELECT key, value FROM kv')) {
      final key = row['key'] as String?;
      if (key == SettingsKey.teacherName && row['value'] != null) {
        await db.update(
          'teachers',
          {'name': row['value']},
          where: 'id = ?',
          whereArgs: ['local'],
        );
      }
    }

    // Old tables are only dropped once everything above has been copied.
    for (final table in _legacyTables) {
      await db.execute('DROP TABLE IF EXISTS _v1_$table');
    }

    await db.insert(
      'kv',
      {'key': SettingsKey.schemaVersion, 'value': '$schemaVersion'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static int _termForQuarter(int quarter) =>
      quarter < 1 ? 1 : (quarter > 3 ? 3 : quarter);

  static Weights _decodeWeights(String? raw) {
    final weights = <AssessmentCategory, double>{
      for (final category in AssessmentCategory.values) category: 0,
    };
    if (raw == null || raw.isEmpty) {
      return Map<AssessmentCategory, double>.from(depedAcademicWeights);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return Map<AssessmentCategory, double>.from(depedAcademicWeights);
      }
      final old = <String, double>{
        for (final entry in decoded.entries)
          if (entry.value is num) '${entry.key}': (entry.value as num).toDouble(),
      };
      String canonical(String key) => switch (key) {
            'quizzes' || 'assignments' || 'activities' || 'writtenWorks' =>
              'writtenWorks',
            'performanceTasks' => 'performanceTasks',
            'examinations' || 'termExam' => 'termExam',
            _ => key,
          };
      for (final entry in old.entries) {
        final category = AssessmentCategory.fromName(canonical(entry.key));
        if (category != null) {
          weights[category] = (weights[category] ?? 0) + entry.value;
        }
      }
      final total = weights.values.fold<double>(0, (sum, value) => sum + value);
      if (total <= 0) {
        return Map<AssessmentCategory, double>.from(depedAcademicWeights);
      }
      return weights;
    } catch (_) {
      return Map<AssessmentCategory, double>.from(depedAcademicWeights);
    }
  }

  Future<bool> _tableExists(DatabaseExecutor db, String name) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [name],
    );
    return rows.isNotEmpty;
  }

  Future<void> _ensureYear(
    DatabaseExecutor db,
    String schoolYear,
    int now,
  ) async {
    await db.insert(
      'school_years',
      {
        'id': 'sy-$schoolYear',
        'name': schoolYear,
        'is_active': 0,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    for (final term in terms) {
      await db.insert(
        'academic_terms',
        {
          'id': 'sy-$schoolYear::t$term',
          'school_year': schoolYear,
          'term': term,
          'start_date': _defaultTermStart(schoolYear, term),
          'end_date': _defaultTermEnd(schoolYear, term),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static String _subjectConfigId(String subjectId) => 'subj:$subjectId';

  /* ------------------------------ row mappers ------------------------------ */

  Section _section(Map<String, Object?> row) => Section(
        id: row['id']! as String,
        gradeLevel: row['grade_level']! as String,
        section: row['section']! as String,
        schoolYear: row['school_year']! as String,
        curriculum: Curriculum.fromName(row['curriculum'] as String?),
        archived: (row['archived'] as num? ?? 0) == 1,
        createdAt: (row['created_at']! as num).toInt(),
      );

  Student _student(Map<String, Object?> row) => Student(
        id: row['id']! as String,
        sectionId: row['class_id']! as String,
        seatNumber: (row['seat_number'] as num?)?.toInt() ?? 0,
        fullName: row['full_name']! as String,
        lrn: (row['lrn'] as String?) ?? '',
        gender: (row['gender'] as String?) ?? '',
        birthday: (row['birthday'] as String?) ?? '',
        guardianName: (row['guardian_name'] as String?) ?? '',
        guardianContact: (row['guardian_contact'] as String?) ?? '',
        archived: (row['archived'] as num? ?? 0) == 1,
        createdAt: (row['created_at']! as num).toInt(),
      );

  Subject _subject(
    Map<String, Object?> row,
    Map<String, GradingConfig> configs,
  ) {
    final config = configs[row['config_id'] as String? ?? ''];
    return Subject(
      id: row['id']! as String,
      sectionId: row['class_id']! as String,
      name: row['name']! as String,
      teacherName: (row['teacher_name'] as String?) ?? '',
      weights: config?.weights ??
          Map<AssessmentCategory, double>.from(depedAcademicWeights),
      transmute: config?.transmute ?? true,
      termStart: (row['term_start'] as num? ?? 1).toInt(),
      termEnd: (row['term_end'] as num? ?? 3).toInt(),
      configId: (row['config_id'] as String?) ?? '',
      createdAt: (row['created_at']! as num).toInt(),
    );
  }

  /* ------------------------------- config IO -------------------------------- */

  Future<void> _writeConfig(
    DatabaseExecutor db,
    GradingConfig config, {
    bool isBuiltin = false,
  }) async {
    await db.insert(
      'grading_configurations',
      {
        'id': config.id,
        'name': config.name,
        'curriculum': config.curriculum.name,
        'transmute': config.transmute ? 1 : 0,
        'is_default': config.isDefault ? 1 : 0,
        'is_builtin': isBuiltin ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    for (final category in AssessmentCategory.values) {
      await db.insert(
        'grading_components',
        {
          'config_id': config.id,
          'category': category.name,
          'weight': config.weights[category] ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /* ----------------------------- single-row writers ------------------------ */

  Future<void> _writeSection(DatabaseExecutor db, Section value) {
    return db.insert('classes', {
      'id': value.id,
      'grade_level': value.gradeLevel,
      'section': value.section,
      'school_year': value.schoolYear,
      'curriculum': value.curriculum.name,
      'archived': value.archived ? 1 : 0,
      'created_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _writeStudent(DatabaseExecutor db, Student value) async {
    await db.insert('students', {
      'id': value.id,
      'class_id': value.sectionId,
      'seat_number': value.seatNumber,
      'full_name': value.fullName,
      'lrn': value.lrn,
      'gender': value.gender,
      'birthday': value.birthday,
      'guardian_name': value.guardianName,
      'guardian_contact': value.guardianContact,
      'archived': value.archived ? 1 : 0,
      'created_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('class_students', {
      'class_id': value.sectionId,
      'student_id': value.id,
      'enrolled_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _writeSubject(
    DatabaseExecutor db,
    Subject value, {
    bool writeConfig = true,
  }) async {
    if (writeConfig) {
      await _writeConfig(
        db,
        GradingConfig(
          id: _subjectConfigId(value.id),
          name: 'Subject — ${value.name}',
          curriculum: Curriculum.existingShs,
          weights: value.weights,
          transmute: value.transmute,
        ),
      );
    }
    await db.insert('subjects', {
      'id': value.id,
      'class_id': value.sectionId,
      'name': value.name,
      'teacher_name': value.teacherName,
      'term_start': value.termStart,
      'term_end': value.termEnd,
      'config_id': _subjectConfigId(value.id),
      'created_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _writeAssessment(
    DatabaseExecutor db,
    String subjectId,
    int term,
    AssessmentItem value,
    int position,
  ) {
    return db.insert('assessments', {
      'id': value.id,
      'subject_id': subjectId,
      'term': term,
      'category': value.category.name,
      'title': value.title,
      'max_score': value.max,
      'position': position,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _writeSetting(
    DatabaseExecutor db,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await db.delete('kv', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await db.insert(
      'kv',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /* ------------------------------- public writes --------------------------- */

  void saveSetting(String key, String? value) {
    _enqueue<void>((db) => _writeSetting(db, key, value));
  }

  void putSection(Section value) {
    _enqueue<void>((db) => _writeSection(db, value));
  }

  /// Deletes a class with all of its records (used only after confirmation).
  void removeSection(String id) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await txn.delete('classes', where: 'id = ?', whereArgs: [id]);
      });
    });
  }

  void putStudent(Student value) {
    _enqueue<void>((db) => _writeStudent(db, value));
  }

  void removeStudent(String id) {
    _enqueue<void>((db) => db.delete('students', where: 'id = ?', whereArgs: [id]));
  }

  void putSubject(Subject value) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await _writeSubject(txn, value);
      });
    });
  }

  void removeSubject(String id) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);
        await txn.delete(
          'grading_configurations',
          where: 'id = ?',
          whereArgs: [_subjectConfigId(id)],
        );
      });
    });
  }

  /// Saves an assessment and (optionally) its scores in one transaction.
  void putAssessment(
    String subjectId,
    int term,
    AssessmentItem value,
    int position, {
    Map<String, double> scores = const {},
  }) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await _writeAssessment(txn, subjectId, term, value, position);
        for (final entry in scores.entries) {
          await txn.insert(
            'student_scores',
            {
              'assessment_id': value.id,
              'student_id': entry.key,
              'value': entry.value,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    });
  }

  void removeAssessment(String id) {
    _enqueue<void>(
      (db) => db.delete('assessments', where: 'id = ?', whereArgs: [id]),
    );
  }

  /// Saves a score keyed `${sheetId}|${studentId}|${itemId}`; null clears it.
  void saveScore(String key, double? value) {
    final parts = key.split('|');
    if (parts.length != 3) return;
    final itemId = parts[2];
    final studentId = parts[1];
    _enqueue<void>((db) async {
      if (value == null || value.isNaN) {
        await db.delete(
          'student_scores',
          where: 'assessment_id = ? AND student_id = ?',
          whereArgs: [itemId, studentId],
        );
        return;
      }
      await db.insert(
        'student_scores',
        {'assessment_id': itemId, 'student_id': studentId, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  void putAttendanceDay(AttendanceDay value) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await txn.delete(
          'attendance',
          where: 'class_id = ? AND date = ?',
          whereArgs: [value.sectionId, value.date],
        );
        for (final entry in value.statuses.entries) {
          await txn.insert(
            'attendance',
            {
              'class_id': value.sectionId,
              'date': value.date,
              'student_id': entry.key,
              'status': entry.value.name,
              'marked_at': value.markedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    });
  }

  void removeAttendanceDay(String id) {
    final parts = id.split('::');
    if (parts.length != 2) return;
    _enqueue<void>(
      (db) => db.delete(
        'attendance',
        where: 'class_id = ? AND date = ?',
        whereArgs: [parts[0], parts[1]],
      ),
    );
  }

  void putBmi(BmiRecord value) {
    _enqueue<void>((db) {
      return db.insert(
        'bmi_records',
        {
          'student_id': value.studentId,
          'date': value.date,
          'height_cm': value.heightCm,
          'weight_kg': value.weightKg,
          'recorded_at': value.recordedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  void removeBmi(String studentId, String date) {
    _enqueue<void>(
      (db) => db.delete(
        'bmi_records',
        where: 'student_id = ? AND date = ?',
        whereArgs: [studentId, date],
      ),
    );
  }

  /// Replaces every term grade of a subject for one term in a transaction.
  void saveTermGrades(List<TermGradeRecord> records, {int? term, String? subjectId}) {
    if (records.isEmpty && (term == null || subjectId == null)) return;
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        if (term != null && subjectId != null) {
          await txn.delete(
            'term_grades',
            where: 'subject_id = ? AND term = ?',
            whereArgs: [subjectId, term],
          );
        }
        for (final record in records) {
          await txn.insert(
            'term_grades',
            {
              'subject_id': record.subjectId,
              'term': record.term,
              'student_id': record.studentId,
              'initial_grade': record.initialGrade,
              'term_grade': record.termGrade,
              'computed_at': record.computedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    });
  }

  void saveFinalGrades(List<FinalGradeRecord> records, {required String subjectId}) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await txn.delete(
          'final_grades',
          where: 'subject_id = ?',
          whereArgs: [subjectId],
        );
        for (final record in records) {
          await txn.insert(
            'final_grades',
            {
              'subject_id': record.subjectId,
              'student_id': record.studentId,
              'grade': record.grade,
              'computed_at': record.computedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    });
  }

  void saveGradingConfig(GradingConfig config) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await _writeConfig(txn, config, isBuiltin: true);
      });
    });
  }

  void putSchoolYear(SchoolYear value) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        await txn.insert(
          'school_years',
          {
            'id': value.id,
            'name': value.name,
            'is_active': value.isActive ? 1 : 0,
            'created_at': value.createdAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _ensureYear(txn, value.name, value.createdAt);
      });
    });
  }

  void putAcademicTerms(List<AcademicTerm> values) {
    _enqueue<void>((db) async {
      await db.transaction((txn) async {
        for (final value in values) {
          await txn.insert(
            'academic_terms',
            {
              'id': value.id,
              'school_year': value.schoolYear,
              'term': value.term,
              'start_date': value.start,
              'end_date': value.end,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    });
  }

  void saveTeacherName(String name) {
    _enqueue<void>((db) async {
      await db.update(
        'teachers',
        {'name': name},
        where: 'id = ?',
        whereArgs: ['local'],
      );
      await _writeSetting(db, SettingsKey.teacherName, name);
    });
  }

  /* ---------------------------------- reads --------------------------------- */

  /// Reads every table back into the shape the store expects.
  Future<PersistedData> loadAll() => _enqueue(_loadAll, reportErrors: false);

  Future<PersistedData> _loadAll(Database db) async {
    final kvRows = await db.rawQuery('SELECT key, value FROM kv');
    final kv = <String, String>{
      for (final row in kvRows)
        if (row['value'] != null) row['key']! as String: row['value']! as String,
    };

    String teacherName = '';
    final teacherRows = await db.rawQuery(
      "SELECT name FROM teachers WHERE id = 'local' LIMIT 1",
    );
    if (teacherRows.isNotEmpty) {
      teacherName = (teacherRows.first['name'] as String?) ?? '';
    }
    if (teacherName.isEmpty) {
      teacherName = kv[SettingsKey.teacherName] ?? '';
    }

    final schoolYears = <String, SchoolYear>{};
    for (final row in await db.rawQuery('SELECT * FROM school_years')) {
      final value = SchoolYear(
        id: row['id']! as String,
        name: row['name']! as String,
        isActive: (row['is_active'] as num? ?? 0) == 1,
        createdAt: (row['created_at']! as num).toInt(),
      );
      schoolYears[value.id] = value;
    }

    final academicTerms = <AcademicTerm>[
      for (final row in await db.rawQuery(
        'SELECT * FROM academic_terms ORDER BY school_year DESC, term',
      ))
        AcademicTerm(
          id: row['id']! as String,
          schoolYear: row['school_year']! as String,
          term: (row['term']! as num).toInt(),
          start: (row['start_date'] as String?) ?? '',
          end: (row['end_date'] as String?) ?? '',
        ),
    ];

    // grading configurations + their components
    final gradingConfigs = <String, GradingConfig>{};
    final components = <String, Weights>{};
    for (final row in await db.rawQuery('SELECT * FROM grading_components')) {
      final configId = row['config_id']! as String;
      final category = AssessmentCategory.fromName(row['category'] as String?);
      if (category == null) continue;
      (components[configId] ??= <AssessmentCategory, double>{})[category] =
          (row['weight'] as num? ?? 0).toDouble();
    }
    for (final row in await db.rawQuery('SELECT * FROM grading_configurations')) {
      final id = row['id']! as String;
      final weights = components[id] ??
          Map<AssessmentCategory, double>.from(depedAcademicWeights);
      var total = 0.0;
      for (final category in AssessmentCategory.values) {
        total += weights[category] ?? 0;
      }
      final filled = <AssessmentCategory, double>{
        for (final category in AssessmentCategory.values)
          category: weights[category] ?? 0,
      };
      gradingConfigs[id] = GradingConfig(
        id: id,
        name: row['name']! as String,
        curriculum: Curriculum.fromName(row['curriculum'] as String?),
        weights: total > 0
            ? filled
            : Map<AssessmentCategory, double>.from(depedAcademicWeights),
        transmute: (row['transmute'] as num? ?? 1) == 1,
        isDefault: (row['is_default'] as num? ?? 0) == 1,
      );
    }

    final sections = <String, Section>{};
    for (final row in await db.rawQuery('SELECT * FROM classes')) {
      final value = _section(row);
      sections[value.id] = value;
    }

    final students = <String, Student>{};
    for (final row in await db.rawQuery('SELECT * FROM students')) {
      final value = _student(row);
      students[value.id] = value;
    }

    final subjects = <String, Subject>{};
    for (final row in await db.rawQuery('SELECT * FROM subjects')) {
      final value = _subject(row, gradingConfigs);
      subjects[value.id] = value;
    }

    // assessments -> score sheets
    final sheets = <String, ScoreSheet>{};
    ScoreSheet sheetFor(String subjectId, int term) {
      final id = '$subjectId::t$term';
      return sheets.putIfAbsent(
        id,
        () => ScoreSheet(
          id: id,
          subjectId: subjectId,
          term: term,
          items: {
            for (final category in AssessmentCategory.values)
              category: <AssessmentItem>[],
          },
        ),
      );
    }

    // item id -> sheet id, so scores are attached without rescanning sheets.
    final sheetIdByItem = <String, String>{};
    for (final row in await db.rawQuery(
      'SELECT * FROM assessments ORDER BY subject_id, term, category, position',
    )) {
      final subjectId = row['subject_id']! as String;
      final term = (row['term'] as num? ?? 1).toInt();
      final category = AssessmentCategory.fromName(row['category'] as String?) ??
          AssessmentCategory.writtenWorks;
      final sheet = sheetFor(subjectId, term);
      sheetIdByItem[row['id']! as String] = sheet.id;
      final items = List<AssessmentItem>.from(sheet.items[category]!);
      items.add(AssessmentItem(
        id: row['id']! as String,
        title: row['title']! as String,
        max: (row['max_score']! as num).toDouble(),
        category: category,
      ));
      sheets[sheet.id] = sheet.copyWith(items: {...sheet.items, category: items});
    }

    final scores = <String, double>{};
    for (final row in await db.rawQuery('SELECT * FROM student_scores')) {
      final itemId = row['assessment_id']! as String;
      final studentId = row['student_id']! as String;
      final value = (row['value']! as num).toDouble();
      final sheetId = sheetIdByItem[itemId];
      if (sheetId == null) continue; // orphaned score
      scores['$sheetId|$studentId|$itemId'] = value;
    }

    final attendance = <String, AttendanceDay>{};
    for (final row in await db.rawQuery(
      'SELECT * FROM attendance ORDER BY class_id, date',
    )) {
      final classId = row['class_id']! as String;
      final date = row['date']! as String;
      final id = '$classId::$date';
      final status = AttendanceStatus.fromName(row['status']! as String);
      if (status == null) continue;
      final existing = attendance[id];
      final statuses = existing == null
          ? <String, AttendanceStatus>{}
          : Map<String, AttendanceStatus>.from(existing.statuses);
      statuses[row['student_id']! as String] = status;
      final markedAt = (row['marked_at'] as num? ?? 0).toInt();
      attendance[id] = AttendanceDay(
        id: id,
        sectionId: classId,
        date: date,
        statuses: statuses,
        markedAt: existing == null || markedAt > existing.markedAt
            ? markedAt
            : existing.markedAt,
      );
    }

    final bmi = <String, BmiRecord>{};
    for (final row in await db.rawQuery('SELECT * FROM bmi_records')) {
      final studentId = row['student_id']! as String;
      final date = row['date']! as String;
      bmi['$studentId::$date'] = BmiRecord(
        id: '$studentId::$date',
        studentId: studentId,
        date: date,
        heightCm: (row['height_cm']! as num).toDouble(),
        weightKg: (row['weight_kg']! as num).toDouble(),
        recordedAt: (row['recorded_at']! as num).toInt(),
      );
    }

    final termGrades = <String, TermGradeRecord>{};
    for (final row in await db.rawQuery('SELECT * FROM term_grades')) {
      final record = TermGradeRecord(
        subjectId: row['subject_id']! as String,
        term: (row['term']! as num).toInt(),
        studentId: row['student_id']! as String,
        initialGrade: (row['initial_grade']! as num).toDouble(),
        termGrade: (row['term_grade']! as num).toDouble(),
        computedAt: (row['computed_at']! as num).toInt(),
      );
      termGrades['${record.subjectId}|${record.term}|${record.studentId}'] =
          record;
    }

    final finalGrades = <String, FinalGradeRecord>{};
    for (final row in await db.rawQuery('SELECT * FROM final_grades')) {
      final record = FinalGradeRecord(
        subjectId: row['subject_id']! as String,
        studentId: row['student_id']! as String,
        grade: (row['grade']! as num).toDouble(),
        computedAt: (row['computed_at']! as num).toInt(),
      );
      finalGrades['${record.subjectId}|${record.studentId}'] = record;
    }

    return PersistedData(
      teacherName: teacherName,
      activeSectionId: kv[SettingsKey.activeSectionId],
      activeTerm: int.tryParse(kv[SettingsKey.activeTerm] ?? '') ?? 1,
      activeSchoolYear: kv[SettingsKey.activeSchoolYear],
      schoolLogoUri: kv[SettingsKey.schoolLogoUri],
      sections: sections,
      students: students,
      subjects: subjects,
      sheets: sheets,
      scores: scores,
      attendance: attendance,
      bmi: bmi,
      gradingConfigs: gradingConfigs,
      schoolYears: schoolYears,
      academicTerms: academicTerms,
      termGrades: termGrades,
      finalGrades: finalGrades,
      kv: kv,
    );
  }

  /// Reads the record counts and schema version of a backup file without
  /// touching the live database (used before a restore).
  Future<BackupPreview> inspectBackup(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('The selected backup file is missing.');
    }
    final db = await openDatabase(path, readOnly: true);
    try {
      final versionRows = await db.rawQuery('PRAGMA user_version');
      final version = versionRows.isEmpty
          ? 0
          : (versionRows.first.values.first as num?)?.toInt() ?? 0;
      final counts = <String, int>{};
      for (final table in const [
        'classes',
        'students',
        'subjects',
        'assessments',
        'student_scores',
        'attendance',
        'bmi_records',
      ]) {
        try {
          final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
          counts[table] = (rows.first['c'] as num?)?.toInt() ?? 0;
        } catch (_) {
          counts[table] = 0;
        }
      }
      return BackupPreview(schemaVersion: version, counts: counts);
    } finally {
      await db.close();
    }
  }

  /* ------------------------------- backup ---------------------------------- */

  /// Copies the live database file to [destination] (a full backup).
  Future<File> backupTo(String destination) async {
    // Make sure every queued write has landed before copying the file.
    await _enqueue((db) async => db.rawQuery('PRAGMA wal_checkpoint(FULL)'));
    final source = await databaseFilePath;
    final file = File(source);
    final target = File(destination);
    await target.parent.create(recursive: true);
    return file.copy(target.path);
  }

  /// Closes the open connection so the file can be replaced or deleted.
  Future<void> close() async {
    final future = _future;
    _future = null;
    if (future == null) return;
    try {
      await (await future).close();
    } catch (_) {
      // Already closed or never opened — nothing left to release.
    }
  }

  /// Replaces the live database with [source] and reopens it.
  ///
  /// The caller must have confirmed this destructive step with the teacher.
  Future<void> restoreFrom(String source) async {
    final backup = File(source);
    if (!await backup.exists()) {
      throw const FileSystemException('The selected backup file is missing.');
    }
    // Drain the queue, close the current database, swap the file, reopen.
    await _enqueue((db) async => true);
    await close();
    final target = await databaseFilePath;
    await backup.copy(target);
    await _database; // reopen and run migrations if the backup is older
  }

  /* --------------------------- legacy app import ---------------------------- */

  /// One-time import of the JSON blob the earlier React Native build kept in
  /// its AsyncStorage, so no class, score or attendance record is lost when
  /// switching to Flutter. Only possible when the Flutter build is installed
  /// over the old app (same bundle id); otherwise it finds nothing and simply
  /// marks itself done.
  Future<void> migrateLegacyStorage() async {
    final alreadyDone = await _enqueue((db) async {
      final rows = await db.rawQuery(
        'SELECT value FROM kv WHERE key = ?',
        [SettingsKey.legacyMigrated],
      );
      return rows.isNotEmpty && rows.first['value'] == '1';
    });
    if (alreadyDone) return;

    final legacy = await _readLegacyJson();

    await _enqueue<void>((db) async {
      await db.transaction((txn) async {
        if (legacy != null) await _importLegacyJson(txn, legacy);
        await _writeSetting(txn, SettingsKey.legacyMigrated, '1');
      });
    });

    await _deleteLegacyBackup();
  }

  Future<void> _importLegacyJson(
    Transaction txn,
    Map<String, dynamic> state,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, dynamic> mapOf(Object? value) =>
        value is Map<String, dynamic> ? value : const <String, dynamic>{};

    // classes
    for (final entry in mapOf(state['sections']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final schoolYear = (value['schoolYear'] as String?) ?? defaultSchoolYear;
      await _ensureYear(txn, schoolYear, now);
      await txn.insert(
        'classes',
        {
          'id': value['id'] ?? entry.key,
          'grade_level': value['gradeLevel'] ?? '',
          'section': value['section'] ?? '',
          'school_year': schoolYear,
          'curriculum': Curriculum.existingShs.name,
          'archived': 0,
          'created_at': (value['createdAt'] as num?)?.toInt() ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // students
    for (final entry in mapOf(state['students']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      await txn.insert(
        'students',
        {
          'id': value['id'] ?? entry.key,
          'class_id': value['sectionId'] ?? '',
          'seat_number': (value['seatNumber'] as num?)?.toInt() ?? 0,
          'full_name': value['fullName'] ?? '',
          'lrn': value['lrn'] ?? '',
          'gender': value['gender'] ?? '',
          'birthday': value['birthday'] ?? '',
          'guardian_name': value['guardianName'] ?? '',
          'guardian_contact': value['guardianContact'] ?? '',
          'archived': 0,
          'created_at': (value['createdAt'] as num?)?.toInt() ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // subjects with their own config
    for (final entry in mapOf(state['subjects']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final id = (value['id'] as String?) ?? entry.key;
      final configId = _subjectConfigId(id);
      final weights = <AssessmentCategory, double>{
        for (final category in AssessmentCategory.values) category: 0,
      };
      final rawWeights = mapOf(value['weights']);
      for (final weightEntry in rawWeights.entries) {
        final category = AssessmentCategory.fromName(weightEntry.key);
        if (category != null && weightEntry.value is num) {
          weights[category] =
              (weights[category] ?? 0) + (weightEntry.value as num).toDouble();
        }
      }
      final total = weights.values.fold<double>(0, (sum, v) => sum + v);
      await _writeConfig(
        txn,
        GradingConfig(
          id: configId,
          name: 'Imported — ${value['name']}',
          curriculum: Curriculum.existingShs,
          weights: total > 0
              ? weights
              : Map<AssessmentCategory, double>.from(depedAcademicWeights),
          transmute: value['transmute'] == true,
        ),
      );
      await txn.insert(
        'subjects',
        {
          'id': id,
          'class_id': value['sectionId'] ?? '',
          'name': value['name'] ?? '',
          'teacher_name': value['teacherName'] ?? '',
          'term_start': 1,
          'term_end': 3,
          'config_id': configId,
          'created_at': (value['createdAt'] as num?)?.toInt() ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // sheets of this subject
      final sheetPrefix = '$id::';
      for (final sheetEntry in mapOf(state['sheets']).entries) {
        final sheetId = sheetEntry.key;
        if (!sheetId.startsWith(sheetPrefix)) continue;
        final sheet = sheetEntry.value;
        if (sheet is! Map<String, dynamic>) continue;
        final term = _termForQuarter(
          (sheet['quarter'] as num?)?.toInt() ?? 1,
        );
        var position = 0;
        for (final itemEntry in mapOf(sheet['items']).entries) {
          final category = AssessmentCategory.fromName(itemEntry.key);
          final list = itemEntry.value;
          if (category == null || list is! List) continue;
          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;
            final itemId = (item['id'] as String?) ?? '';
            if (itemId.isEmpty) continue;
            await _writeAssessment(
              txn,
              id,
              term,
              AssessmentItem(
                id: itemId,
                title: (item['title'] as String?) ?? '',
                max: (item['max'] as num?)?.toDouble() ?? 100,
                category: category,
              ),
              position++,
            );
          }
        }
      }
    }

    // scores
    for (final entry in mapOf(state['scores']).entries) {
      final value = entry.value;
      if (value is! num) continue;
      final parts = entry.key.split('|');
      if (parts.length != 3) continue;
      try {
        await txn.insert(
          'student_scores',
          {
            'assessment_id': parts[2],
            'student_id': parts[1],
            'value': value.toDouble(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }

    // attendance
    for (final entry in mapOf(state['attendance']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final classId = (value['sectionId'] as String?) ?? '';
      final date = (value['date'] as String?) ?? '';
      final markedAt = (value['markedAt'] as num?)?.toInt() ?? now;
      for (final mark in mapOf(value['statuses']).entries) {
        final status = mark.value is String
            ? AttendanceStatus.fromName(mark.value as String)
            : null;
        if (status == null) continue;
        try {
          await txn.insert(
            'attendance',
            {
              'class_id': classId,
              'date': date,
              'student_id': mark.key,
              'status': status.name,
              'marked_at': markedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {}
      }
    }

    // bmi
    for (final entry in mapOf(state['bmi']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      try {
        await txn.insert(
          'bmi_records',
          {
            'student_id': value['studentId'] ?? '',
            'date': value['date'] ?? '',
            'height_cm': (value['heightCm'] as num?)?.toDouble() ?? 0,
            'weight_kg': (value['weightKg'] as num?)?.toDouble() ?? 0,
            'recorded_at': (value['recordedAt'] as num?)?.toInt() ?? now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }

    if (state['teacherName'] is String) {
      final name = state['teacherName'] as String;
      await txn.update(
        'teachers',
        {'name': name},
        where: 'id = ?',
        whereArgs: ['local'],
      );
    }
  }

  /// Candidate locations of the previous build's AsyncStorage database.
  Future<List<String>> _legacyDatabasePaths() async {
    final candidates = <String>[];
    try {
      candidates.add(p.join(await getDatabasesPath(), 'RKStorage'));
    } catch (_) {}
    try {
      candidates.add(p.join(await getDatabasesPath(), 'AsyncStorage'));
    } catch (_) {}
    try {
      final support = await getApplicationSupportDirectory();
      candidates
        ..add(p.join(support.path, 'RKStorage'))
        ..add(p.join(support.path, 'Library', 'RKStorage'));
    } catch (_) {}
    return candidates;
  }

  Future<Map<String, dynamic>?> _readLegacyJson() async {
    for (final path in await _legacyDatabasePaths()) {
      if (!File(path).existsSync()) continue;
      try {
        final legacyDb = await openDatabase(path, readOnly: true);
        try {
          final rows = await legacyDb.rawQuery(
            'SELECT value FROM catalystLocalStorage WHERE key = ?',
            [_legacyKey],
          );
          if (rows.isEmpty) continue;
          final raw = rows.first['value'];
          final text = raw is String
              ? raw
              : raw is List<int>
                  ? utf8.decode(raw, allowMalformed: true)
                  : null;
          if (text == null || text.isEmpty) continue;
          final decoded = jsonDecode(text);
          if (decoded is! Map<String, dynamic>) continue;
          final state = decoded['state'];
          return state is Map<String, dynamic> ? state : decoded;
        } finally {
          await legacyDb.close();
        }
      } catch (_) {
        // not the layout we expected — try the next candidate
      }
    }
    return null;
  }

  Future<void> _deleteLegacyBackup() async {
    for (final path in await _legacyDatabasePaths()) {
      if (!File(path).existsSync()) continue;
      try {
        final legacyDb = await openDatabase(path);
        await legacyDb.delete(
          'catalystLocalStorage',
          where: 'key = ?',
          whereArgs: [_legacyKey],
        );
        await legacyDb.close();
      } catch (_) {
        // leaving the old copy behind is harmless: it is never read again
      }
    }
  }
}
