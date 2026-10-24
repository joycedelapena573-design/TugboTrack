/** BMI calculation and screening categories. */

export interface BmiCategory {
  label: string;
  tone: 'primary' | 'success' | 'warning' | 'danger';
}

/**
 * Standard WHO adult BMI categories, used as a screening reference only.
 * A proper child/adolescent assessment needs BMI-for-age, which also requires
 * age and sex; see the note surfaced on the BMI screen.
 */
const BANDS: { min: number; label: string; tone: BmiCategory['tone'] }[] = [
  { min: 40, label: 'Obesity Class III', tone: 'danger' },
  { min: 35, label: 'Obesity Class II', tone: 'danger' },
  { min: 30, label: 'Obesity Class I', tone: 'danger' },
  { min: 25, label: 'Overweight', tone: 'warning' },
  { min: 18.5, label: 'Normal weight', tone: 'success' },
  { min: 0, label: 'Underweight', tone: 'primary' },
];

/** BMI = kg / m^2. Height is given in centimetres. Returns null when unusable. */
export function calculateBmi(heightCm: number | null, weightKg: number | null): number | null {
  if (heightCm === null || weightKg === null) return null;
  if (!Number.isFinite(heightCm) || !Number.isFinite(weightKg)) return null;
  if (heightCm <= 0 || weightKg <= 0) return null;
  const metres = heightCm / 100;
  const bmi = weightKg / (metres * metres);
  if (!Number.isFinite(bmi)) return null;
  return Math.round(bmi * 10) / 10;
}

export function categorizeBmi(bmi: number | null): BmiCategory | null {
  if (bmi === null) return null;
  const band = BANDS.find((b) => bmi >= b.min);
  if (!band) return null;
  return { label: band.label, tone: band.tone };
}

export const BMI_NOTE =
  'BMI = kg / m\u00B2. Categories shown use the standard WHO adult cutoffs as a screening ' +
  'reference. For school-age learners the clinical standard is BMI-for-age, which also needs ' +
  'age and sex, so treat these values as a screening indicator rather than a diagnosis.';