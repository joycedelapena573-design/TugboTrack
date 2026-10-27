/**
 * CSV backups. Every save/change in the app schedules an automatic local CSV
 * backup (requirement 4.4); teachers can also export a shareable backup.
 */
import { Directory, File, Paths } from 'expo-file-system';

import { toCsv } from './csv';
import { formatShortDate } from './format';
import { COMPONENTS } from './types';
import type {
  AttendanceDay,
  BmiRecord,
  ScoreMap,
  ScoreSheet,
  Section,
  Student,
  Subject,
} from './types';

export interface BackupData {
  teacherName: string;
  sections: Record<string, Section>;
  students: Record<string, Student>;
  subjects: Record<string, Subject>;
  sheets: Record<string, ScoreSheet>;
  scores: ScoreMap;
  attendance: Record<string, AttendanceDay>;
  bmi: Record<string, BmiRecord>;
}

const AUTO_DIR = 'auto-backups';

function values<T>(map: Record<string, T>): T[] {
  return Object.values(map);
}

export function buildStudentsCsv(data: BackupData): string {
  const rows: (string | number)[][] = [
    ['Seat', 'Name', 'LRN', 'Gender', 'Birthday', 'Age', 'Guardian', 'Contact', 'Grade Level', 'Section', 'School Year'],
  ];
  const students = values(data.students).sort(
    (a, b) =>
      a.sectionId.localeCompare(b.sectionId) || (a.seatNumber ?? 0) - (b.seatNumber ?? 0),
  );
  for (const s of students) {
    const sec = data.sections[s.sectionId];
    rows.push([
      s.seatNumber ?? '',
      s.fullName,
      s.lrn,
      s.gender,
      s.birthday,
      ageOf(s.birthday),
      s.guardianName,
      s.guardianContact,
      sec?.gradeLevel ?? '',
      sec?.section ?? '',
      sec?.schoolYear ?? '',
    ]);
  }
  return toCsv(rows);
}

function ageOf(birthday: string): number | '' {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(birthday ?? '')) return '';
  const b = new Date(birthday);
  const now = new Date();
  let age = now.getFullYear() - b.getFullYear();
  const m = now.getMonth() - b.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < b.getDate())) age -= 1;
  return age >= 0 ? age : '';
}

