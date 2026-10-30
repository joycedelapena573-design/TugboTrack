/**
 * Offline-first app store. The UI renders from this in-memory store, every
 * change is mirrored into the on-device SQLite database (see ./db.ts) and
 * every mutation schedules an automatic CSV backup.
 */
import * as Crypto from 'expo-crypto';
import { create } from 'zustand';

import { scheduleAutoBackup, type BackupData } from './backup';
import {
  loadAll,
  migrateLegacyStorage,
  putAttendanceDay,
  putBmi,
  putSection,
  putSheet,
  putStudent,
  putSubject,
  removeAttendanceDay,
  removeBmi,
  removeSection,
  removeSheet,
  removeStudent,
  removeSubject,
  saveScore,
  saveSetting,
} from './db';
import { normalizeBirthday } from './format';
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
import { DEFAULT_WEIGHTS } from './types';

function uid(): string {
  try {
    return Crypto.randomUUID();
  } catch {
    return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
  }
}

function emptySheetItems(): Record<ComponentKey, AssessmentItem[]> {
  return { quizzes: [], assignments: [], activities: [], performanceTasks: [], examinations: [] };
}

export interface ClassTrackState {
  hydrated: boolean;
  teacherName: string;
  sections: Record<string, Section>;
  students: Record<string, Student>;
  subjects: Record<string, Subject>;
  sheets: Record<string, ScoreSheet>;
  scores: ScoreMap;
  attendance: Record<string, AttendanceDay>;
  bmi: Record<string, BmiRecord>;
  activeSectionId: string | null;
  /** Teacher-chosen school logo file (file:// uri), null = bundled default. */
  schoolLogoUri: string | null;

  setTeacherName: (name: string) => void;
  setActiveSection: (id: string | null) => void;
  setSchoolLogo: (uri: string | null) => void;

  addSection: (input: { gradeLevel: string; section: string; schoolYear: string }) => Section;
  updateSection: (id: string, patch: Partial<Omit<Section, 'id'>>) => void;
  deleteSection: (id: string) => void;

  addStudent: (input: Omit<Student, 'id' | 'createdAt'>) => Student;
  bulkAddStudents: (rows: Omit<Student, 'id' | 'createdAt'>[]) => number;
  updateStudent: (id: string, patch: Partial<Omit<Student, 'id'>>) => void;
  deleteStudent: (id: string) => void;

  addSubject: (input: { sectionId: string; name: string; teacherName: string; weights?: Weights; transmute?: boolean }) => Subject;
  updateSubject: (id: string, patch: Partial<Omit<Subject, 'id'>>) => void;
  deleteSubject: (id: string) => void;

  ensureSheet: (subjectId: string, quarter: Quarter) => ScoreSheet;
  addItem: (subjectId: string, quarter: Quarter, component: ComponentKey, title: string, max: number) => void;
  updateItem: (subjectId: string, quarter: Quarter, component: ComponentKey, itemId: string, patch: { title?: string; max?: number }) => void;
  deleteItem: (subjectId: string, quarter: Quarter, component: ComponentKey, itemId: string) => void;
  setScore: (sheetId: string, studentId: string, itemId: string, value: number | null) => void;

  setAttendance: (sectionId: string, date: string, studentId: string, status: AttendanceStatus) => void;
  clearAttendanceSeat: (sectionId: string, date: string, studentId: string) => void;
  markAllAttendance: (sectionId: string, date: string, status: AttendanceStatus) => void;
  clearAttendanceDay: (sectionId: string, date: string) => void;

  setBmi: (studentId: string, date: string, heightCm: number, weightKg: number) => void;
  deleteBmi: (recordId: string) => void;
}

