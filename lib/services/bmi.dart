/// BMI calculation and interpretation.
library;

import 'package:flutter/material.dart';

class BmiInterpretation {
  const BmiInterpretation({
    required this.category,
    required this.color,
    required this.bg,
    required this.advice,
  });

  final String category;
  final Color color;
  final Color bg;
  final String advice;
}

double? computeBmi(double heightCm, double weightKg) {
  if (heightCm <= 0 || weightKg <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Standard WHO / DepEd screening cutoffs.
BmiInterpretation? interpretBmi(double? bmi) {
  if (bmi == null || bmi.isNaN) return null;
  if (bmi < 18.5) {
    return const BmiInterpretation(
      category: 'Underweight',
      color: Color(0xFF2C5FBF),
      bg: Color(0xFFE1EBFC),
      advice: 'Below normal weight. A balanced, nutritious diet is recommended.',
    );
  }
  if (bmi < 25) {
    return const BmiInterpretation(
      category: 'Normal',
      color: Color(0xFF1B7F4B),
      bg: Color(0xFFDFF5E7),
      advice:
          'Healthy weight. Keep up regular physical activity and good eating habits.',
    );
  }
  if (bmi < 30) {
    return const BmiInterpretation(
      category: 'Overweight',
      color: Color(0xFFB26A00),
      bg: Color(0xFFFFF1D6),
      advice:
          'Above normal weight. More activity and healthier food choices are advised.',
    );
  }
  return const BmiInterpretation(
    category: 'Obese',
    color: Color(0xFFC0392B),
    bg: Color(0xFFFDE4E1),
    advice: 'Well above the healthy range. Please consult a health professional.',
  );
}

/// BMI-for-height reference hint (5th–85th percentile style guidance).
String bmiForAgeNote() =>
    'Screening uses standard WHO BMI cutoffs. Results are indicative and not a medical diagnosis.';
