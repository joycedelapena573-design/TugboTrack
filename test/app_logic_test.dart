/// Logic tests for the class record engine: grade computation, transmutation,
/// BMI interpretation and CSV round-trips (all pure Dart, no device needed).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tugbotrack/models/models.dart';
import 'package:tugbotrack/services/bmi.dart';
import 'package:tugbotrack/services/csv.dart';
import 'package:tugbotrack/services/grading.dart';

ScoreSheet _sheet(Map<ComponentKey, List<AssessmentItem>> items) => ScoreSheet(
      id: 'sub1::q1',
      subjectId: 'sub1',
      quarter: 1,
      items: items,
    );

AssessmentItem _item(String id, String title, double max) =>
    AssessmentItem(id: id, title: title, max: max);

void main() {
  group('grade computation', () {
    test('weighted grade across the five components', () {
      final sheet = _sheet({
        ComponentKey.quizzes: [_item('q1', 'Quiz 1', 20)],
        ComponentKey.assignments: [_item('a1', 'Act 1', 20)],
        ComponentKey.activities: [_item('c1', 'Activity 1', 20)],
        ComponentKey.performanceTasks: [_item('p1', 'PT 1', 50)],
        ComponentKey.examinations: [_item('e1', 'Exam 1', 50)],
      });
      const scores = <String, double>{
        'sub1::q1|s1|q1': 18, // 90%
        'sub1::q1|s1|a1': 16, // 80%
        'sub1::q1|s1|c1': 18, // 90%
        'sub1::q1|s1|p1': 45, // 90%
        'sub1::q1|s1|e1': 40, // 80%
      };

      final result = computeQuarterGrade(defaultWeights, false, sheet, scores, 's1');

      // 90*.10 + 80*.10 + 90*.10 + 90*.30 + 80*.40
      expect(result.finalGrade, isNotNull);
      expect(result.finalGrade!, closeTo(85.0, 0.001));
    });

    test('components without scores are skipped and weights redistributed', () {
      final sheet = _sheet({
        ComponentKey.quizzes: [_item('q1', 'Quiz 1', 20)],
      });
      const scores = <String, double>{'sub1::q1|s1|q1': 20}; // 100%

      final result = computeQuarterGrade(defaultWeights, false, sheet, scores, 's1');

      expect(result.finalGrade, isNotNull);
      expect(result.finalGrade!, closeTo(100.0, 0.001));
      expect(result.usedWeights[ComponentKey.quizzes], 10);
      expect(result.usedWeights[ComponentKey.examinations], 0);
    });

    test('no records yet returns a null grade', () {
      final result =
          computeQuarterGrade(defaultWeights, false, null, const {}, 's1');
      expect(result.finalGrade, isNull);
      expect(result.raw, isNull);
    });

    test('DepEd transmutation maps 60 to 75 and caps at 100', () {
      expect(transmuteGrade(60), closeTo(75, 0.001));
      expect(transmuteGrade(100), closeTo(100, 0.001));
      expect(transmuteGrade(55), closeTo(55, 0.001)); // below table: unchanged
      final raw = transmuteGrade(80);
      expect(raw, greaterThan(80), reason: 'transmutation lifts passing grades');
      expect(raw, lessThanOrEqualTo(100));
    });

    test('remarks and achievement labels follow DepEd bands', () {
      expect(gradeRemarks(96), 'With High Honors');
      expect(gradeRemarks(92), 'With Honors');
      expect(gradeRemarks(88), isEmpty);
      expect(gradeRemarks(null), isEmpty);
      expect(achievementLabel(null), 'No records yet');
      expect(achievementLabel(96), 'Outstanding');
      expect(achievementLabel(70), 'Did not meet expectations');
      expect(gradePassed(75), isTrue);
      expect(gradePassed(74), isFalse);
      expect(gradePassed(null), isNull);
    });
  });

  group('BMI', () {
    test('computes BMI from height and weight', () {
      expect(computeBmi(165, 55)!, closeTo(20.2, 0.1));
      expect(computeBmi(0, 55), isNull);
      expect(computeBmi(165, -1), isNull);
    });

    test('interprets the standard cutoffs', () {
      expect(interpretBmi(17.0)!.category, 'Underweight');
      expect(interpretBmi(22.0)!.category, 'Normal');
      expect(interpretBmi(27.0)!.category, 'Overweight');
      expect(interpretBmi(32.0)!.category, 'Obese');
      expect(interpretBmi(null), isNull);
    });
  });

  group('CSV', () {
    test('quotes fields containing commas, quotes or newlines', () {
      final csv = toCsv([
        ['Name', 'Note'],
        ['Dela Cruz, Juan', 'He said "hi"'],
      ]);
      expect(csv, contains('"Dela Cruz, Juan"'));
      expect(csv, contains('"He said ""hi"""'));
      expect(csv.split('\r\n'), hasLength(2));
    });

    test('round-trips through the parser', () {
      final rows = [
        ['Seat', 'Name'],
        [1, 'Dela Cruz, Juan "JD"'],
      ];
      final parsed = parseCsv(toCsv(rows));
      expect(parsed[0], ['Seat', 'Name']);
      expect(parsed[1], ['1', 'Dela Cruz, Juan "JD"']);
    });
  });
}