export const useStore = create<ClassTrackState>()(
  (set, get) => {
    const backup = () => {
      const s = get();
      const data: BackupData = {
        teacherName: s.teacherName,
        sections: s.sections,
        students: s.students,
        subjects: s.subjects,
        sheets: s.sheets,
        scores: s.scores,
        attendance: s.attendance,
        bmi: s.bmi,
      };
      scheduleAutoBackup(data);
    };

    const sheetIdOf = (subjectId: string, quarter: Quarter) => `${subjectId}::q${quarter}`;

    return {
      hydrated: false,
      teacherName: '',
      sections: {},
      students: {},
      subjects: {},
      sheets: {},
      scores: {},
      attendance: {},
      bmi: {},
      activeSectionId: null,
      schoolLogoUri: null,

      setTeacherName: (name) => {
        set({ teacherName: name.trim() });
        backup();
      },

      setSchoolLogo: (uri) => {
        set({ schoolLogoUri: uri });
      },

      setActiveSection: (id) => set({ activeSectionId: id }),

      addSection: ({ gradeLevel, section, schoolYear }) => {
        const sec: Section = { id: uid(), gradeLevel, section, schoolYear, createdAt: Date.now() };
        set((s) => ({ sections: { ...s.sections, [sec.id]: sec }, activeSectionId: sec.id }));
        backup();
        return sec;
      },

      updateSection: (id, patch) => {
        set((s) => {
          const prev = s.sections[id];
          if (!prev) return s;
          return { sections: { ...s.sections, [id]: { ...prev, ...patch } } };
        });
        backup();
      },

      deleteSection: (id) => {
        set((s) => {
          const sections = { ...s.sections };
          delete sections[id];
          const students = Object.fromEntries(
            Object.entries(s.students).filter(([, st]) => st.sectionId !== id),
          );
          const removedStudentIds = new Set(
            Object.values(s.students)
              .filter((st) => st.sectionId === id)
              .map((st) => st.id),
          );
          const subjects = Object.fromEntries(
            Object.entries(s.subjects).filter(([, sub]) => sub.sectionId !== id),
          );
          const removedSubjectIds = new Set(
            Object.values(s.subjects)
              .filter((sub) => sub.sectionId === id)
              .map((sub) => sub.id),
          );
          const sheets = Object.fromEntries(
            Object.entries(s.sheets).filter(([, sh]) => !removedSubjectIds.has(sh.subjectId)),
          );
          const scores = Object.fromEntries(
            Object.entries(s.scores).filter(
              ([key]) => !removedSubjectIds.has(key.split('|')[0].split('::')[0]),
            ),
          );
          const attendance = Object.fromEntries(
            Object.entries(s.attendance).filter(([, day]) => day.sectionId !== id),
          );
          const bmi = Object.fromEntries(
            Object.entries(s.bmi).filter(([, r]) => !removedStudentIds.has(r.studentId)),
          );
          return {
            sections,
            students,
            subjects,
            sheets,
            scores,
            attendance,
            bmi,
            activeSectionId: s.activeSectionId === id ? null : s.activeSectionId,
          };
        });
        backup();
      },

      addStudent: (input) => {
        const student: Student = { ...input, id: uid(), createdAt: Date.now() };
        set((s) => ({ students: { ...s.students, [student.id]: student } }));
        backup();
        return student;
      },

      bulkAddStudents: (rows) => {
        if (rows.length === 0) return 0;
        set((s) => {
          const students = { ...s.students };
          const taken = new Set(
            Object.values(s.students).map((st) => `${st.sectionId}#${st.seatNumber}`),
          );
          let added = 0;
          for (const row of rows) {
            let seat = row.seatNumber;
            while (seat !== null && seat !== undefined && taken.has(`${row.sectionId}#${seat}`)) {
              seat += 1;
            }
            const finalSeat = seat === null || seat === undefined ? nextSeat(s.students, row.sectionId) : seat;
            const student: Student = { ...row, seatNumber: finalSeat, id: uid(), createdAt: Date.now() + added };
            taken.add(`${row.sectionId}#${finalSeat}`);
            students[student.id] = student;
            added += 1;
          }
          return { students };
        });
        backup();
        return rows.length;
      },

      updateStudent: (id, patch) => {
        set((s) => {
          const prev = s.students[id];
          if (!prev) return s;
          const next = { ...prev, ...patch };
          if (patch.birthday !== undefined) {
            next.birthday = normalizeBirthday(patch.birthday) ?? prev.birthday;
          }
          return { students: { ...s.students, [id]: next } };
        });
        backup();
      },

      deleteStudent: (id) => {
        set((s) => {
          const students = { ...s.students };
          delete students[id];
          const scores = Object.fromEntries(
            Object.entries(s.scores).filter(([key]) => !key.includes(`|${id}|`)),
          );
          const attendance = Object.fromEntries(
            Object.entries(s.attendance).map(([k, day]) => {
              if (!(id in day.statuses)) return [k, day] as const;
              const statuses = { ...day.statuses };
              delete statuses[id];
              return [k, { ...day, statuses }] as const;
            }),
          );
          const bmi = Object.fromEntries(
            Object.entries(s.bmi).filter(([, r]) => r.studentId !== id),
          );
          return { students, scores, attendance, bmi };
        });
        backup();
      },

      addSubject: ({ sectionId, name, teacherName, weights, transmute }) => {
        const subject: Subject = {
          id: uid(),
          sectionId,
          name: name.trim(),
          teacherName: teacherName.trim(),
          weights: weights ?? DEFAULT_WEIGHTS,
          transmute: transmute ?? false,
          createdAt: Date.now(),
        };
        set((s) => ({ subjects: { ...s.subjects, [subject.id]: subject } }));
        backup();
        return subject;
      },

      updateSubject: (id, patch) => {
        set((s) => {
          const prev = s.subjects[id];
          if (!prev) return s;
          return { subjects: { ...s.subjects, [id]: { ...prev, ...patch } } };
        });
        backup();
      },

      deleteSubject: (id) => {
        set((s) => {
          const subjects = { ...s.subjects };
          delete subjects[id];
          const sheets = Object.fromEntries(
            Object.entries(s.sheets).filter(([, sh]) => sh.subjectId !== id),
          );
          const scores = Object.fromEntries(
            Object.entries(s.scores).filter(([key]) => !key.startsWith(`${id}::`)),
          );
          return { subjects, sheets, scores };
        });
        backup();
      },

      ensureSheet: (subjectId, quarter) => {
        const id = sheetIdOf(subjectId, quarter);
        const existing = get().sheets[id];
        if (existing) return existing;
        const sheet: ScoreSheet = { id, subjectId, quarter, items: emptySheetItems() };
        set((s) => ({ sheets: { ...s.sheets, [id]: sheet } }));
        return sheet;
      },

      addItem: (subjectId, quarter, component, title, max) => {
        const sheet = get().ensureSheet(subjectId, quarter);
        const item = { id: uid(), title: title.trim(), max: max > 0 ? max : 100 };
        set((s) => {
          const prev = s.sheets[sheet.id];
          return {
            sheets: {
              ...s.sheets,
              [sheet.id]: { ...prev, items: { ...prev.items, [component]: [...(prev.items[component] ?? []), item] } },
            },
          };
        });
        backup();
      },

      updateItem: (subjectId, quarter, component, itemId, patch) => {
        const id = sheetIdOf(subjectId, quarter);
        set((s) => {
          const sheet = s.sheets[id];
          if (!sheet) return s;
          const items = (sheet.items[component] ?? []).map((it) =>
            it.id === itemId ? { ...it, ...patch, max: patch.max !== undefined && patch.max > 0 ? patch.max : it.max } : it,
          );
          return { sheets: { ...s.sheets, [id]: { ...sheet, items: { ...sheet.items, [component]: items } } } };
        });
        backup();
      },

      deleteItem: (subjectId, quarter, component, itemId) => {
        const id = sheetIdOf(subjectId, quarter);
        set((s) => {
          const sheet = s.sheets[id];
          if (!sheet) return s;
          const items = (sheet.items[component] ?? []).filter((it) => it.id !== itemId);
          const prefix = `${id}|`;
          const scores = Object.fromEntries(
            Object.entries(s.scores).filter(
              ([key]) => !(key.startsWith(prefix) && key.endsWith(`|${itemId}`)),
            ),
          );
          return {
            sheets: { ...s.sheets, [id]: { ...sheet, items: { ...sheet.items, [component]: items } } },
            scores,
          };
        });
        backup();
      },

      setScore: (sheetId, studentId, itemId, value) => {
        const key = `${sheetId}|${studentId}|${itemId}`;
        set((s) => {
          const scores = { ...s.scores };
          if (value === null || Number.isNaN(value)) delete scores[key];
          else scores[key] = value;
          return { scores };
        });
        backup();
      },

      setAttendance: (sectionId, date, studentId, status) => {
        const id = `${sectionId}::${date}`;
        set((s) => {
          const day = s.attendance[id] ?? { id, sectionId, date, statuses: {}, markedAt: Date.now() };
          return {
            attendance: {
              ...s.attendance,
              [id]: { ...day, statuses: { ...day.statuses, [studentId]: status }, markedAt: Date.now() },
            },
          };
        });
        backup();
      },

      clearAttendanceSeat: (sectionId, date, studentId) => {
        const id = `${sectionId}::${date}`;
        set((s) => {
          const day = s.attendance[id];
          if (!day || !(studentId in day.statuses)) return s;
          const statuses = { ...day.statuses };
          delete statuses[studentId];
          return {
            attendance: { ...s.attendance, [id]: { ...day, statuses, markedAt: Date.now() } },
          };
        });
        backup();
      },

      markAllAttendance: (sectionId, date, status) => {
        const id = `${sectionId}::${date}`;
        set((s) => {
          const statuses: Record<string, AttendanceStatus> = {};
          for (const st of Object.values(s.students)) {
            if (st.sectionId === sectionId) statuses[st.id] = status;
          }
          return {
            attendance: {
              ...s.attendance,
              [id]: { id, sectionId, date, statuses, markedAt: Date.now() },
            },
          };
        });
        backup();
      },

      clearAttendanceDay: (sectionId, date) => {
        const id = `${sectionId}::${date}`;
        set((s) => {
          const attendance = { ...s.attendance };
          delete attendance[id];
          return { attendance };
        });
        backup();
      },

      setBmi: (studentId, date, heightCm, weightKg) => {
        const id = `${studentId}::${date}`;
        set((s) => ({
          bmi: {
            ...s.bmi,
            [id]: { id, studentId, date, heightCm, weightKg, recordedAt: Date.now() },
          },
        }));
        backup();
      },

      deleteBmi: (recordId) => {
        set((s) => {
          const bmi = { ...s.bmi };
          delete bmi[recordId];
          return { bmi };
        });
        backup();
      },
    };
  },
);

