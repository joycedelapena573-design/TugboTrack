/** Domain model for classes, students, assessments and grades. */

/** DepEd assessment components. */
export type GradingComponent = 'ww' | 'pt' | 'qa';

/** Editable percentage split applied to the three components. */
export interface Weights {
  ww: number;
  pt: number;
  qa: number;
}

/** What kind of activity an assessment is. Drives its default component. */
export type AssessmentType = 'quiz' | 'assignment' | 'activity' | 'project' | 'exam';

export interface ClassRecord {
  id: string;
  /** Subject / learning area, e.g. "Mathematics 8". */
  subject: string;
  /** Section name, e.g. "Rose". */
  section: string;
  /** Optional grade level, e.g. "Grade 8". */
  gradeLevel: string;
  schoolYear: string;
  /** Key into WEIGHT_PRESETS; 'custom' when weights were edited by hand. */
  presetKey: string;
  weights: Weights;
  createdAt: number;
}

export interface Student {
  id: string;
  classId: string;
  name: string;
  section: string;
  /** Centimetres; null until recorded. */
  heightCm: number | null;
  /** Kilograms; null until recorded. */
  weightKg: number | null;
  createdAt: number;
}

export interface Assessment {
  id: string;
  classId: string;
  title: string;
  type: AssessmentType;
  component: GradingComponent;
  /** Highest possible score for this assessment. */
  maxScore: number;
  /** ISO date (yyyy-mm-dd) when the assessment was given. */
  date: string;
  /** studentId -> points earned. Absent means "not yet scored". */
  scores: Record<string, number>;
  createdAt: number;
}

export interface AppData {
  version: number;
  classes: ClassRecord[];
  students: Student[];
  assessments: Assessment[];
}

export const EMPTY_DATA: AppData = { version: 1, classes: [], students: [], assessments: [] };