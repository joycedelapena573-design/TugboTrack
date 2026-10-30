/// Grade computation engine (DepEd-style weighted components).
library;

import '../models/models.dart';

class ComponentResult {
  const ComponentResult({
    required this.earned,
    required this.max,
    required this.graded,
    required this.total,
    required this.percentage,
  });

  final double earned;

  /// Sum of the highest scores of *graded* items only.
  final double max;
  final int graded;
  final int total;

  /// earned / max * 100, null when nothing is graded yet.
  final double? percentage;

  static const empty = ComponentResult(
    earned: 0,
    max: 0,
    graded: 0,
    total: 0,
    percentage: null,
  );
}

String scoreKey(String sheetId, String studentId, String itemId) =>
    '$sheetId|$studentId|$itemId';

ComponentResult computeComponent(
  ScoreSheet sheet,
  ScoreMap scores,
  String studentId,
  ComponentKey component,
) {
  final items = sheet.items[component] ?? const <AssessmentItem>[];
  var earned = 0.0;
  var max = 0.0;
  var graded = 0;
  for (final item in items) {
    final value = scores[scoreKey(sheet.id, studentId, item.id)];
    if (value != null && !value.isNaN) {
      earned += value;
      max += item.max;
      graded += 1;
    }
  }
  return ComponentResult(
    earned: earned,
    max: max,
    graded: graded,
    total: items.length,
    percentage: max > 0 ? earned / max * 100 : null,
  );
}

class QuarterGradeResult {
  const QuarterGradeResult({
    required this.raw,
    required this.finalGrade,
    required this.transmuted,
    required this.components,
    required this.usedWeights,
  });

  /// Weighted quarterly grade before transmutation.
  final double? raw;

  /// Grade shown to the teacher (after transmutation when enabled).
  final double? finalGrade;
  final bool transmuted;
  final Map<ComponentKey, ComponentResult> components;

  /// Weights actually used (components without graded items are skipped).
  final Map<ComponentKey, double> usedWeights;
}

/// Weighted grade across the five components. Components with no graded items
/// yet are skipped and their weight is redistributed, so the running grade is
/// always fair for what has been recorded so far.
QuarterGradeResult computeQuarterGrade(
  Weights weights,
  bool transmute,
  ScoreSheet? sheet,
  ScoreMap scores,
  String studentId,
) {
  final components = <ComponentKey, ComponentResult>{};
  for (final component in ComponentKey.values) {
    components[component] = sheet != null
        ? computeComponent(sheet, scores, studentId, component)
        : ComponentResult.empty;
  }

  final usedWeights = Map<ComponentKey, double>.from(defaultWeights);
  var weightSum = 0.0;
  var acc = 0.0;
  for (final component in ComponentKey.values) {
    final pct = components[component]!.percentage;
    if (pct == null) {
      usedWeights[component] = 0;
      continue;
    }
    final weight = weights[component] ?? 0;
    weightSum += weight;
    acc += pct * weight / 100;
  }

  if (weightSum == 0) {
    return QuarterGradeResult(
      raw: null,
      finalGrade: null,
      transmuted: false,
      components: components,
      usedWeights: usedWeights,
    );
  }

  final raw = acc / (weightSum / 100);
  return QuarterGradeResult(
    raw: raw,
    finalGrade: transmute ? transmuteGrade(raw) : raw,
    transmuted: transmute,
    components: components,
    usedWeights: usedWeights,
  );
}

/// DepEd transmutation table (DO 8, s. 2015), interpolated between the
/// standard anchor points. Raw grades below 60 are returned unchanged.
const List<List<double>> _transmuteAnchors = [
  [60, 75],
  [65, 79],
  [70, 83],
  [75, 87],
  [80, 91],
  [85, 95],
  [90, 99],
  [100, 100],
];

double transmuteGrade(double raw) {
  if (raw < 60) return raw;
  if (raw >= 100) return 100;
  for (var i = 0; i < _transmuteAnchors.length - 1; i++) {
    final x0 = _transmuteAnchors[i][0];
    final y0 = _transmuteAnchors[i][1];
    final x1 = _transmuteAnchors[i + 1][0];
    final y1 = _transmuteAnchors[i + 1][1];
    if (raw >= x0 && raw <= x1) {
      final t = (raw - x0) / (x1 - x0);
      return y0 + t * (y1 - y0);
    }
  }
  return raw;
}

const double passingGrade = 75;

/// Recognition remarks used on class records.
String gradeRemarks(double? finalGrade) {
  if (finalGrade == null) return '';
  if (finalGrade >= 95) return 'With High Honors';
  if (finalGrade >= 90) return 'With Honors';
  return '';
}

bool? gradePassed(double? finalGrade) {
  if (finalGrade == null) return null;
  return finalGrade >= passingGrade;
}

/// Friendly achievement descriptor for a percentage.
String achievementLabel(double? pct) {
  if (pct == null) return 'No records yet';
  if (pct >= 95) return 'Outstanding';
  if (pct >= 90) return 'Very Satisfactory';
  if (pct >= 85) return 'Satisfactory';
  if (pct >= 80) return 'Fairly Satisfactory';
  if (pct >= 75) return 'Developing';
  return 'Did not meet expectations';
}

class WeightPreset {
  const WeightPreset(this.label, this.weights);

  final String label;
  final Weights weights;
}

const List<WeightPreset> weightPresets = [
  WeightPreset('Standard (10/10/10/30/40)', defaultWeights),
  WeightPreset('Performance-heavy (10/10/10/50/20)', {
    ComponentKey.quizzes: 10,
    ComponentKey.assignments: 10,
    ComponentKey.activities: 10,
    ComponentKey.performanceTasks: 50,
    ComponentKey.examinations: 20,
  }),
  WeightPreset('Exam-heavy (10/10/10/20/50)', {
    ComponentKey.quizzes: 10,
    ComponentKey.assignments: 10,
    ComponentKey.activities: 10,
    ComponentKey.performanceTasks: 20,
    ComponentKey.examinations: 50,
  }),
  WeightPreset('Equal (20/20/20/20/20)', {
    ComponentKey.quizzes: 20,
    ComponentKey.assignments: 20,
    ComponentKey.activities: 20,
    ComponentKey.performanceTasks: 20,
    ComponentKey.examinations: 20,
  }),
];