/* ---------------------------- SQLite mirroring ----------------------------- */

/**
 * State updates are immutable, so a collection whose reference changed holds
 * new records and a record whose reference changed is the one to write. This
 * keeps a single code path between what the screens do and what SQLite holds,
 * and it fires after every save — a score, a seat tap, an edited profile.
 */
useStore.subscribe((state, prev) => {
  // The initial load writes nothing: those rows are already in the database.
  if (!prev.hydrated || !state.hydrated) return;

  if (state.teacherName !== prev.teacherName) saveSetting('teacherName', state.teacherName);
  if (state.activeSectionId !== prev.activeSectionId) {
    saveSetting('activeSectionId', state.activeSectionId);
  }
  if (state.schoolLogoUri !== prev.schoolLogoUri) saveSetting('schoolLogoUri', state.schoolLogoUri);

  if (state.sections !== prev.sections) syncRecords(prev.sections, state.sections, putSection, removeSection);
  if (state.students !== prev.students) syncRecords(prev.students, state.students, putStudent, removeStudent);
  if (state.subjects !== prev.subjects) syncRecords(prev.subjects, state.subjects, putSubject, removeSubject);
  if (state.sheets !== prev.sheets) syncRecords(prev.sheets, state.sheets, putSheet, removeSheet);
  if (state.scores !== prev.scores) {
    syncRecords(prev.scores, state.scores, (value, id) => saveScore(id, value), (id) => saveScore(id, null));
  }
  if (state.attendance !== prev.attendance) {
    syncRecords(prev.attendance, state.attendance, putAttendanceDay, removeAttendanceDay);
  }
  if (state.bmi !== prev.bmi) {
    syncRecords(prev.bmi, state.bmi, putBmi, (id) => {
      const [studentId, date] = id.split('::');
      if (studentId && date) removeBmi(studentId, date);
    });
  }
});

