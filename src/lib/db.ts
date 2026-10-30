/**
 * SQLite storage layer for TIS ClassTrack.
 *
 * Every collection the app keeps offline lives in one on-device SQLite file
 * (`classtrack.db`) with a dedicated table per collection:
 *
 *   kv               teacher name, active section, chosen logo, migration flag
 *   sections         one row per class / section
 *   students         one row per learner (LRN, birthday, guardian, ...)
 *   subjects         one row per subject taught in a section
 *   sheets           one row per subject + quarter score sheet
 *   sheet_items      the quizzes, assignments, activities, PTs and exams
 *   scores           one row per student score
 *   attendance_days  one row per section + date
 *   attendance_marks one row per student mark for that day
 *   bmi              one row per student measurement
 *
 * `store.ts` stays the in-memory source of truth the UI renders from and
 * mirrors each change into these tables through the `put*` functions below;
 * `loadAll()` reads them back on launch. All work is serialized on a single
 * queue so writes keep their order, nothing blocks the UI, and the app stays
 * fully usable without a network connection.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SQLite from 'expo-sqlite';

import type {
  AssessmentItem,
  AttendanceDay,
  AttendanceStatus,
  BmiRecord,
  ComponentKey,
  Quarter,
  ScoreMap,
  ScoreSheet,
  Section,
  Student,
  Subject,
  Weights,
} from './types';
import { COMPONENTS, DEFAULT_WEIGHTS } from './types';

const DB_NAME = 'classtrack.db';
/** Key under which pre-SQLite builds stored the whole state as one JSON blob. */
const LEGACY_KEY = 'tis-classtrack';
const KEY_MIGRATED = 'legacyMigrated';

/* --------------------------------- schema --------------------------------- */

const SCHEMA = `
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS kv (
  key   TEXT PRIMARY KEY NOT NULL,
  value TEXT
);

CREATE TABLE IF NOT EXISTS sections (
  id          TEXT PRIMARY KEY NOT NULL,
  grade_level TEXT NOT NULL,
  section     TEXT NOT NULL,
  school_year TEXT NOT NULL,
  created_at  INTEGER NOT NULL
);

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
);
CREATE INDEX IF NOT EXISTS idx_students_section ON students(section_id);

CREATE TABLE IF NOT EXISTS subjects (
  id           TEXT PRIMARY KEY NOT NULL,
  section_id   TEXT NOT NULL,
  name         TEXT NOT NULL,
  teacher_name TEXT NOT NULL DEFAULT '',
  weights      TEXT NOT NULL,
  transmute    INTEGER NOT NULL DEFAULT 0,
  created_at   INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_subjects_section ON subjects(section_id);

CREATE TABLE IF NOT EXISTS sheets (
  id         TEXT PRIMARY KEY NOT NULL,
  subject_id TEXT NOT NULL,
  quarter    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sheets_subject ON sheets(subject_id);

CREATE TABLE IF NOT EXISTS sheet_items (
  id        TEXT PRIMARY KEY NOT NULL,
  sheet_id  TEXT NOT NULL,
  component TEXT NOT NULL,
  title     TEXT NOT NULL,
  max_score INTEGER NOT NULL,
  position  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_items_sheet ON sheet_items(sheet_id);

CREATE TABLE IF NOT EXISTS scores (
  sheet_id   TEXT NOT NULL,
  student_id TEXT NOT NULL,
  item_id    TEXT NOT NULL,
  value      REAL NOT NULL,
  PRIMARY KEY (sheet_id, student_id, item_id)
);
CREATE INDEX IF NOT EXISTS idx_scores_sheet ON scores(sheet_id);

CREATE TABLE IF NOT EXISTS attendance_days (
  id         TEXT PRIMARY KEY NOT NULL,
  section_id TEXT NOT NULL,
  date       TEXT NOT NULL,
  marked_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_days_section ON attendance_days(section_id);

CREATE TABLE IF NOT EXISTS attendance_marks (
  day_id    TEXT NOT NULL,
  student_id TEXT NOT NULL,
  status    TEXT NOT NULL,
  PRIMARY KEY (day_id, student_id)
);
CREATE INDEX IF NOT EXISTS idx_marks_day ON attendance_marks(day_id);

CREATE TABLE IF NOT EXISTS bmi (
  student_id  TEXT NOT NULL,
  date        TEXT NOT NULL,
  height_cm   REAL NOT NULL,
  weight_kg   REAL NOT NULL,
  recorded_at INTEGER NOT NULL,
  PRIMARY KEY (student_id, date)
);
CREATE INDEX IF NOT EXISTS idx_bmi_student ON bmi(student_id);
`;

