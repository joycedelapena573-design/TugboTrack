/// BMI calculation and age/sex-specific interpretation.
///
/// Adult cut-offs are not valid for growing children and adolescents, so the
/// app screens learners aged 5–19 against the WHO 2007 BMI-for-age reference
/// (the reference DepEd uses for school health screening): thinness below
/// −2 SD, normal between −2 SD and +1 SD, overweight between +1 SD and +2 SD,
/// and obese above +2 SD. Outside that age range the WHO adult cut-offs are
/// used instead. All values are screening aids, not a diagnosis.
library;

import 'package:flutter/material.dart';

class BmiInterpretation {
  const BmiInterpretation({
    required this.category,
    required this.color,
    required this.bg,
    required this.advice,
    this.reference = '',
  });

  final String category;
  final Color color;
  final Color bg;
  final String advice;

  /// Which reference produced the category, e.g. "WHO BMI-for-age, 16 y (M)".
  final String reference;
}

double? computeBmi(double heightCm, double weightKg) {
  if (heightCm <= 0 || weightKg <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// WHO 2007 BMI-for-age cut-offs (kg/m²) for ages 5–19.
///
/// Each row is `[age, −2SD, −1SD, +1SD, +2SD]`. Values are the published
/// sex-specific reference limits; the app interpolates nothing between whole
/// ages and simply picks the learner's completed age.
const Map<String, List<List<double>>> _bmiForAge = {
  'M': [
    [5, 12.1, 13.0, 15.3, 16.6],
    [6, 12.0, 13.0, 15.6, 17.0],
    [7, 12.0, 13.1, 15.9, 17.4],
    [8, 12.1, 13.3, 16.3, 17.9],
    [9, 12.2, 13.5, 16.8, 18.5],
    [10, 12.4, 13.7, 17.3, 19.2],
    [11, 12.7, 14.1, 18.0, 20.0],
    [12, 13.0, 14.5, 18.7, 20.9],
    [13, 13.4, 14.9, 19.4, 21.9],
    [14, 13.8, 15.4, 20.2, 22.9],
    [15, 14.2, 15.9, 21.0, 23.9],
    [16, 14.6, 16.4, 21.8, 24.9],
    [17, 15.0, 16.9, 22.5, 25.8],
    [18, 15.4, 17.4, 23.2, 26.7],
    [19, 15.8, 17.9, 23.9, 27.6],
  ],
  'F': [
    [5, 11.8, 12.7, 15.1, 16.5],
    [6, 11.7, 12.6, 15.3, 16.8],
    [7, 11.7, 12.7, 15.6, 17.3],
    [8, 11.8, 12.8, 16.0, 17.9],
    [9, 11.9, 13.0, 16.5, 18.6],
    [10, 12.1, 13.2, 17.1, 19.4],
    [11, 12.4, 13.6, 17.8, 20.3],
    [12, 12.7, 14.0, 18.5, 21.3],
    [13, 13.1, 14.4, 19.3, 22.3],
    [14, 13.5, 14.9, 20.1, 23.3],
    [15, 13.9, 15.4, 20.9, 24.3],
    [16, 14.3, 15.8, 21.7, 25.2],
    [17, 14.6, 16.2, 22.4, 26.0],
    [18, 14.9, 16.5, 23.0, 26.8],
    [19, 15.1, 16.8, 23.6, 27.5],
  ],
};

const _thin = BmiInterpretation(
  category: 'Thinness',
  color: Color(0xFF2C5FBF),
  bg: Color(0xFFE1EBFC),
  advice: 'Below the healthy range for this age and sex. '
      'A balanced, nutritious diet and a health check are recommended.',
);

const _normal = BmiInterpretation(
  category: 'Normal',
  color: Color(0xFF1B7F4B),
  bg: Color(0xFFDFF5E7),
  advice: 'Healthy weight for this age and sex. '
      'Keep up regular physical activity and good eating habits.',
);

const _overweight = BmiInterpretation(
  category: 'Overweight',
  color: Color(0xFFB26A00),
  bg: Color(0xFFFFF1D6),
  advice: 'Above the healthy range for this age and sex. '
      'More activity and healthier food choices are advised.',
);

const _obese = BmiInterpretation(
  category: 'Obese',
  color: Color(0xFFC0392B),
  bg: Color(0xFFFDE4E1),
  advice: 'Well above the healthy range for this age and sex. '
      'Please consult a health professional.',
);

/// Interprets [bmi] for a learner.
///
/// Pass [ageYears] and [sex] (`'Male'`/`'Female'`, case-insensitive) to use the
/// child/adolescent reference; without them the adult cut-offs are used.
BmiInterpretation? interpretBmi(
  double? bmi, {
  int? ageYears,
  String? sex,
}) {
  if (bmi == null || bmi.isNaN || bmi <= 0) return null;

  final reference = _sexKey(sex);
  if (ageYears != null && reference != null) {
    final rows = _bmiForAge[reference]!;
    final row = rows.where((value) => value[0] == ageYears.toDouble()).firstOrNull;
    if (row != null) {
      final thin = row[1];
      final overweight = row[3];
      final obese = row[4];
      final label = 'WHO BMI-for-age, $ageYears y (${reference == 'M' ? 'M' : 'F'})';
      if (bmi < thin) {
        return BmiInterpretation(
          category: _thin.category,
          color: _thin.color,
          bg: _thin.bg,
          advice: _thin.advice,
          reference: label,
        );
      }
      if (bmi < overweight) {
        return BmiInterpretation(
          category: _normal.category,
          color: _normal.color,
          bg: _normal.bg,
          advice: _normal.advice,
          reference: label,
        );
      }
      if (bmi < obese) {
        return BmiInterpretation(
          category: _overweight.category,
          color: _overweight.color,
          bg: _overweight.bg,
          advice: _overweight.advice,
          reference: label,
        );
      }
      return BmiInterpretation(
        category: _obese.category,
        color: _obese.color,
        bg: _obese.bg,
        advice: _obese.advice,
        reference: label,
      );
    }
  }

  // WHO adult cut-offs.
  const adult = 'WHO adult cut-offs';
  if (bmi < 18.5) {
    return BmiInterpretation(
      category: 'Underweight',
      color: _thin.color,
      bg: _thin.bg,
      advice: _thin.advice,
      reference: adult,
    );
  }
  if (bmi < 25) {
    return BmiInterpretation(
      category: _normal.category,
      color: _normal.color,
      bg: _normal.bg,
      advice: _normal.advice,
      reference: adult,
    );
  }
  if (bmi < 30) {
    return BmiInterpretation(
      category: _overweight.category,
      color: _overweight.color,
      bg: _overweight.bg,
      advice: _overweight.advice,
      reference: adult,
    );
  }
  return BmiInterpretation(
    category: _obese.category,
    color: _obese.color,
    bg: _obese.bg,
    advice: _obese.advice,
    reference: adult,
  );
}

String? _sexKey(String? sex) {
  final value = (sex ?? '').trim().toLowerCase();
  if (value.startsWith('m')) return 'M';
  if (value.startsWith('f')) return 'F';
  return null;
}

/// Short note shown under BMI results.
String bmiForAgeNote({bool forAge = true}) => forAge
    ? 'Screened against the WHO 2007 BMI-for-age reference for learners '
        'aged 5–19, using the record date, birthday and sex.'
    : 'Screening uses standard WHO cut-offs. Results are indicative and not a '
        'medical diagnosis.';
