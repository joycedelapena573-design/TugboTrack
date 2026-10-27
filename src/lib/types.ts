/** Domain types for TIS ClassTrack. All data lives locally on the device. */

export type Quarter = 1 | 2 | 3 | 4;

export const QUARTERS: Quarter[] = [1, 2, 3, 4];

export type ComponentKey =
  | 'quizzes'
  | 'assignments'
  | 'activities'
  | 'performanceTasks'
  | 'examinations';

export const COMPONENTS: { key: ComponentKey; label: string; short: string }[] = [
  { key: 'quizzes', label: 'Quizzes', short: 'QUIZ' },
  { key: 'assignments', label: 'Assignments', short: 'ASSMT' },
  { key: 'activities', label: 'Activities', short: 'ACT' },
  { key: 'performanceTasks', label: 'Performance Tasks', short: 'PT' },
  { key: 'examinations', label: 'Examinations', short: 'EXAM' },
];

/** Weights (in %) that must total 100 across the five components. */
export type Weights = Record<ComponentKey, number>;

export const DEFAULT_WEIGHTS: Weights = {
  quizzes: 10,
  assignments: 10,
  activities: 10,
  performanceTasks: 30,
  examinations: 40,
};

export type AttendanceStatus = 'present' | 'late' | 'absent' | 'excused';

export const ATTENDANCE_META: Record<
  AttendanceStatus,
  { code: string; label: string; color: string; bg: string }
> = {
  present: { code: 'P', label: 'Present', color: '#1B7F4B', bg: '#DFF5E7' },
  late: { code: 'L', label: 'Late', color: '#B26A00', bg: '#FFF1D6' },
  absent: { code: 'A', label: 'Absent', color: '#C0392B', bg: '#FDE4E1' },
  excused: { code: 'E', label: 'Excused', color: '#2C5FBF', bg: '#E1EBFC' },
};

export interface Section {
  id: string;
  /** e.g. "Kindergarten" or "Grade 7" */
  gradeLevel: string;
  /** e.g. "Sampaguita" */
  section: string;
  /** e.g. "2025-2026" */
  schoolYear: string;
  createdAt: number;
}

export type Gender = 'Male' | 'Female' | '';

export interface Student {
  id: string;
  sectionId: string;
  /** Seat number inside the section (used by the seat-based attendance board). */
  seatNumber: number;
  fullName: string;
  lrn: string;
  gender: Gender;
  /** ISO date "YYYY-MM-DD" */
  birthday: string;
  guardianName: string;
  guardianContact: string;
  createdAt: number;
}

export interface Subject {
  id: string;
  sectionId: string;
  name: string;
  teacherName: string;
  weights: Weights;
  /** Use the DepEd transmutation table (DO 8, s. 2015) on quarterly grades. */
  transmute: boolean;
  createdAt: number;
}

export interface AssessmentItem {
  id: string;
  title: string;
  /** Highest possible score for this item. */
  max: number;
}

export interface ScoreSheet {
  /** `${subjectId}::q${quarter}` */
  id: string;
  subjectId: string;
  quarter: Quarter;
  items: Record<ComponentKey, AssessmentItem[]>;
}

/** Flat score map: `${sheetId}|${studentId}|${itemId}` -> score. */
export type ScoreMap = Record<string, number>;

export interface AttendanceDay {
  /** `${sectionId}::${dateISO}` */
  id: string;
  sectionId: string;
  /** ISO date "YYYY-MM-DD" */
  date: string;
  /** studentId -> status */
  statuses: Record<string, AttendanceStatus>;
  markedAt: number;
}

export interface BmiRecord {
  /** `${studentId}::${dateISO}` */
  id: string;
  studentId: string;
  date: string;
  heightCm: number;
  weightKg: number;
  recordedAt: number;
}

export interface TeacherProfile {
  name: string;
}

export const GRADE_LEVELS = [
  'Kindergarten',
  'Grade 1',
  'Grade 2',
  'Grade 3',
  'Grade 4',
  'Grade 5',
  'Grade 6',
  'Grade 7',
  'Grade 8',
  'Grade 9',
  'Grade 10',
  'Grade 11',
  'Grade 12',
];

/** Current school year, e.g. "2025-2026" (Philippine SY runs Aug–Jun). */
export function currentSchoolYear(): string {
  const now = new Date();
  const y = now.getFullYear();
  const startYear = now.getMonth() >= 7 ? y : y - 1; // August onwards
  return `${startYear}-${startYear + 1}`;
}