/* --------------------------------- row types -------------------------------- */

interface SectionRow {
  id: string;
  grade_level: string;
  section: string;
  school_year: string;
  created_at: number;
}

interface StudentRow {
  id: string;
  section_id: string;
  seat_number: number | null;
  full_name: string;
  lrn: string;
  gender: string;
  birthday: string;
  guardian_name: string;
  guardian_contact: string;
  created_at: number;
}

interface SubjectRow {
  id: string;
  section_id: string;
  name: string;
  teacher_name: string;
  weights: string;
  transmute: number;
  created_at: number;
}

interface SheetRow {
  id: string;
  subject_id: string;
  quarter: number;
}

interface ItemRow {
  id: string;
  sheet_id: string;
  component: string;
  title: string;
  max_score: number;
  position: number;
}

interface ScoreRow {
  sheet_id: string;
  student_id: string;
  item_id: string;
  value: number;
}

interface DayRow {
  id: string;
  section_id: string;
  date: string;
  marked_at: number;
}

interface MarkRow {
  day_id: string;
  student_id: string;
  status: string;
}

interface BmiRow {
  student_id: string;
  date: string;
  height_cm: number;
  weight_kg: number;
  recorded_at: number;
}

/** Everything the store persists, read back from the database. */
export interface PersistedData {
  teacherName: string;
  activeSectionId: string | null;
  schoolLogoUri: string | null;
  sections: Record<string, Section>;
  students: Record<string, Student>;
  subjects: Record<string, Subject>;
  sheets: Record<string, ScoreSheet>;
  scores: ScoreMap;
  attendance: Record<string, AttendanceDay>;
  bmi: Record<string, BmiRecord>;
}

export type SettingKey = 'teacherName' | 'activeSectionId' | 'schoolLogoUri';

const COMPONENT_KEYS = new Set<string>(COMPONENTS.map((c) => c.key));
const STATUSES = new Set<string>(['present', 'late', 'absent', 'excused']);

/* ------------------------------ connection + queue -------------------------- */

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;
let queue: Promise<unknown> = Promise.resolve();

function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (!dbPromise) {
    dbPromise = SQLite.openDatabaseAsync(DB_NAME)
      .then(async (db) => {
        await db.execAsync(SCHEMA);
        return db;
      })
      .catch((error) => {
        dbPromise = null; // retry on the next operation
        throw error;
      });
  }
  return dbPromise;
}

/**
 * Run one operation after everything queued before it. Errors are reported but
 * never thrown at fire-and-forget callers: the in-memory store already holds
 * the data the user just saved, so a failed write must not break the screen.
 */
function enqueue<T>(task: (db: SQLite.SQLiteDatabase) => Promise<T>): Promise<T> {
  const run = queue.then(() => getDb()).then(task);
  queue = run.then(
    () => undefined,
    (error) => console.warn('[sqlite] database operation failed', error),
  );
  return run;
}

/* ------------------------------- row mappers -------------------------------- */

function toSection(row: SectionRow): Section {
  return {
    id: row.id,
    gradeLevel: row.grade_level,
    section: row.section,
    schoolYear: row.school_year,
    createdAt: row.created_at,
  };
}