function syncRecords<T>(
  prev: Record<string, T>,
  next: Record<string, T>,
  put: (value: T, id: string) => void,
  remove: (id: string) => void,
): void {
  for (const id of Object.keys(next)) {
    if (prev[id] !== next[id]) put(next[id], id);
  }
  for (const id of Object.keys(prev)) {
    if (!(id in next)) remove(id);
  }
}

/* -------------------------------- hydration -------------------------------- */

/**
 * Reads the SQLite database back into memory once at launch (importing anything
 * a pre-SQLite build left in AsyncStorage first). The splash screen waits on
 * `hydrated`, so no screen renders before this finishes.
 */
void (async () => {
  try {
    await migrateLegacyStorage();
    const data = await loadAll();
    useStore.setState({ ...data, hydrated: true });
  } catch (error) {
    console.warn('[store] could not read the SQLite database', error);
    useStore.setState({ hydrated: true });
  }
})();

function nextSeat(students: Record<string, Student>, sectionId: string): number {
  const seats = Object.values(students)
    .filter((s) => s.sectionId === sectionId)
    .map((s) => s.seatNumber);
  return seats.length ? Math.max(...seats) + 1 : 1;
}

/* ------------------------- derived selector helpers ------------------------ */

export function sectionStudents(state: ClassTrackState, sectionId: string | null): Student[] {
  if (!sectionId) return [];
  return Object.values(state.students)
    .filter((s) => s.sectionId === sectionId)
    .sort((a, b) => a.seatNumber - b.seatNumber);
}

export function sectionSubjects(state: ClassTrackState, sectionId: string | null): Subject[] {
  if (!sectionId) return [];
  return Object.values(state.subjects)
    .filter((s) => s.sectionId === sectionId)
    .sort((a, b) => a.createdAt - b.createdAt);
}

/** Full CSV snapshot for exports (matches lib/backup BackupData). */
export function selectBackupData(state: ClassTrackState): BackupData {
  return {
    teacherName: state.teacherName,
    sections: state.sections,
    students: state.students,
    subjects: state.subjects,
    sheets: state.sheets,
    scores: state.scores,
    attendance: state.attendance,
    bmi: state.bmi,
  };
}
