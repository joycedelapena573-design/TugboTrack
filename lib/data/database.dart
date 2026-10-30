/// SQLite storage layer for TIS ClassTrack.
///
/// Every collection the app keeps offline lives in one on-device SQLite file
/// (`classtrack.db`) with a dedicated table per collection:
///
///   kv               teacher name, active section, chosen logo, migration flag
///   sections         one row per class / section
///   students         one row per learner (LRN, birthday, guardian, ...)
///   subjects         one row per subject taught in a section
///   sheets           one row per subject + quarter score sheet
///   sheet_items      the quizzes, assignments, activities, PTs and exams
///   scores           one row per student score
///   attendance_days  one row per section + date
///   attendance_marks one row per student mark for that day
///   bmi              one row per student measurement
///
/// [AppState] is the in-memory source of truth the UI renders from and mirrors
/// each change into these tables through the `put*` methods; [loadAll] reads
/// them back on launch. All work is serialized on a single queue so writes keep
/// their order, nothing blocks the UI, and the app stays fully usable without a
/// network connection.
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
  static const schoolLogoUri = 'schoolLogoUri';
  static const legacyMigrated = 'legacyMigrated';
}

/// Key under which the earlier React Native build stored the whole state.
const String _legacyKey = 'tis-classtrack';

/// Everything the store persists, read back from the database.
class PersistedData {
  const PersistedData({
    required this.teacherName,
    required this.activeSectionId,
    required this.schoolLogoUri,
    required this.sections,
    required this.students,
    required this.subjects,
    required this.sheets,
    required this.scores,
    required this.attendance,
    required this.bmi,
  });

  final String teacherName;
  final String? activeSectionId;
  final String? schoolLogoUri;
  final Map<String, Section> sections;
  final Map<String, Student> students;
  final Map<String, Subject> subjects;
  final Map<String, ScoreSheet> sheets;
  final ScoreMap scores;
  final Map<String, AttendanceDay> attendance;
  final Map<String, BmiRecord> bmi;
}

class DatabaseService {
  DatabaseService([this._databasePath]);

  static final DatabaseService instance = DatabaseService();

  final String? _databasePath;
  Future<Database>? _future;
  Future<dynamic> _queue = Future<dynamic>.value();