function toStudent(row: StudentRow): Student {
  return {
    id: row.id,
    sectionId: row.section_id,
    seatNumber: row.seat_number ?? 0,
    fullName: row.full_name,
    lrn: row.lrn ?? '',
    gender: (row.gender as Student['gender']) ?? '',
    birthday: row.birthday ?? '',
    guardianName: row.guardian_name ?? '',
    guardianContact: row.guardian_contact ?? '',
    createdAt: row.created_at,
  };
}

function toSubject(row: SubjectRow): Subject {
  let weights: Weights = DEFAULT_WEIGHTS;
  try {
    const parsed = JSON.parse(row.weights) as Weights;
    if (parsed && typeof parsed === 'object') weights = { ...DEFAULT_WEIGHTS, ...parsed };
  } catch {
    // keep the defaults when a stored weight set is unreadable
  }
  return {
    id: row.id,
    sectionId: row.section_id,
    name: row.name,
    teacherName: row.teacher_name ?? '',
    weights,
    transmute: row.transmute === 1,
    createdAt: row.created_at,
  };
}

/* ----------------------------- single-row writers --------------------------- */

async function writeSection(db: SQLite.SQLiteDatabase, value: Section): Promise<void> {
  await db.runAsync(
    `INSERT INTO sections (id, grade_level, section, school_year, created_at)
       VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       grade_level = excluded.grade_level,
       section = excluded.section,
       school_year = excluded.school_year,
       created_at = excluded.created_at`,
    [value.id, value.gradeLevel, value.section, value.schoolYear, value.createdAt],
  );
}

async function writeStudent(db: SQLite.SQLiteDatabase, value: Student): Promise<void> {
  await db.runAsync(
    `INSERT INTO students (id, section_id, seat_number, full_name, lrn, gender, birthday,
                           guardian_name, guardian_contact, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       section_id = excluded.section_id,
       seat_number = excluded.seat_number,
       full_name = excluded.full_name,
       lrn = excluded.lrn,
       gender = excluded.gender,
       birthday = excluded.birthday,
       guardian_name = excluded.guardian_name,
       guardian_contact = excluded.guardian_contact,
       created_at = excluded.created_at`,
    [
      value.id,
      value.sectionId,
      value.seatNumber ?? 0,
      value.fullName,
      value.lrn ?? '',
      value.gender ?? '',
      value.birthday ?? '',
      value.guardianName ?? '',
      value.guardianContact ?? '',
      value.createdAt,
    ],
  );
}

async function writeSubject(db: SQLite.SQLiteDatabase, value: Subject): Promise<void> {
  await db.runAsync(
    `INSERT INTO subjects (id, section_id, name, teacher_name, weights, transmute, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       section_id = excluded.section_id,
       name = excluded.name,
       teacher_name = excluded.teacher_name,
       weights = excluded.weights,
       transmute = excluded.transmute,
       created_at = excluded.created_at`,
    [
      value.id,
      value.sectionId,
      value.name,
      value.teacherName ?? '',
      JSON.stringify(value.weights ?? DEFAULT_WEIGHTS),
      value.transmute ? 1 : 0,
      value.createdAt,
    ],
  );
}

/** Writes a score sheet together with all of its assessment items. */
async function writeSheet(db: SQLite.SQLiteDatabase, value: ScoreSheet): Promise<void> {
  await db.runAsync(
    `INSERT INTO sheets (id, subject_id, quarter) VALUES (?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET subject_id = excluded.subject_id, quarter = excluded.quarter`,
    [value.id, value.subjectId, value.quarter],
  );
  await db.runAsync('DELETE FROM sheet_items WHERE sheet_id = ?', [value.id]);
  const order = COMPONENTS.map((c) => c.key);
  for (const component of order) {
    const items = value.items?.[component] ?? [];
    for (let position = 0; position < items.length; position += 1) {
      const item: AssessmentItem = items[position];
      await db.runAsync(
        `INSERT INTO sheet_items (id, sheet_id, component, title, max_score, position)
           VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           sheet_id = excluded.sheet_id,
           component = excluded.component,
           title = excluded.title,
           max_score = excluded.max_score,
           position = excluded.position`,
        [item.id, value.id, component, item.title, item.max, position],
      );
    }
  }
}

