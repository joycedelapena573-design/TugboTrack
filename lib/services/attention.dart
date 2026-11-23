/// "Needs attention" checks for the dashboard: the small set of things a
/// teacher should fix before grades are due. Pure functions over a
/// [BackupData] snapshot so they can be tested without a database.
library;

import '../models/models.dart';
import 'backup.dart';
import 'grading.dart';

/// What kind of follow-up an [AttentionItem] asks for.
enum AttentionKind { missingBmi, frequentAbsence, noAssessments, failing }

class AttentionItem {
  const AttentionItem({
    required this.kind,
    required this.title,
    required this.detail,
    this.sectionId,
    this.studentId,
    this.count = 1,
  });

  final AttentionKind kind;
  final String title;
  final String detail;
  final String? sectionId;
  final String? studentId;

  /// How many learners/records this item covers.
  final int count;
}

/// Learners with at least this many absences in a term get flagged.
const int absenceFlagThreshold = 3;

/// Builds the dashboard checklist for [term].
///
/// [calendar] supplies the term date ranges (an empty list means "count every
/// recorded attendance day"). [sectionId] limits the check to one class and
/// [schoolYear] to one school year.
List<AttentionItem> attentionItems(
  BackupData data, {
  required int term,
  List<AcademicTerm> calendar = const [],
  String? sectionId,
  String? schoolYear,
}) {
  final items = <AttentionItem>[];
  final sections = data.sections.values.where((section) {
    if (section.archived) return false;
    if (schoolYear != null && section.schoolYear != schoolYear) return false;
    if (sectionId != null && section.id != sectionId) return false;
    return true;
  }).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (final section in sections) {
    final roster = data.rosterOf(section.id);
    if (roster.isEmpty) continue;

    // 1. Learners without a BMI measurement.
    final withoutBmi =
        roster.where((student) => !_hasBmi(data, student.id)).toList();
    if (withoutBmi.isNotEmpty) {
      items.add(AttentionItem(
        kind: AttentionKind.missingBmi,
        title: withoutBmi.length == 1
            ? '1 learner has no BMI record'
            : '${withoutBmi.length} learners have no BMI record',
        detail: '${section.gradeLevel} — ${section.section}',
        sectionId: section.id,
        count: withoutBmi.length,
      ));
    }

    // 2. Subjects with no assessments for the term.
    for (final subject in data.subjectsOf(section.id)) {
      if (!subject.covers(term)) continue;
      final sheet = data.sheetOf(subject.id, term);
      if ((sheet?.itemCount ?? 0) > 0) continue;
      items.add(AttentionItem(
        kind: AttentionKind.noAssessments,
        title: 'No assessments in ${termLabel(term)}',
        detail: '${subject.name} · ${section.section}',
        sectionId: section.id,
        count: 1,
      ));
    }

    final range = _termRange(calendar, section.schoolYear, term);

    for (final student in roster) {
      // 3. Repeated absences in this term.
      final absences = _absenceCount(data, section.id, student.id, range);
      if (absences >= absenceFlagThreshold) {
        items.add(AttentionItem(
          kind: AttentionKind.frequentAbsence,
          title: '$absences absences in ${termLabel(term)}',
          detail: '${student.fullName} · ${section.section}',
          sectionId: section.id,
          studentId: student.id,
          count: absences,
        ));
      }

      // 4. Failing final grade.
      final failing = <String>[];
      for (final subject in data.subjectsOf(section.id)) {
        final grade = data.finalGradeOf(subject, student.id);
        if (grade != null && grade < passingGrade) failing.add(subject.name);
      }
      if (failing.isNotEmpty) {
        items.add(AttentionItem(
          kind: AttentionKind.failing,
          title: 'Below passing in ${failing.length} '
              '${failing.length == 1 ? 'subject' : 'subjects'}',
          detail: '${student.fullName} · ${section.section} · '
              '${failing.join(', ')}',
          sectionId: section.id,
          studentId: student.id,
          count: failing.length,
        ));
      }
    }
  }

  // Most actionable first: missing grades before missing measurements.
  const order = {
    AttentionKind.failing: 0,
    AttentionKind.noAssessments: 1,
    AttentionKind.frequentAbsence: 2,
    AttentionKind.missingBmi: 3,
  };
  items.sort((a, b) {
    final byKind = order[a.kind]!.compareTo(order[b.kind]!);
    return byKind != 0 ? byKind : a.title.compareTo(b.title);
  });
  return items;
}

bool _hasBmi(BackupData data, String studentId) =>
    data.bmi.values.any((record) => record.studentId == studentId);

({String start, String end})? _termRange(
  List<AcademicTerm> calendar,
  String schoolYear,
  int term,
) {
  for (final value in calendar) {
    if (value.schoolYear != schoolYear || value.term != term) continue;
    if (value.start.isEmpty || value.end.isEmpty) return null;
    return (start: value.start, end: value.end);
  }
  return null;
}

int _absenceCount(
  BackupData data,
  String sectionId,
  String studentId,
  ({String start, String end})? range,
) {
  var count = 0;
  for (final day in data.attendance.values) {
    if (day.sectionId != sectionId) continue;
    if (range != null &&
        (day.date.compareTo(range.start) < 0 ||
            day.date.compareTo(range.end) > 0)) {
      continue;
    }
    if (day.statuses[studentId] == AttendanceStatus.absent) count += 1;
  }
  return count;
}

/// Per-learner attendance totals used by badges in the roster.
class LearnerAttendance {
  const LearnerAttendance({
    required this.recorded,
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
  });

  final int recorded;
  final int present;
  final int late;
  final int absent;
  final int excused;

  int get attendanceCount => present + late;

  double get rate => recorded == 0 ? 0 : attendanceCount / recorded * 100;
}
