/// Domain types for TIS ClassTrack. All data lives locally on the device.
library;

/// Grading period: 1 = Q1 … 4 = Q4.
const List<int> quarters = [1, 2, 3, 4];

/// The five graded components. [name] is the key used in stored JSON/CSV and
/// must stay identical to the earlier TypeScript build's keys.
enum ComponentKey {
  quizzes('quizzes', 'Quizzes', 'QUIZ'),
  assignments('assignments', 'Assignments', 'ASSMT'),
  activities('activities', 'Activities', 'ACT'),
  performanceTasks('performanceTasks', 'Performance Tasks', 'PT'),
  examinations('examinations', 'Examinations', 'EXAM');

  const ComponentKey(this.name, this.label, this.short);

  /// Storage key, e.g. `performanceTasks`.
  final String name;

  /// Human label, e.g. `Performance Tasks`.
  final String label;

  /// Short label used on narrow score grids, e.g. `PT`.
  final String short;

  static ComponentKey? fromName(String value) {
    for (final key in values) {
      if (key.name == value) return key;
    }
    return null;
  }
}

/// Weights (in %) that must total 100 across the five components.
typedef Weights = Map<ComponentKey, double>;

const Weights defaultWeights = {
  ComponentKey.quizzes: 10,
  ComponentKey.assignments: 10,
  ComponentKey.activities: 10,
  ComponentKey.performanceTasks: 30,
  ComponentKey.examinations: 40,
};

/// Daily attendance marks, shown as letter codes on the seat board.
enum AttendanceStatus {
  present('Present', 'P'),
  late('Late', 'L'),
  absent('Absent', 'A'),
  excused('Excused', 'E');

  const AttendanceStatus(this.label, this.code);

  final String label;
  final String code;

  static AttendanceStatus? fromName(String value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return null;
  }
}

class Section {
  const Section({
    required this.id,
    required this.gradeLevel,
    required this.section,
    required this.schoolYear,
    required this.createdAt,
  });

  final String id;

  /// e.g. "Grade 11"
  final String gradeLevel;

  /// e.g. "Sampaguita"
  final String section;

  /// e.g. "2025-2026"
  final String schoolYear;

  final int createdAt;

  Section copyWith({
    String? gradeLevel,
    String? section,
    String? schoolYear,
  }) {
    return Section(
      id: id,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      schoolYear: schoolYear ?? this.schoolYear,
      createdAt: createdAt,
    );
  }

  String get title => '$gradeLevel — $section';
}

class Student {
  const Student({
    required this.id,
    required this.sectionId,
    required this.seatNumber,
    required this.fullName,
    required this.lrn,
    required this.gender,
    required this.birthday,
    required this.guardianName,
    required this.guardianContact,
    required this.createdAt,
  });

  final String id;
  final String sectionId;

  /// Seat number inside the section (used by the seat-based attendance board).
  final int seatNumber;
  final String fullName;

  /// Learners Reference Number.
  final String lrn;

  /// 'Male', 'Female' or '' when not set.
  final String gender;

  /// ISO date "YYYY-MM-DD".
  final String birthday;
  final String guardianName;
  final String guardianContact;
  final int createdAt;

  Student copyWith({
    int? seatNumber,
    String? fullName,
    String? lrn,
    String? gender,
    String? birthday,
    String? guardianName,
    String? guardianContact,
  }) {
    return Student(
      id: id,
      sectionId: sectionId,
      seatNumber: seatNumber ?? this.seatNumber,
      fullName: fullName ?? this.fullName,
      lrn: lrn ?? this.lrn,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      guardianName: guardianName ?? this.guardianName,
      guardianContact: guardianContact ?? this.guardianContact,
      createdAt: createdAt,
    );
  }
}

class Subject {
  const Subject({
    required this.id,
    required this.sectionId,
    required this.name,
    required this.teacherName,
    required this.weights,
    required this.transmute,
    required this.createdAt,
  });

  final String id;
  final String sectionId;
  final String name;
  final String teacherName;
  final Weights weights;

  /// Use the DepEd transmutation table (DO 8, s. 2015) on quarterly grades.
  final bool transmute;
  final int createdAt;

  Subject copyWith({
    String? name,
    String? teacherName,
    Weights? weights,
    bool? transmute,
  }) {
    return Subject(
      id: id,
      sectionId: sectionId,
      name: name ?? this.name,
      teacherName: teacherName ?? this.teacherName,
      weights: weights ?? this.weights,
      transmute: transmute ?? this.transmute,
      createdAt: createdAt,
    );
  }
}

class AssessmentItem {
  const AssessmentItem({required this.id, required this.title, required this.max});

  final String id;
  final String title;

  /// Highest possible score for this item.
  final double max;

  AssessmentItem copyWith({String? title, double? max}) {
    return AssessmentItem(
      id: id,
      title: title ?? this.title,
      max: max ?? this.max,
    );
  }
}

class ScoreSheet {
  /// `${subjectId}::q$quarter`
  const ScoreSheet({
    required this.id,
    required this.subjectId,
    required this.quarter,
    required this.items,
  });

  final String id;
  final String subjectId;
  final int quarter;

  /// Component -> assessment items, in the order they were added.
  final Map<ComponentKey, List<AssessmentItem>> items;

  ScoreSheet copyWith({Map<ComponentKey, List<AssessmentItem>>? items}) {
    return ScoreSheet(
      id: id,
      subjectId: subjectId,
      quarter: quarter,
      items: items ?? this.items,
    );
  }
}

/// Flat score map: `${sheetId}|${studentId}|${itemId}` -> score.
typedef ScoreMap = Map<String, double>;

class AttendanceDay {
  /// `${sectionId}::$dateISO`
  const AttendanceDay({
    required this.id,
    required this.sectionId,
    required this.date,
    required this.statuses,
    required this.markedAt,
  });

  final String id;
  final String sectionId;

  /// ISO date "YYYY-MM-DD".
  final String date;

  /// studentId -> status
  final Map<String, AttendanceStatus> statuses;
  final int markedAt;

  AttendanceDay copyWith({
    Map<String, AttendanceStatus>? statuses,
    int? markedAt,
  }) {
    return AttendanceDay(
      id: id,
      sectionId: sectionId,
      date: date,
      statuses: statuses ?? this.statuses,
      markedAt: markedAt ?? this.markedAt,
    );
  }
}

class BmiRecord {
  /// `${studentId}::$dateISO`
  const BmiRecord({
    required this.id,
    required this.studentId,
    required this.date,
    required this.heightCm,
    required this.weightKg,
    required this.recordedAt,
  });

  final String id;
  final String studentId;
  final String date;
  final double heightCm;
  final double weightKg;
  final int recordedAt;
}

/// Grade levels offered by the school. The New Class form offers senior high
/// (11–12) only, per the latest design annotation.
const List<String> gradeLevels = [
  'Kindergarten',
  'Grade 1',
  'Grade 2',
  'Grade 3',
  'Grade 4',
  'Grade 5',
  'Grade 6',
  'Grade 7',
  'Grade 8',
  'Grade 9',
  'Grade 10',
  'Grade 11',
  'Grade 12',
];

/// Grade levels selectable when creating a class (senior high school).
const List<String> selectableGradeLevels = ['Grade 11', 'Grade 12'];

/// Current school year, e.g. "2025-2026" (Philippine SY runs Aug–Jun).
String currentSchoolYear([DateTime? now]) {
  final date = now ?? DateTime.now();
  final startYear = date.month >= 8 ? date.year : date.year - 1;
  return '$startYear-${startYear + 1}';
}