async function writeAttendanceDay(db: SQLite.SQLiteDatabase, value: AttendanceDay): Promise<void> {
  await db.runAsync(
    `INSERT INTO attendance_days (id, section_id, date, marked_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       section_id = excluded.section_id,
       date = excluded.date,
       marked_at = excluded.marked_at`,
    [value.id, value.sectionId, value.date, value.markedAt],
  );
  await db.runAsync('DELETE FROM attendance_marks WHERE day_id = ?', [value.id]);
  for (const [studentId, status] of Object.entries(value.statuses ?? {})) {
    await db.runAsync(
      'INSERT OR REPLACE INTO attendance_marks (day_id, student_id, status) VALUES (?, ?, ?)',
      [value.id, studentId, status],
    );
  }
}

async function writeBmi(db: SQLite.SQLiteDatabase, value: BmiRecord): Promise<void> {
  await db.runAsync(
    `INSERT INTO bmi (student_id, date, height_cm, weight_kg, recorded_at)
       VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(student_id, date) DO UPDATE SET
       height_cm = excluded.height_cm,
       weight_kg = excluded.weight_kg,
       recorded_at = excluded.recorded_at`,
    [value.studentId, value.date, value.heightCm, value.weightKg, value.recordedAt],
  );
}

async function writeSetting(
  db: SQLite.SQLiteDatabase,
  key: SettingKey | typeof KEY_MIGRATED,
  value: string | null,
): Promise<void> {
  if (value === null) {
    await db.runAsync('DELETE FROM kv WHERE key = ?', [key]);
    return;
  }
  await db.runAsync(
    'INSERT INTO kv (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value],
  );
}

/* ------------------------------- public writes ------------------------------ */

export function saveSetting(key: SettingKey, value: string | null): void {
  void enqueue((db) => writeSetting(db, key, value));
}

export function putSection(value: Section): void {
  void enqueue((db) => writeSection(db, value));
}

export function removeSection(id: string): void {
  void enqueue((db) => db.runAsync('DELETE FROM sections WHERE id = ?', [id]).then(() => undefined));
}

export function putStudent(value: Student): void {
  void enqueue((db) => writeStudent(db, value));
}

export function removeStudent(id: string): void {
  void enqueue((db) =>
    db
      .runAsync('DELETE FROM students WHERE id = ?', [id])
      .then(() => undefined),
  );
}

export function putSubject(value: Subject): void {
  void enqueue((db) => writeSubject(db, value));
}

export function removeSubject(id: string): void {
  void enqueue((db) => db.runAsync('DELETE FROM subjects WHERE id = ?', [id]).then(() => undefined));
}

export function putSheet(value: ScoreSheet): void {
  void enqueue((db) => writeSheet(db, value));
}

export function removeSheet(id: string): void {
  void enqueue(async (db) => {
    await db.runAsync('DELETE FROM sheet_items WHERE sheet_id = ?', [id]);
    await db.runAsync('DELETE FROM sheets WHERE id = ?', [id]);
  });
}

/** Saves a score keyed `${sheetId}|${studentId}|${itemId}`; null clears it. */
export function saveScore(key: string, value: number | null): void {
  const [sheetId, studentId, itemId] = key.split('|');
  if (!sheetId || !studentId || !itemId) return;
  void enqueue(async (db) => {
    if (value === null || Number.isNaN(value)) {
      await db.runAsync('DELETE FROM scores WHERE sheet_id = ? AND student_id = ? AND item_id = ?', [
        sheetId,
        studentId,
        itemId,
      ]);
      return;
    }
    await db.runAsync(
      `INSERT INTO scores (sheet_id, student_id, item_id, value) VALUES (?, ?, ?, ?)
       ON CONFLICT(sheet_id, student_id, item_id) DO UPDATE SET value = excluded.value`,
      [sheetId, studentId, itemId, value],
    );
  });
}

