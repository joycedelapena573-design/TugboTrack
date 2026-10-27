/** BMI calculation and interpretation. */

export interface BmiInterpretation {
  category: 'Underweight' | 'Normal' | 'Overweight' | 'Obese';
  color: string;
  bg: string;
  advice: string;
}

export function computeBmi(heightCm: number, weightKg: number): number | null {
  if (!(heightCm > 0) || !(weightKg > 0)) return null;
  const m = heightCm / 100;
  return weightKg / (m * m);
}

/** Standard WHO / DepEd screening cutoffs. */
export function interpretBmi(bmi: number | null): BmiInterpretation | null {
  if (bmi === null || Number.isNaN(bmi)) return null;
  if (bmi < 18.5) {
    return {
      category: 'Underweight',
      color: '#2C5FBF',
      bg: '#E1EBFC',
      advice: 'Below normal weight. A balanced, nutritious diet is recommended.',
    };
  }
  if (bmi < 25) {
    return {
      category: 'Normal',
      color: '#1B7F4B',
      bg: '#DFF5E7',
      advice: 'Healthy weight. Keep up regular physical activity and good eating habits.',
    };
  }
  if (bmi < 30) {
    return {
      category: 'Overweight',
      color: '#B26A00',
      bg: '#FFF1D6',
      advice: 'Above normal weight. More activity and healthier food choices are advised.',
    };
  }
  return {
    category: 'Obese',
    color: '#C0392B',
    bg: '#FDE4E1',
    advice: 'Well above the healthy range. Please consult a health professional.',
  };
}

/** BMI-for-height reference hint (5th–85th percentile style guidance). */
export function bmiForAgeNote(): string {
  return 'Screening uses standard WHO BMI cutoffs. Results are indicative and not a medical diagnosis.';
}
