/**
 * Dependency-free verification of the pure logic: DepEd transmutation, the
 * weighted grade calculation, BMI and CSV parsing.
 *
 * Run with: node scripts/verify-logic.ts
 */
import assert from 'node:assert/strict';

import { calculateBmi, categorizeBmi } from '../src/lib/bmi.ts';
import { parseCsv, pick, toTable } from '../src/lib/csv.ts';
import { computeGrade, componentPercentage, transmute, weightTotal } from '../src/lib/grades.ts';
import type { Assessment, Weights } from '../src/lib/types.ts';

let passed = 0;
const check = (label: string, fn: () => void) => {
  try {
    fn();
    passed += 1;
    console.log(`  ok  ${label}`);
  } catch (error) {
    console.error(`FAIL  ${label}`);
    console.error(error);
    process.exitCode = 1;
  }
};

const assessment = (patch: Partial<Assessment> & { id: string }): Assessment => ({
  classId: 'c1',
  title: 'Test',
  type: 'quiz',
  component: 'ww',
  maxScore: 10,
  date: '2026-06-01',
  scores: {},
  createdAt: 0,
  ...patch,
});

console.log('\nDepEd transmutation table (DO 8, s. 2015)');
check('maps exact table boundaries', () => {
  const expected: [number, number][] = [
    [100, 100],
    [99.99, 99],
    [98.4, 99],
    [98.39, 98],
    [96.8, 98],
    [95.2, 97],
    [85.6, 91],
    [84, 90],
    [80.8, 88],
    [76, 85],
    [61.6, 76],
    [61.59, 75],
    [60, 75],
    [59.99, 74],
    [56, 74],
    [55.99, 73],
    [40, 70],
    [20, 65],
    [7.99, 61],
    [4, 61],
    [3.99, 60],
    [0, 60],
  ];
  for (const [ps, tg] of expected) {
    assert.equal(transmute(ps), tg, `PS ${ps} should transmute to ${tg}, got ${transmute(ps)}`);
  }
});

check('passing grade is 75 and floor is 60', () => {
  assert.equal(transmute(60), 75);
  assert.equal(transmute(0), 60);
  assert.ok(transmute(59.99) < 75);
});

check('clamps out-of-range input', () => {
  assert.equal(transmute(250), 100);
  assert.equal(transmute(-10), 60);
  assert.equal(transmute(Number.NaN), 60);
});

console.log('\nWeighted grade calculation');
check('single student across all three components', () => {
  const weights: Weights = { ww: 40, pt: 40, qa: 20 };
  const assessments = [
    assessment({ id: 'a1', component: 'ww', maxScore: 20, scores: { s1: 18 } }), // 90%
    assessment({ id: 'a2', component: 'pt', maxScore: 50, scores: { s1: 45 } }), // 90%
    assessment({ id: 'a3', component: 'qa', maxScore: 100, scores: { s1: 80 } }), // 80%
  ];
  // 90*0.4 + 90*0.4 + 80*0.2 = 36 + 36 + 16 = 88
  const result = computeGrade(assessments, weights, 's1');
  assert.equal(result.initial, 88);
  assert.equal(result.final, transmute(88));
  assert.equal(result.final, 92); // 75 + (88 - 60) * 25/40 = 92.5 -> 92
});

check('pools multiple assessments inside one component', () => {
  const weights: Weights = { ww: 40, pt: 40, qa: 20 };
  const assessments = [
    assessment({ id: 'a1', component: 'ww', maxScore: 10, scores: { s1: 8 } }), // 8/10
    assessment({ id: 'a2', component: 'ww', maxScore: 30, scores: { s1: 27 } }), // 27/30
    assessment({ id: 'a3', component: 'pt', maxScore: 40, scores: { s1: 40 } }),
    assessment({ id: 'a4', component: 'qa', maxScore: 50, scores: { s1: 50 } }),
  ];
  const ww = componentPercentage(assessments, 'ww', 's1');
  assert.ok(ww !== null);
  assert.ok(Math.abs(ww - (35 / 40) * 100) < 1e-9, `WW% was ${ww}`);
  const result = computeGrade(assessments, weights, 's1');
  assert.ok(result.initial !== null);
  assert.equal(result.final, transmute(result.initial));
});

check('renormalises weights when a component has no data', () => {
  const weights: Weights = { ww: 40, pt: 40, qa: 20 };
  const assessments = [
    assessment({ id: 'a1', component: 'ww', maxScore: 10, scores: { s1: 10 } }), // 100%
    assessment({ id: 'a2', component: 'pt', maxScore: 10, scores: { s1: 5 } }), // 50%
    // no QA work at all
  ];
  const result = computeGrade(assessments, weights, 's1');
  // Active weights 40+40 = 80 -> 50%/50% split -> 75 initial.
  assert.equal(result.initial, 75);
  const applied = result.components.filter((c) => c.percentage !== null);
  assert.equal(applied.reduce((sum, c) => sum + c.appliedWeight, 0), 100);
});