export function putAttendanceDay(value: AttendanceDay): void {
  void enqueue((db) => writeAttendanceDay(db, value));
}

export function removeAttendanceDay(id: string): void {
  void enqueue(async (db) => {
    await db.runAsync('DELETE FROM attendance_marks WHERE day_id = ?', [id]);
    await db.runAsync('DELETE FROM attendance_days WHERE id = ?', [id]);
  });
}

export function putBmi(value: BmiRecord): void {
  void enqueue((db) => writeBmi(db, value));
}

export function removeBmi(studentId: string, date: string): void {
  void enqueue((db) =>
    db.runAsync('DELETE FROM bmi WHERE student_id = ? AND date = ?', [studentId, date]).then(() => undefined),
  );
}

/* ---------------------------------- reads ----------------------------------- */

/** Reads every table back into the shape the store expects. */
export function loadAll(): Promise<PersistedData> {
  return enqueue(async (db) => {
    const kvRows = await db.getAllAsync<{ key: string; value: string }>('SELECT key, value FROM kv');
    const kv = new Map(kvRows.map((row) => [row.key, row.value]));

    const sectionRows = await db.getAllAsync<SectionRow>('SELECT * FROM sections');
    const studentRows = await db.getAllAsync<StudentRow>('SELECT * FROM students');
    const subjectRows = await db.getAllAsync<SubjectRow>('SELECT * FROM subjects');
    const sheetRows = await db.getAllAsync<SheetRow>('SELECT * FROM sheets');
    const itemRows = await db.getAllAsync<ItemRow>('SELECT * FROM sheet_items ORDER BY sheet_id, position');
    const scoreRows = await db.getAllAsync<ScoreRow>('SELECT * FROM scores');
    const dayRows = await db.getAllAsync<DayRow>('SELECT * FROM attendance_days');
    const markRows = await db.getAllAsync<MarkRow>('SELECT * FROM attendance_marks');
    const bmiRows = await db.getAllAsync<BmiRow>('SELECT * FROM bmi');

    const sections: Record<string, Section> = {};
    for (const row of sectionRows) sections[row.id] = toSection(row);

    const students: Record<string, Student> = {};
    for (const row of studentRows) students[row.id] = toStudent(row);

    const subjects: Record<string, Subject> = {};
    for (const row of subjectRows) subjects[row.id] = toSubject(row);

    const sheets: Record<string, ScoreSheet> = {};
    for (const row of sheetRows) {
      sheets[row.id] = {
        id: row.id,
        subjectId: row.subject_id,
        quarter: row.quarter as Quarter,
        items: { quizzes: [], assignments: [], activities: [], performanceTasks: [], examinations: [] },
      };
    }
    for (const row of itemRows) {
      const sheet = sheets[row.sheet_id];
      if (!sheet || !COMPONENT_KEYS.has(row.component)) continue;
      sheet.items[row.component as ComponentKey].push({
        id: row.id,
        title: row.title,
        max: row.max_score,
      });
    }

    const scores: ScoreMap = {};
    for (const row of scoreRows) {
      scores[`${row.sheet_id}|${row.student_id}|${row.item_id}`] = row.value;
    }

    const attendance: Record<string, AttendanceDay> = {};
    for (const row of dayRows) {
      attendance[row.id] = {
        id: row.id,
        sectionId: row.section_id,
        date: row.date,
        statuses: {},
        markedAt: row.marked_at,
      };
    }
    for (const row of markRows) {
      const day = attendance[row.day_id];
      if (!day || !STATUSES.has(row.status)) continue;
      day.statuses[row.student_id] = row.status as AttendanceStatus;
    }

    const bmi: Record<string, BmiRecord> = {};
    for (const row of bmiRows) {
      const id = `${row.student_id}::${row.date}`;
      bmi[id] = {
        id,
        studentId: row.student_id,
        date: row.date,
        heightCm: row.height_cm,
        weightKg: row.weight_kg,
        recordedAt: row.recorded_at,
      };
    }

    return {
      teacherName: kv.get('teacherName') ?? '',
      activeSectionId: kv.get('activeSectionId') ?? null,
      schoolLogoUri: kv.get('schoolLogoUri') ?? null,
      sections,
      students,
      subjects,
      sheets,
      scores,
      attendance,
      bmi,
    };
  });
}