export function buildGradesCsv(data: BackupData): string {
  const rows: (string | number)[][] = [
    [
      'Grade Level', 'Section', 'School Year', 'Subject', 'Quarter', 'Student',
      'Component', 'Item', 'Score', 'Highest',
    ],
  ];
  for (const sheet of values(data.sheets)) {
    const subject = data.subjects[sheet.subjectId];
    if (!subject) continue;
    const section = data.sections[subject.sectionId];
    for (const comp of COMPONENTS) {
      for (const item of sheet.items[comp.key] ?? []) {
        const students = values(data.students)
          .filter((s) => s.sectionId === subject.sectionId)
          .sort((a, b) => a.seatNumber - b.seatNumber);
        for (const st of students) {
          const key = `${sheet.id}|${st.id}|${item.id}`;
          const score = data.scores[key];
          if (typeof score !== 'number') continue;
          rows.push([
            section?.gradeLevel ?? '',
            section?.section ?? '',
            section?.schoolYear ?? '',
            subject.name,
            `Q${sheet.quarter}`,
            st.fullName,
            comp.label,
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

export function buildAttendanceCsv(data: BackupData): string {
  const rows: (string | number)[][] = [
    ['Date', 'Grade Level', 'Section', 'School Year', 'Seat', 'Student', 'Status'],
  ];
  const days = values(data.attendance).sort((a, b) => a.date.localeCompare(b.date));
  for (const day of days) {
    const section = data.sections[day.sectionId];
    const students = values(data.students)
      .filter((s) => s.sectionId === day.sectionId)
      .sort((a, b) => a.seatNumber - b.seatNumber);
    for (const st of students) {
      const status = day.statuses[st.id];
      rows.push([
        day.date,
        section?.gradeLevel ?? '',
        section?.section ?? '',
        section?.schoolYear ?? '',
        st.seatNumber ?? '',
        st.fullName,
        status ?? '',
      ]);
    }
  }
  return toCsv(rows);
}

export function buildBmiCsv(data: BackupData): string {
  const rows: (string | number)[][] = [
    ['Date', 'Student', 'Height (cm)', 'Weight (kg)', 'BMI'],
  ];
  const records = values(data.bmi).sort((a, b) => a.date.localeCompare(b.date));
  for (const r of records) {
    const st = data.students[r.studentId];
    const bmi = r.heightCm > 0 ? r.weightKg / ((r.heightCm / 100) ** 2) : null;
    rows.push([
      r.date,
      st?.fullName ?? '',
      r.heightCm,
      r.weightKg,
      bmi === null ? '' : bmi.toFixed(1),
    ]);
  }
  return toCsv(rows);
}

/** Full machine-readable backup (one row per record type, importable in spreadsheets). */
export function buildFullBackupCsv(data: BackupData): string {
  const rows: (string | number)[][] = [
    ['record_type', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8', 'c9'],
  ];
  rows.push(['meta', 'TIS ClassTrack backup', formatShortDate(new Date().toISOString().slice(0, 10)), data.teacherName]);
  for (const sec of values(data.sections)) {
    rows.push(['section', sec.id, sec.gradeLevel, sec.section, sec.schoolYear]);
  }
  for (const st of values(data.students)) {
    rows.push([
      'student', st.id, st.sectionId, st.seatNumber, st.fullName, st.lrn,
      st.gender, st.birthday, st.guardianName, st.guardianContact,
    ]);
  }
  for (const sub of values(data.subjects)) {
    const w = sub.weights;
    rows.push([
      'subject', sub.id, sub.sectionId, sub.name, sub.teacherName,
      `${w.quizzes}/${w.assignments}/${w.activities}/${w.performanceTasks}/${w.examinations}`,
      sub.transmute ? 'transmute' : 'raw',
    ]);
  }
  for (const sheet of values(data.sheets)) {
    for (const comp of COMPONENTS) {
      for (const item of sheet.items[comp.key] ?? []) {
        rows.push(['item', sheet.id, sheet.subjectId, `Q${sheet.quarter}`, comp.key, item.id, item.title, item.max]);
      }
    }
  }
  for (const [key, score] of Object.entries(data.scores)) {
    rows.push(['score', key, score]);
  }
  for (const day of values(data.attendance)) {
    for (const [studentId, status] of Object.entries(day.statuses)) {
      rows.push(['attendance', day.sectionId, day.date, studentId, status]);
    }
  }
  for (const r of values(data.bmi)) {
    rows.push(['bmi', r.studentId, r.date, r.heightCm, r.weightKg]);
  }
  return toCsv(rows);
}

function ensureBackupDir(): Directory {
  const dir = new Directory(Paths.document, AUTO_DIR);
  if (!dir.exists) dir.create({ intermediates: true, idempotent: true });
  return dir;
}

/** Write the rolling on-device CSV backup set (called on every app save). */
export async function writeAutoBackups(data: BackupData): Promise<void> {
  const dir = ensureBackupDir();
  const files: [string, string][] = [
    ['students.csv', buildStudentsCsv(data)],
    ['grades.csv', buildGradesCsv(data)],
    ['attendance.csv', buildAttendanceCsv(data)],
    ['bmi.csv', buildBmiCsv(data)],
    ['full-backup.csv', buildFullBackupCsv(data)],
  ];
  for (const [name, csv] of files) {
    const file = new File(dir, name);
    await file.write(csv, { encoding: 'utf8' });
  }
}

let backupTimer: ReturnType<typeof setTimeout> | null = null;
let lastRunAt = 0;

/** Debounced auto-backup so rapid edits (typing scores) batch into one write. */
export function scheduleAutoBackup(data: BackupData): void {
  if (backupTimer) clearTimeout(backupTimer);
  backupTimer = setTimeout(
    async () => {
      backupTimer = null;
      try {
        await writeAutoBackups(data);
        lastRunAt = Date.now();
      } catch (err) {
        console.warn('Auto-backup failed', err);
      }
    },
    Math.max(400, 1200 - (Date.now() - lastRunAt)),
  );
}

export function autoBackupDirPath(): string {
  return `${Paths.document.uri}${AUTO_DIR}/`;
}

/** Write a timestamped full backup and return its URI for sharing/saving. */
export async function exportFullBackupCsv(data: BackupData): Promise<string> {
  const stamp = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '');
  const file = new File(Paths.cache, `classtrack-backup-${stamp}.csv`);
  await file.write(buildFullBackupCsv(data), { encoding: 'utf8' });
  return file.uri;
}

/** Write an arbitrary CSV (e.g. a class record sheet) and return its URI. */
export async function exportCsvFile(name: string, csv: string): Promise<string> {
  const safe = name.replace(/[^a-zA-Z0-9-_]+/g, '_');
  const file = new File(Paths.cache, `${safe}.csv`);
  await file.write(csv, { encoding: 'utf8' });
  return file.uri;
}