  Future<Database> get _database async {
    if (_future != null) return _future!;
    final future = () async {
      final path = _databasePath ??
          p.join(await getDatabasesPath(), 'classtrack.db');
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          for (final statement in _schema) {
            await db.execute(statement);
          }
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
    CREATE TABLE IF NOT EXISTS sections (
      id          TEXT PRIMARY KEY NOT NULL,
      grade_level TEXT NOT NULL,
      section     TEXT NOT NULL,
      school_year TEXT NOT NULL,
      created_at  INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE IF NOT EXISTS students (
      id               TEXT PRIMARY KEY NOT NULL,
      section_id       TEXT NOT NULL,
      seat_number      INTEGER,
      full_name        TEXT NOT NULL,
      lrn              TEXT NOT NULL DEFAULT '',
      gender           TEXT NOT NULL DEFAULT '',
      birthday         TEXT NOT NULL DEFAULT '',
      guardian_name    TEXT NOT NULL DEFAULT '',
      guardian_contact TEXT NOT NULL DEFAULT '',
      created_at       INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_students_section ON students(section_id)',
    '''
    CREATE TABLE IF NOT EXISTS subjects (
      id           TEXT PRIMARY KEY NOT NULL,
      section_id   TEXT NOT NULL,
      name         TEXT NOT NULL,
      teacher_name TEXT NOT NULL DEFAULT '',
      weights      TEXT NOT NULL,
      transmute    INTEGER NOT NULL DEFAULT 0,
      created_at   INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_subjects_section ON subjects(section_id)',
    '''
    CREATE TABLE IF NOT EXISTS sheets (
      id         TEXT PRIMARY KEY NOT NULL,
      subject_id TEXT NOT NULL,
      quarter    INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_sheets_subject ON sheets(subject_id)',
    '''
    CREATE TABLE IF NOT EXISTS sheet_items (
      id        TEXT PRIMARY KEY NOT NULL,
      sheet_id  TEXT NOT NULL,
      component TEXT NOT NULL,
      title     TEXT NOT NULL,
      max_score INTEGER NOT NULL,
      position  INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_items_sheet ON sheet_items(sheet_id)',
    '''
    CREATE TABLE IF NOT EXISTS scores (
      sheet_id   TEXT NOT NULL,
      student_id TEXT NOT NULL,
      item_id    TEXT NOT NULL,
      value      REAL NOT NULL,
      PRIMARY KEY (sheet_id, student_id, item_id)
    )''',
    'CREATE INDEX IF NOT EXISTS idx_scores_sheet ON scores(sheet_id)',
    '''
    CREATE TABLE IF NOT EXISTS attendance_days (
      id         TEXT PRIMARY KEY NOT NULL,
      section_id TEXT NOT NULL,
      date       TEXT NOT NULL,
      marked_at  INTEGER NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_days_section ON attendance_days(section_id)',
    '''
    CREATE TABLE IF NOT EXISTS attendance_marks (
      day_id     TEXT NOT NULL,
      student_id TEXT NOT NULL,
      status     TEXT NOT NULL,
      PRIMARY KEY (day_id, student_id)
    )''',
    'CREATE INDEX IF NOT EXISTS idx_marks_day ON attendance_marks(day_id)',
    '''
    CREATE TABLE IF NOT EXISTS bmi (
      student_id  TEXT NOT NULL,
      date        TEXT NOT NULL,
      height_cm   REAL NOT NULL,
      weight_kg   REAL NOT NULL,
      recorded_at INTEGER NOT NULL,
      PRIMARY KEY (student_id, date)
    )''',
    'CREATE INDEX IF NOT EXISTS idx_bmi_student ON bmi(student_id)',
  ];

  /* ------------------------------ row mappers ------------------------------ */

  Section _section(Map<String, Object?> row) => Section(
        id: row['id']! as String,
        gradeLevel: row['grade_level']! as String,
        section: row['section']! as String,
        schoolYear: row['school_year']! as String,
        createdAt: (row['created_at']! as num).toInt(),
      );

  Student _student(Map<String, Object?> row) => Student(
        id: row['id']! as String,
        sectionId: row['section_id']! as String,
        seatNumber: (row['seat_number'] as num?)?.toInt() ?? 0,
        fullName: row['full_name']! as String,
        lrn: (row['lrn'] as String?) ?? '',
        gender: (row['gender'] as String?) ?? '',
        birthday: (row['birthday'] as String?) ?? '',
        guardianName: (row['guardian_name'] as String?) ?? '',
        guardianContact: (row['guardian_contact'] as String?) ?? '',
        createdAt: (row['created_at']! as num).toInt(),
      );

  Subject _subject(Map<String, Object?> row) {
    Weights weights = Map<ComponentKey, double>.from(defaultWeights);
    try {
      final decoded = jsonDecode(row['weights']! as String);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          final component = ComponentKey.fromName(key);
          if (component != null && value is num) {
            weights[component] = value.toDouble();
          }
        });
      }
    } catch (_) {
      // keep the defaults when a stored weight set is unreadable
    }
    return Subject(
      id: row['id']! as String,
      sectionId: row['section_id']! as String,
      name: row['name']! as String,
      teacherName: (row['teacher_name'] as String?) ?? '',
      weights: weights,
      transmute: (row['transmute'] as num? ?? 0) == 1,
      createdAt: (row['created_at']! as num).toInt(),
    );
  }

  /* ----------------------------- single-row writers ------------------------ */

  Future<void> _writeSection(DatabaseExecutor db, Section value) {
    return db.insert('sections', {
      'id': value.id,
      'grade_level': value.gradeLevel,
      'section': value.section,
      'school_year': value.schoolYear,
      'created_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _writeStudent(DatabaseExecutor db, Student value) {
    return db.insert('students', {
      'id': value.id,
      'section_id': value.sectionId,
      'seat_number': value.seatNumber,
      'full_name': value.fullName,
      'lrn': value.lrn,
      'gender': value.gender,
      'birthday': value.birthday,
      'guardian_name': value.guardianName,
      'guardian_contact': value.guardianContact,
      'created_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _writeSubject(DatabaseExecutor db, Subject value) {
    return db.insert('subjects', {
      'id': value.id,
      'section_id': value.sectionId,
      'name': value.name,
      'teacher_name': value.teacherName,
      'weights': jsonEncode({
        for (final entry in value.weights.entries) entry.key.name: entry.value,
      }),
      'transmute': value.transmute ? 1 : 0,
      'created_at': value.createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Writes a score sheet together with all of its assessment items.
  Future<void> _writeSheet(DatabaseExecutor db, ScoreSheet value) async {
    await db.insert(
      'sheets',
      {'id': value.id, 'subject_id': value.subjectId, 'quarter': value.quarter},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.delete('sheet_items', where: 'sheet_id = ?', whereArgs: [value.id]);
    for (final component in ComponentKey.values) {
      final items = value.items[component] ?? const <AssessmentItem>[];
      for (var position = 0; position < items.length; position += 1) {
        final item = items[position];
        await db.insert(
          'sheet_items',
          {
            'id': item.id,
            'sheet_id': value.id,
            'component': component.name,
            'title': item.title,
            'max_score': item.max,
            'position': position,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  Future<void> _writeAttendanceDay(DatabaseExecutor db, AttendanceDay value) async {
    await db.insert(
      'attendance_days',
      {
        'id': value.id,
        'section_id': value.sectionId,
        'date': value.date,
        'marked_at': value.markedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.delete('attendance_marks', where: 'day_id = ?', whereArgs: [value.id]);
    for (final entry in value.statuses.entries) {
      await db.insert(
        'attendance_marks',
        {
          'day_id': value.id,
          'student_id': entry.key,
          'status': entry.value.name,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _writeBmi(DatabaseExecutor db, BmiRecord value) {
    return db.insert('bmi', {
      'student_id': value.studentId,
      'date': value.date,
      'height_cm': value.heightCm,
      'weight_kg': value.weightKg,
      'recorded_at': value.recordedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _writeSetting(DatabaseExecutor db, String key, String? value) async {
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

  void removeSection(String id) {
    _enqueue<void>((db) => db.delete('sections', where: 'id = ?', whereArgs: [id]));
  }

  void putStudent(Student value) {
    _enqueue<void>((db) => _writeStudent(db, value));
  }

  void removeStudent(String id) {
    _enqueue<void>((db) => db.delete('students', where: 'id = ?', whereArgs: [id]));
  }

  void putSubject(Subject value) {
    _enqueue<void>((db) => _writeSubject(db, value));
  }

  void removeSubject(String id) {
    _enqueue<void>((db) => db.delete('subjects', where: 'id = ?', whereArgs: [id]));
  }

  void putSheet(ScoreSheet value) {
    _enqueue<void>((db) => _writeSheet(db, value));
  }

  void removeSheet(String id) {
    _enqueue<void>((db) async {
      await db.delete('sheet_items', where: 'sheet_id = ?', whereArgs: [id]);
      await db.delete('sheets', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Saves a score keyed `${sheetId}|${studentId}|${itemId}`; null clears it.
  void saveScore(String key, double? value) {
    final parts = key.split('|');
    if (parts.length != 3) return;
    final sheetId = parts[0];
    final studentId = parts[1];
    final itemId = parts[2];
    _enqueue<void>((db) async {
      if (value == null || value.isNaN) {
        await db.delete(
          'scores',
          where: 'sheet_id = ? AND student_id = ? AND item_id = ?',
          whereArgs: [sheetId, studentId, itemId],
        );
        return;
      }
      await db.insert(
        'scores',
        {
          'sheet_id': sheetId,
          'student_id': studentId,
          'item_id': itemId,
          'value': value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  void putAttendanceDay(AttendanceDay value) {
    _enqueue<void>((db) => _writeAttendanceDay(db, value));
  }

  void removeAttendanceDay(String id) {
    _enqueue<void>((db) async {
      await db.delete('attendance_marks', where: 'day_id = ?', whereArgs: [id]);
      await db.delete('attendance_days', where: 'id = ?', whereArgs: [id]);
    });
  }

  void putBmi(BmiRecord value) {
    _enqueue<void>((db) => _writeBmi(db, value));
  }

  void removeBmi(String studentId, String date) {
    _enqueue<void>(
      (db) => db.delete(
        'bmi',
        where: 'student_id = ? AND date = ?',
        whereArgs: [studentId, date],
      ),
    );
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

    final sections = <String, Section>{};
    for (final row in await db.rawQuery('SELECT * FROM sections')) {
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
      final value = _subject(row);
      subjects[value.id] = value;
    }

    final sheets = <String, ScoreSheet>{};
    for (final row in await db.rawQuery('SELECT * FROM sheets')) {
      final id = row['id']! as String;
      sheets[id] = ScoreSheet(
        id: id,
        subjectId: row['subject_id']! as String,
        quarter: (row['quarter']! as num).toInt(),
        items: {
          for (final component in ComponentKey.values) component: <AssessmentItem>[],
        },
      );
    }
    final itemRows = await db.rawQuery(
      'SELECT * FROM sheet_items ORDER BY sheet_id, position',
    );
    for (final row in itemRows) {
      final sheet = sheets[row['sheet_id']! as String];
      final component = ComponentKey.fromName(row['component']! as String);
      if (sheet == null || component == null) continue;
      final items = List<AssessmentItem>.from(sheet.items[component]!);
      items.add(AssessmentItem(
        id: row['id']! as String,
        title: row['title']! as String,
        max: (row['max_score']! as num).toDouble(),
      ));
      sheets[sheet.id] = sheet.copyWith(items: {
        ...sheet.items,
        component: items,
      });
    }

    final scores = <String, double>{};
    for (final row in await db.rawQuery('SELECT * FROM scores')) {
      scores['${row['sheet_id']}|${row['student_id']}|${row['item_id']}'] =
          (row['value']! as num).toDouble();
    }

    final attendance = <String, AttendanceDay>{};
    for (final row in await db.rawQuery('SELECT * FROM attendance_days')) {
      final id = row['id']! as String;
      attendance[id] = AttendanceDay(
        id: id,
        sectionId: row['section_id']! as String,
        date: row['date']! as String,
        statuses: <String, AttendanceStatus>{},
        markedAt: (row['marked_at']! as num).toInt(),
      );
    }
    for (final row in await db.rawQuery('SELECT * FROM attendance_marks')) {
      final day = attendance[row['day_id']! as String];
      final status = AttendanceStatus.fromName(row['status']! as String);
      if (day == null || status == null) continue;
      final statuses = Map<String, AttendanceStatus>.from(day.statuses)
        ..[row['student_id']! as String] = status;
      attendance[day.id] = day.copyWith(statuses: statuses);
    }

    final bmi = <String, BmiRecord>{};
    for (final row in await db.rawQuery('SELECT * FROM bmi')) {
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

    return PersistedData(
      teacherName: kv[SettingsKey.teacherName] ?? '',
      activeSectionId: kv[SettingsKey.activeSectionId],
      schoolLogoUri: kv[SettingsKey.schoolLogoUri],
      sections: sections,
      students: students,
      subjects: subjects,
      sheets: sheets,
      scores: scores,
      attendance: attendance,
      bmi: bmi,
    );
  }

  /* --------------------------- legacy app import ---------------------------- */

  /// One-time import of the JSON blob the earlier React Native build kept in
  /// its AsyncStorage, so no class, score or attendance record is lost when
  /// switching to Flutter. Only possible when the Flutter build is installed
  /// over the old app (same bundle id `ph.tugbo.classtrack`); otherwise it
  /// finds nothing and simply marks itself done.
  ///
  /// The whole import commits in a single transaction together with its
  /// completion flag — a failure leaves nothing behind and is retried on the
  /// next launch, and the legacy copy is only deleted once the data is safely
  /// in SQLite.
  Future<void> migrateLegacyStorage() async {
    final alreadyDone = await _enqueue((db) async {
      final rows = await db.rawQuery(
        'SELECT value FROM kv WHERE key = ?',
        [SettingsKey.legacyMigrated],
      );
      return rows.isNotEmpty && rows.first['value'] == '1';
    });
    if (alreadyDone) return;

    final legacy = await _readLegacyBackup();

    await _enqueue<void>((db) async {
      await db.transaction((txn) async {
        if (legacy != null) await _importLegacy(txn, legacy);
        await _writeSetting(txn, SettingsKey.legacyMigrated, '1');
      });
    });

    await _deleteLegacyBackup();
  }

  Future<void> _importLegacy(Transaction txn, _LegacyState legacy) async {
    for (final value in legacy.sections.values) {
      await _writeSection(txn, value);
    }
    for (final value in legacy.students.values) {
      await _writeStudent(txn, value);
    }
    for (final value in legacy.subjects.values) {
      await _writeSubject(txn, value);
    }
    for (final value in legacy.sheets.values) {
      await _writeSheet(txn, value);
    }      for (final entry in legacy.scores.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 3) continue;
      await txn.insert(
        'scores',
        {
          'sheet_id': parts[0],
          'student_id': parts[1],
          'item_id': parts[2],
          'value': entry.value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final value in legacy.attendance.values) {
      await _writeAttendanceDay(txn, value);
    }
    for (final value in legacy.bmi.values) {
      await _writeBmi(txn, value);
    }
    if (legacy.teacherName != null) {
      await _writeSetting(txn, SettingsKey.teacherName, legacy.teacherName);
    }
    if (legacy.activeSectionId != null) {
      await _writeSetting(txn, SettingsKey.activeSectionId, legacy.activeSectionId);
    }
    if (legacy.schoolLogoUri != null) {
      await _writeSetting(txn, SettingsKey.schoolLogoUri, legacy.schoolLogoUri);
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

  Future<_LegacyState?> _readLegacyBackup() async {
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
          return _parseLegacyState(text);
        } finally {
          await legacyDb.close();
        }
      } catch (_) {
        // not the layout we expected — try the next candidate
      }
    }
    return null;
  }

  _LegacyState? _parseLegacyState(String text) {
    try {
      final decoded = jsonDecode(text);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final state = map['state'] is Map<String, dynamic>
          ? map['state'] as Map<String, dynamic>
          : map;
      return _LegacyState.fromJson(state);
    } catch (error) {
      // ignore: avoid_print
      print('[sqlite] legacy backup is unreadable, skipping import: $error');
      return null;
    }
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

/// Shape of the state blob written by the earlier TypeScript build.
class _LegacyState {
  _LegacyState({
    required this.sections,
    required this.students,
    required this.subjects,
    required this.sheets,
    required this.scores,
    required this.attendance,
    required this.bmi,
    this.teacherName,
    this.activeSectionId,
    this.schoolLogoUri,
  });

  final Map<String, Section> sections;
  final Map<String, Student> students;
  final Map<String, Subject> subjects;
  final Map<String, ScoreSheet> sheets;
  final Map<String, double> scores;
  final Map<String, AttendanceDay> attendance;
  final Map<String, BmiRecord> bmi;
  final String? teacherName;
  final String? activeSectionId;
  final String? schoolLogoUri;

  factory _LegacyState.fromJson(Map<String, dynamic> json) {
    final sections = <String, Section>{};
    for (final entry in _mapOf(json['sections']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      try {
        sections[entry.key] = Section(
          id: value['id']! as String,
          gradeLevel: value['gradeLevel']! as String,
          section: value['section']! as String,
          schoolYear: value['schoolYear']! as String,
          createdAt: (value['createdAt'] as num?)?.toInt() ?? 0,
        );
      } catch (_) {}
    }

    final students = <String, Student>{};
    for (final entry in _mapOf(json['students']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      try {
        students[entry.key] = Student(
          id: value['id']! as String,
          sectionId: value['sectionId']! as String,
          seatNumber: (value['seatNumber'] as num?)?.toInt() ?? 0,
          fullName: (value['fullName'] as String?) ?? '',
          lrn: (value['lrn'] as String?) ?? '',
          gender: (value['gender'] as String?) ?? '',
          birthday: (value['birthday'] as String?) ?? '',
          guardianName: (value['guardianName'] as String?) ?? '',
          guardianContact: (value['guardianContact'] as String?) ?? '',
          createdAt: (value['createdAt'] as num?)?.toInt() ?? 0,
        );
      } catch (_) {}
    }

    final subjects = <String, Subject>{};
    for (final entry in _mapOf(json['subjects']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      try {
        final weights = Map<ComponentKey, double>.from(defaultWeights);
        final rawWeights = value['weights'];
        if (rawWeights is Map<String, dynamic>) {
          rawWeights.forEach((key, weight) {
            final component = ComponentKey.fromName(key);
            if (component != null && weight is num) {
              weights[component] = weight.toDouble();
            }
          });
        }
        subjects[entry.key] = Subject(
          id: value['id']! as String,
          sectionId: value['sectionId']! as String,
          name: (value['name'] as String?) ?? '',
          teacherName: (value['teacherName'] as String?) ?? '',
          weights: weights,
          transmute: value['transmute'] == true,
          createdAt: (value['createdAt'] as num?)?.toInt() ?? 0,
        );
      } catch (_) {}
    }

    final sheets = <String, ScoreSheet>{};
    for (final entry in _mapOf(json['sheets']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      try {
        final items = <ComponentKey, List<AssessmentItem>>{
          for (final component in ComponentKey.values) component: <AssessmentItem>[],
        };
        final rawItems = value['items'];
        if (rawItems is Map<String, dynamic>) {
          rawItems.forEach((key, list) {
            final component = ComponentKey.fromName(key);
            if (component == null || list is! List) return;
            for (final item in list) {
              if (item is! Map<String, dynamic>) continue;
              items[component]!.add(AssessmentItem(
                id: (item['id'] as String?) ?? '',
                title: (item['title'] as String?) ?? '',
                max: (item['max'] as num?)?.toDouble() ?? 0,
              ));
            }
          });
        }
        sheets[entry.key] = ScoreSheet(
          id: value['id']! as String,
          subjectId: value['subjectId']! as String,
          quarter: (value['quarter'] as num?)?.toInt() ?? 1,
          items: items,
        );
      } catch (_) {}
    }

    final scores = <String, double>{};
    _mapOf(json['scores']).forEach((key, value) {
      if (value is num) scores[key] = value.toDouble();
    });

    final attendance = <String, AttendanceDay>{};
    for (final entry in _mapOf(json['attendance']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final statuses = <String, AttendanceStatus>{};
      final rawStatuses = value['statuses'];
      if (rawStatuses is Map<String, dynamic>) {
        rawStatuses.forEach((studentId, status) {
          final parsed = status is String ? AttendanceStatus.fromName(status) : null;
          if (parsed != null) statuses[studentId] = parsed;
        });
      }
      attendance[entry.key] = AttendanceDay(
        id: (value['id'] as String?) ?? entry.key,
        sectionId: (value['sectionId'] as String?) ?? '',
        date: (value['date'] as String?) ?? '',
        statuses: statuses,
        markedAt: (value['markedAt'] as num?)?.toInt() ?? 0,
      );
    }

    final bmi = <String, BmiRecord>{};
    for (final entry in _mapOf(json['bmi']).entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      bmi[entry.key] = BmiRecord(
        id: (value['id'] as String?) ?? entry.key,
        studentId: (value['studentId'] as String?) ?? '',
        date: (value['date'] as String?) ?? '',
        heightCm: (value['heightCm'] as num?)?.toDouble() ?? 0,
        weightKg: (value['weightKg'] as num?)?.toDouble() ?? 0,
        recordedAt: (value['recordedAt'] as num?)?.toInt() ?? 0,
      );
    }

    return _LegacyState(
      sections: sections,
      students: students,
      subjects: subjects,
      sheets: sheets,
      scores: scores,
      attendance: attendance,
      bmi: bmi,
      teacherName: json['teacherName'] is String ? json['teacherName'] as String : null,
      activeSectionId:
          json['activeSectionId'] is String ? json['activeSectionId'] as String : null,
      schoolLogoUri:
          json['schoolLogoUri'] is String ? json['schoolLogoUri'] as String : null,
    );
  }

  static Map<String, dynamic> _mapOf(Object? value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};
}