check('students without scores return null rather than zero', () => {
  const weights: Weights = { ww: 40, pt: 40, qa: 20 };
  const assessments = [assessment({ id: 'a1', scores: { s2: 5 } })];
  const result = computeGrade(assessments, weights, 's1');
  assert.equal(result.initial, null);
  assert.equal(result.final, null);
  assert.equal(result.remark, null);
});

check('skips assessments a student has not been scored on', () => {
  const weights: Weights = { ww: 40, pt: 40, qa: 20 };
  const assessments = [
    assessment({ id: 'a1', component: 'ww', maxScore: 10, scores: { s1: 10 } }),
    assessment({ id: 'a2', component: 'ww', maxScore: 10, scores: { s1: 0 } }),
    assessment({ id: 'a3', component: 'ww', maxScore: 10, scores: { s2: 10 } }),
  ];
  const result = computeGrade(assessments, weights, 's1');
  assert.equal(componentPercentage(assessments, 'ww', 's1'), 50);
  assert.equal(result.initial, 50);
});

check('zero weights fall back to an equal split', () => {
  const weights: Weights = { ww: 0, pt: 0, qa: 0 };
  const assessments = [
    assessment({ id: 'a1', component: 'ww', maxScore: 10, scores: { s1: 10 } }),
    assessment({ id: 'a2', component: 'qa', maxScore: 10, scores: { s1: 0 } }),
  ];
  const result = computeGrade(assessments, weights, 's1');
  assert.equal(result.initial, 50);
  assert.equal(weightTotal(weights), 0);
});

check('percentages above 100 still cap the final grade at 100', () => {
  const weights: Weights = { ww: 40, pt: 40, qa: 20 };
  const assessments = [assessment({ id: 'a1', maxScore: 10, scores: { s1: 15 } })];
  const result = computeGrade(assessments, weights, 's1');
  assert.equal(result.final, 100);
});

console.log('\nBMI');
check('computes BMI from cm and kg', () => {
  assert.equal(calculateBmi(160, 50), 19.5);
  assert.equal(calculateBmi(170, 65), 22.5);
  assert.equal(calculateBmi(150, 60), 26.7);
});

check('returns null for missing or impossible measurements', () => {
  assert.equal(calculateBmi(null, 50), null);
  assert.equal(calculateBmi(160, null), null);
  assert.equal(calculateBmi(0, 50), null);
  assert.equal(calculateBmi(160, 0), null);
  assert.equal(calculateBmi(-1, 50), null);
});

check('categorises against WHO adult cutoffs', () => {
  assert.equal(categorizeBmi(17.5)?.label, 'Underweight');
  assert.equal(categorizeBmi(18.5)?.label, 'Normal weight');
  assert.equal(categorizeBmi(24.9)?.label, 'Normal weight');
  assert.equal(categorizeBmi(25)?.label, 'Overweight');
  assert.equal(categorizeBmi(29.9)?.label, 'Overweight');
  assert.equal(categorizeBmi(30)?.label, 'Obesity Class I');
  assert.equal(categorizeBmi(35)?.label, 'Obesity Class II');
  assert.equal(categorizeBmi(40)?.label, 'Obesity Class III');
  assert.equal(categorizeBmi(null), null);
});

console.log('\nCSV');
check('handles quotes, escaped quotes and CRLF', () => {
  const rows = parseCsv('name,section\r\n"Dela Cruz, Juan",Rose\r\n"Maria ""Beth""","Violet"\r\n');
  assert.deepEqual(rows, [
    ['name', 'section'],
    ['Dela Cruz, Juan', 'Rose'],
    ['Maria "Beth"', 'Violet'],
  ]);
});

check('ignores blank lines', () => {
  const rows = parseCsv('name,section\n\nJuan,Rose\n\n');
  assert.equal(rows.length, 2);
});

check('maps headers to records case-insensitively', () => {
  const table = toTable(parseCsv('Student Name,Section\nJuan Dela Cruz,Rose'));
  assert.equal(table.records.length, 1);
  assert.equal(pick(table.records[0], ['name', 'studentname']), 'Juan Dela Cruz');
  assert.equal(pick(table.records[0], ['section', 'sec']), 'Rose');
});

check('falls back to positional columns when no header is present', () => {
  const table = toTable(parseCsv('Juan,Rose'));
  assert.equal(pick(table.records[0], ['col0']), 'Juan');
  assert.equal(pick(table.records[0], ['col1']), 'Rose');
});

check('handles a single-column file', () => {
  const table = toTable(parseCsv('name\nJuan\nMaria'));
  assert.deepEqual(
    table.records.map((r) => r.name),
    ['Juan', 'Maria'],
  );
});

console.log(`\n${passed} checks passed${process.exitCode ? ' (with failures)' : ''}.`);