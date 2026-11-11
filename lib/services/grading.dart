/// Grade computation engine for TugboTrack.
///
/// Every subject is graded on the three DepEd components — Written Works (WW),
/// Performance Tasks (PT) and the Term Examination (TE). Each subject carries
/// its own weights (they cannot all be assumed to match), the weighted total is
/// the *initial grade*, and the *term grade* is the initial grade after the
/// transmutation table of DepEd Order 8, s. 2015 (when enabled). The *final
/// grade* of a subject is the average of its term grades across the terms the
/// subject is offered.
library;

import '../models/models.dart';

/// Result of one assessment category for one student.
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
  AssessmentCategory category,
) {
  final items = sheet.itemsOf(category);
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

/// Rounds half-up to [decimals] places without binary-float drift
/// (0.1 + 0.2 style artefacts never leak into a grade).
double roundTo(double value, [int decimals = 2]) {
  final factor = _pow10(decimals);
  return _roundHalfUp(value * factor) / factor;
}

double _pow10(int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

/// Half-up rounding on a scaled value, immune to 1.005 -> 1.00 style errors.
double _roundHalfUp(double value) {
  if (value.isNaN || value.isInfinite) return 0;
  final floor = value.floorToDouble();
  final fraction = value - floor;
  if (fraction > 0.5 - 1e-9) return floor + 1;
  return floor;
}

/// Grade written on the report card: whole numbers only.
int reportGrade(double value) => _roundHalfUp(value).toInt();

class TermGradeResult {
  const TermGradeResult({
    required this.initialGrade,
    required this.termGrade,
    required this.transmuted,
    required this.components,
    required this.usedWeights,
  });

  /// Weighted grade before transmutation, rounded to two decimals.
  final double? initialGrade;

  /// Grade shown to the teacher (transmuted when enabled).
  final double? termGrade;
  final bool transmuted;
  final Map<AssessmentCategory, ComponentResult> components;

  /// Weights actually used (categories without graded items are skipped).
  final Map<AssessmentCategory, double> usedWeights;

  static const empty = TermGradeResult(
    initialGrade: null,
    termGrade: null,
    transmuted: false,
    components: {},
    usedWeights: {},
  );

  /// Integer grade for tables and reports (null when nothing is graded yet).
  int? get displayGrade => termGrade == null ? null : reportGrade(termGrade!);

  bool get hasGrade => termGrade != null;
}

/// Weighted grade across WW / PT / TE for one student in one term.
///
/// Categories with no graded items yet are skipped and their weight is
/// redistributed over the categories that do have scores, so the running grade
/// is always fair for what has been recorded so far.
TermGradeResult computeTermGrade(
  Weights weights,
  bool transmute,
  ScoreSheet? sheet,
  ScoreMap scores,
  String studentId,
) {
  final components = <AssessmentCategory, ComponentResult>{};
  for (final category in AssessmentCategory.values) {
    components[category] = sheet != null
        ? computeComponent(sheet, scores, studentId, category)
        : ComponentResult.empty;
  }

  final usedWeights = <AssessmentCategory, double>{
    for (final category in AssessmentCategory.values) category: 0,
  };
  var weightSum = 0.0;
  var accumulated = 0.0;
  for (final category in AssessmentCategory.values) {
    final pct = components[category]!.percentage;
    if (pct == null) continue;
    final weight = weights[category] ?? 0;
    if (weight <= 0) continue;
    usedWeights[category] = weight;
    weightSum += weight;
    accumulated += pct * weight / 100;
  }

  if (weightSum <= 0) {
    return TermGradeResult(
      initialGrade: null,
      termGrade: null,
      transmuted: transmute,
      components: components,
      usedWeights: usedWeights,
    );
  }

  // Renormalise so the result is on the 0–100 scale even when some categories
  // have no scores yet (weightSum is the total weight actually used).
  final initial = roundTo(accumulated / (weightSum / 100), 2);
  return TermGradeResult(
    initialGrade: initial,
    termGrade: transmute ? transmuteGrade(initial) : initial,
    transmuted: transmute,
    components: components,
    usedWeights: usedWeights,
  );
}

/* ------------------------------ transmutation ----------------------------- */

/// DepEd Order 8, s. 2015 transmutation table.
///
/// Initial grades are banded every 1.6 points starting at 60.00 -> 75 and
/// ending at 100 -> 100. A grade below 60 is retained unchanged so a failing
/// learner is never rounded up into a passing grade.
const double _transmutationBase = 60;
const double _transmutationStep = 1.6;

double transmuteGrade(double initialGrade) {
  if (initialGrade.isNaN) return initialGrade;
  if (initialGrade >= 100) return 100;
  if (initialGrade < _transmutationBase) return initialGrade;
  final band =
      ((initialGrade - _transmutationBase) / _transmutationStep + 1e-9).floor();
  final grade = 75 + band;
  return grade > 100 ? 100 : grade.toDouble();
}

/// The full table as (lowest initial grade, term grade) pairs, for the
/// "Grading configuration" help sheet.
List<({double from, double to, int grade})> transmutationTable() {
  final rows = <({double from, double to, int grade})>[];
  for (var band = 0; band <= 24; band++) {
    final from = roundTo(_transmutationBase + _transmutationStep * band, 2);
    final to = roundTo(_transmutationBase + _transmutationStep * (band + 1), 2);
    rows.add((from: from, to: to, grade: 75 + band));
  }
  rows.add((from: 100, to: 100, grade: 100));
  return rows.reversed.toList();
}

const double passingGrade = 75;

/// Average of the term grades a subject already has. Terms without a grade are
/// skipped; the result is null when none has been computed yet.
double? computeFinalGrade(List<double?> termGrades) {
  final valid = termGrades.whereType<double>().toList();
  if (valid.isEmpty) return null;
  final sum = valid.fold<double>(0, (total, grade) => total + grade);
  return roundTo(sum / valid.length, 2);
}

/// DepEd descriptors used on the report card (DO 8, s. 2015).
String gradeDescriptors(double? grade) {
  if (grade == null) return '';
  if (grade >= 90) return 'Outstanding';
  if (grade >= 85) return 'Very Satisfactory';
  if (grade >= 80) return 'Satisfactory';
  if (grade >= 75) return 'Fairly Satisfactory';
  return 'Did Not Meet Expectations';
}

/// Legacy helper kept for the class-record remarks column.
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

/// Validates a weight set entered by the teacher.
String? validateWeights(Weights weights) {
  for (final category in AssessmentCategory.values) {
    final value = weights[category] ?? 0;
    if (value < 0) return '${category.short} weight cannot be negative.';
    if (value > 100) return '${category.short} weight cannot exceed 100.';
  }
  final total = weights.values.fold<double>(0, (sum, value) => sum + value);
  if ((total - 100).abs() > 0.001) {
    return 'Weights must total 100% (currently ${roundTo(total, 1)}%).';
  }
  return null;
}