/* --------------------------- legacy AsyncStorage import ---------------------- */

interface LegacyState {
  teacherName?: string;
  activeSectionId?: string | null;
  schoolLogoUri?: string | null;
  sections?: Record<string, Section>;
  students?: Record<string, Student>;
  subjects?: Record<string, Subject>;
  sheets?: Record<string, ScoreSheet>;
  scores?: ScoreMap;
  attendance?: Record<string, AttendanceDay>;
  bmi?: Record<string, BmiRecord>;
}

/**
 * One-time import of the JSON blob pre-SQLite builds kept in AsyncStorage, so
 * no class, score or attendance record is lost when upgrading. The whole
 * import commits in a single transaction together with its completion flag —
 * a failure leaves nothing behind and is retried on the next launch, and the
 * legacy copy is only deleted once the data is safely in SQLite.
 */
export async function migrateLegacyStorage(): Promise<void> {
  const alreadyDone = await enqueue(async (db) => {
    const row = await db.getFirstAsync<{ value: string }>('SELECT value FROM kv WHERE key = ?', [
      KEY_MIGRATED,
    ]);
    return row?.value === '1';
  });
  if (alreadyDone) return;

  let legacy: LegacyState | null = null;
  const raw = await AsyncStorage.getItem(LEGACY_KEY);
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as { state?: LegacyState } | LegacyState;
      const wrapped = (parsed as { state?: LegacyState }).state;
      legacy = (wrapped ?? parsed) as LegacyState;
    } catch (error) {
      console.warn('[sqlite] legacy backup is unreadable, skipping import', error);
    }
  }

  await enqueue(async (db) => {
    await db.withTransactionAsync(async () => {
      if (legacy) {
        for (const value of Object.values(legacy.sections ?? {})) await writeSection(db, value);
        for (const value of Object.values(legacy.students ?? {})) await writeStudent(db, value);
        for (const value of Object.values(legacy.subjects ?? {})) await writeSubject(db, value);
        for (const value of Object.values(legacy.sheets ?? {})) await writeSheet(db, value);
        for (const [key, value] of Object.entries(legacy.scores ?? {})) {
          const [sheetId, studentId, itemId] = key.split('|');
          if (!sheetId || !studentId || !itemId || value === null || Number.isNaN(value)) continue;
          await db.runAsync(
            `INSERT INTO scores (sheet_id, student_id, item_id, value) VALUES (?, ?, ?, ?)
             ON CONFLICT(sheet_id, student_id, item_id) DO UPDATE SET value = excluded.value`,
            [sheetId, studentId, itemId, value],
          );
        }
        for (const value of Object.values(legacy.attendance ?? {})) await writeAttendanceDay(db, value);
        for (const value of Object.values(legacy.bmi ?? {})) await writeBmi(db, value);
        if (legacy.teacherName !== undefined) await writeSetting(db, 'teacherName', legacy.teacherName);
        if (legacy.activeSectionId !== undefined) {
          await writeSetting(db, 'activeSectionId', legacy.activeSectionId);
        }
        if (legacy.schoolLogoUri !== undefined) {
          await writeSetting(db, 'schoolLogoUri', legacy.schoolLogoUri);
        }
      }
      await writeSetting(db, KEY_MIGRATED, '1');
    });
  });

  if (legacy) {
    await AsyncStorage.removeItem(LEGACY_KEY);
  }
}
