/** Grade computation engine (DepEd-style weighted components). */
import type { ComponentKey, ScoreMap, ScoreSheet, Weights } from './types';
import { COMPONENTS, DEFAULT_WEIGHTS } from './types';

export interface ComponentResult {
  earned: number;
  /** Sum of the highest scores of *graded* items only. */
  max: number;
  graded: number;
  total: number;
  /** earned / max * 100, null when nothing is graded yet. */
  percentage: number | null;
}

export function scoreKey(sheetId: string, studentId: string, itemId: string): string {
  return `${sheetId}|${studentId}|${itemId}`;
}

export function computeComponent(
  sheet: ScoreSheet,
  scores: ScoreMap,
  studentId: string,
  component: ComponentKey,
): ComponentResult {
  const items = sheet.items[component] ?? [];
  let earned = 0;
  let max = 0;
  let graded = 0;
  for (const item of items) {
    const v = scores[scoreKey(sheet.id, studentId, item.id)];
    if (typeof v === 'number' && !Number.isNaN(v)) {
      earned += v;
      max += item.max;
      graded += 1;
    }
  }
  return {
    earned,
    max,
    graded,
    total: items.length,
    percentage: max > 0 ? (earned / max) * 100 : null,
  };
}

export interface QuarterGradeResult {
  /** Weighted quarterly grade before transmutation. */
  raw: number | null;
  /** Grade shown to the teacher (after transmutation when enabled). */
  final: number | null;
  transmuted: boolean;
  components: Record<ComponentKey, ComponentResult>;
  /** Weights actually used (components without graded items are skipped). */
  usedWeights: Record<ComponentKey, number>;
}

/**
 * Weighted grade across the five components. Components with no graded items
 * yet are skipped and their weight is redistributed, so the running grade is
 * always fair for what has been recorded so far.
 */
export function computeQuarterGrade(
  weights: Weights,
  transmute: boolean,
  sheet: ScoreSheet | undefined,
  scores: ScoreMap,
  studentId: string,
): QuarterGradeResult {
  const components = {} as Record<ComponentKey, ComponentResult>;
  for (const c of COMPONENTS) {
    components[c.key] = sheet
      ? computeComponent(sheet, scores, studentId, c.key)
      : { earned: 0, max: 0, graded: 0, total: 0, percentage: null };
  }
  const usedWeights = { ...DEFAULT_WEIGHTS } as Record<ComponentKey, number>;
  let weightSum = 0;
  let acc = 0;
  for (const c of COMPONENTS) {
    const pct = components[c.key].percentage;
    if (pct === null) {
      usedWeights[c.key] = 0;
      continue;
    }
    weightSum += weights[c.key];
    acc += (pct * weights[c.key]) / 100;
  }
  if (weightSum === 0) {
    return { raw: null, final: null, transmuted: false, components, usedWeights };
  }
  const raw = acc / (weightSum / 100);
  const final = transmute ? transmuteGrade(raw) : raw;
  return { raw, final, transmuted: transmute, components, usedWeights };
}

/**
 * DepEd transmutation table (DO 8, s. 2015), interpolated between the
 * standard anchor points. Raw grades below 60 are returned unchanged.
 */
const TRANSMUTE_ANCHORS: [number, number][] = [
  [60, 75],
  [65, 79],
  [70, 83],
  [75, 87],
  [80, 91],
  [85, 95],
  [90, 99],
  [100, 100],
];

export function transmuteGrade(raw: number): number {
  if (raw < 60) return raw;
  if (raw >= 100) return 100;
  for (let i = 0; i < TRANSMUTE_ANCHORS.length - 1; i++) {
    const [x0, y0] = TRANSMUTE_ANCHORS[i];
    const [x1, y1] = TRANSMUTE_ANCHORS[i + 1];
    if (raw >= x0 && raw <= x1) {
      const t = (raw - x0) / (x1 - x0);
      return y0 + t * (y1 - y0);
    }
  }
  return raw;
}

export const PASSING_GRADE = 75;

/** Recognition remarks used on class records. */
export function gradeRemarks(final: number | null): string {
  if (final === null) return '';
  if (final >= 95) return 'With High Honors';
  if (final >= 90) return 'With Honors';
  return '';
}

export function gradePassed(final: number | null): boolean | null {
  if (final === null) return null;
  return final >= PASSING_GRADE;
}

/** Friendly achievement descriptor for a percentage. */
export function achievementLabel(pct: number | null): string {
  if (pct === null) return 'No records yet';
  if (pct >= 95) return 'Outstanding';
  if (pct >= 90) return 'Very Satisfactory';
  if (pct >= 85) return 'Satisfactory';
  if (pct >= 80) return 'Fairly Satisfactory';
  if (pct >= 75) return 'Developing';
  return 'Did not meet expectations';
}

export const WEIGHT_PRESETS: { label: string; weights: Weights }[] = [
  { label: 'Standard (10/10/10/30/40)', weights: DEFAULT_WEIGHTS },
  {
    label: 'Performance-heavy (10/10/10/50/20)',
    weights: { quizzes: 10, assignments: 10, activities: 10, performanceTasks: 50, examinations: 20 },
  },
  {
    label: 'Exam-heavy (10/10/10/20/50)',
    weights: { quizzes: 10, assignments: 10, activities: 10, performanceTasks: 20, examinations: 50 },
  },
  {
    label: 'Equal (20/20/20/20/20)',
    weights: { quizzes: 20, assignments: 20, activities: 20, performanceTasks: 20, examinations: 20 },
  },
];
