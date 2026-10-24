/**
 * DepEd (Philippines) K-12 grading math.
 *
 * Weights come from DepEd Order No. 8, s. 2015 and vary by learning area, so the
 * app ships them as presets and lets the teacher override them per class.
 *
 * Transmutation follows the DO 8, s. 2015 table. Two linear segments reproduce it:
 *   PS >= 60 : TG = floor(75 + (PS - 60) * 25 / 40)
 *   PS <  60 : TG = floor(60 + PS / 4)
 * The passing grade is 75 and the report-card floor is 60.
 */
import type { Assessment, GradingComponent, Weights } from './types';

export const COMPONENTS: GradingComponent[] = ['ww', 'pt', 'qa'];

export const COMPONENT_LABELS: Record<GradingComponent, string> = {
  ww: 'Written Works',
  pt: 'Performance Tasks',
  qa: 'Quarterly Assessment',
};

export const COMPONENT_SHORT: Record<GradingComponent, string> = {
  ww: 'WW',
  pt: 'PT',
  qa: 'QA',
};

export interface WeightPreset {
  key: string;
  label: string;
  weights: Weights;
}

export const WEIGHT_PRESETS: WeightPreset[] = [
  { key: 'math_science', label: 'Math & Science (Grades 1-10)', weights: { ww: 40, pt: 40, qa: 20 } },
  { key: 'languages', label: 'Languages, AP, EsP (Grades 1-10)', weights: { ww: 30, pt: 50, qa: 20 } },
  { key: 'mapeh_epp', label: 'MAPEH, EPP / TLE (Grades 1-10)', weights: { ww: 20, pt: 60, qa: 20 } },
  { key: 'shs_core', label: 'SHS core subjects', weights: { ww: 25, pt: 50, qa: 25 } },
  { key: 'shs_other', label: 'SHS other subjects', weights: { ww: 35, pt: 40, qa: 25 } },
  { key: 'custom', label: 'Custom weights', weights: { ww: 40, pt: 40, qa: 20 } },
];

export const DEFAULT_WEIGHTS: Weights = { ww: 40, pt: 40, qa: 20 };

export function presetByKey(key: string): WeightPreset {
  return WEIGHT_PRESETS.find((p) => p.key === key) ?? WEIGHT_PRESETS[0];
}

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

/** Convert a raw percentage score (0-100) into the transmuted DepEd grade. */
export function transmute(percentage: number): number {
  const ps = clamp(Number.isFinite(percentage) ? percentage : 0, 0, 100);
  if (ps >= 60) return Math.floor(75 + ((ps - 60) * 25) / 40);
  return Math.floor(60 + ps / 4);
}

/** Adviser-style remark for a transmuted grade. */
export function remarkFor(grade: number): string {
  if (grade >= 90) return 'With Highest Honors';
  if (grade >= 85) return 'With High Honors';
  if (grade >= 80) return 'With Honors';
  if (grade >= 75) return 'Passed';
  return 'Needs Improvement';
}

/** Percentage score for one component across a set of assessments. */
export function componentPercentage(
  assessments: Assessment[],
  component: GradingComponent,
  studentId: string,
): number | null {
  let earned = 0;
  let possible = 0;
  for (const a of assessments) {
    if (a.component !== component) continue;
    const score = a.scores[studentId];
    if (score === undefined || score === null) continue;
    earned += score;
    possible += a.maxScore;
  }
  if (possible <= 0) return null;
  return (earned / possible) * 100;
}

export interface ComponentResult {
  component: GradingComponent;
  /** Raw percentage for this component, or null when nothing is scored. */
  percentage: number | null;
  /** Weight actually applied (renormalised across components that have data). */
  appliedWeight: number;
  /** percentage * appliedWeight / 100. */
  weighted: number;
}

export interface GradeResult {
  components: ComponentResult[];
  /** Weighted sum before transmutation; null when there is no scored work yet. */
  initial: number | null;
  /** Transmuted whole-number grade; null when there is no scored work yet. */
  final: number | null;
  remark: string | null;
}

const NO_DATA: GradeResult = { components: [], initial: null, final: null, remark: null };

/**
 * Compute a student's quarterly grade.
 *
 * For each component with scored work: PS -> WS = PS x weight (weights are
 * renormalised over components that actually have data). The weighted scores are
 * summed into the initial grade, which is transmuted once.
 */
export function computeGrade(
  assessments: Assessment[],
  weights: Weights,
  studentId: string,
): GradeResult {
  const raw: ComponentResult[] = COMPONENTS.map((component) => ({
    component,
    percentage: componentPercentage(assessments, component, studentId),
    appliedWeight: 0,
    weighted: 0,
  }));

  const active = raw.filter((c) => c.percentage !== null);
  if (active.length === 0) return NO_DATA;

  let totalWeight = active.reduce((sum, c) => sum + Math.max(0, weights[c.component]), 0);
  if (totalWeight <= 0) {
    // All weights entered as zero: fall back to an equal split so the result is
    // still meaningful rather than silently zero.
    totalWeight = active.length;
    active.forEach((c) => {
      c.appliedWeight = 100 / active.length;
      c.weighted = ((c.percentage ?? 0) * c.appliedWeight) / 100;
    });
  } else {
    active.forEach((c) => {
      const share = Math.max(0, weights[c.component]) / totalWeight;
      c.appliedWeight = share * 100;
      c.weighted = ((c.percentage ?? 0) * c.appliedWeight) / 100;
    });
  }

  const initial = raw.reduce((sum, c) => sum + c.weighted, 0);
  const final = transmute(initial);

  return { components: raw, initial, final, remark: remarkFor(final) };
}

/** Sanity check: weights should add up to 100 before normalisation. */
export function weightTotal(weights: Weights): number {
  return weights.ww + weights.pt + weights.qa;
}