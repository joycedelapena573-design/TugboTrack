/// Domain types for TugboTrack. All data lives locally on the device.
library;

/// The DepEd three-term academic calendar: Term 1, Term 2, Term 3.
const List<int> terms = [1, 2, 3];

/// Terms used by the previous build (Q1..Q4). Kept only so the database
/// migration can read old rows; the UI never offers them.
const List<int> legacyQuarters = [1, 2, 3, 4];

String termLabel(int term) => 'Term $term';

String termShortLabel(int term) => 'T$term';

/// Curriculum followed by the class. Grading weights differ between them and
/// a subject can override its own weights either way.
enum Curriculum {
  existingShs('existingShs', 'Existing SHS'),
  strengthenedShs('strengthenedShs', 'Strengthened SHS');

  const Curriculum(this.name, this.label);

  /// Storage key (stable; used in SQLite and backups).
  final String name;
  final String label;

  static Curriculum fromName(String? value) {
    for (final value0 in values) {
      if (value0.name == value) return value0;
    }
    return Curriculum.existingShs;
  }
}

/// The three graded components of a DepEd class record.
enum AssessmentCategory {
  writtenWorks('writtenWorks', 'Written Works', 'WW', 'Written Work'),
  performanceTasks('performanceTasks', 'Performance Tasks', 'PT', 'Performance Task'),
  termExam('termExam', 'Term Examination', 'TE', 'Term Examination');

  const AssessmentCategory(this.name, this.label, this.short, this.singular);

  /// Storage key, e.g. `writtenWorks`.
  final String name;

  /// Human label, e.g. `Performance Tasks`.
  final String label;

  /// Short label used on narrow score grids, e.g. `PT`.
  final String short;

  /// Singular form used in dialogs, e.g. `Written Work`.
  final String singular;

  static AssessmentCategory? fromName(String? value) => switch (value) {
        // current keys
        'writtenWorks' => AssessmentCategory.writtenWorks,
        'performanceTasks' => AssessmentCategory.performanceTasks,
        'termExam' => AssessmentCategory.termExam,
        // keys written by the earlier quarterly build
        'quizzes' || 'assignments' || 'activities' => AssessmentCategory.writtenWorks,
        'examinations' => AssessmentCategory.termExam,
        _ => null,
      };
}

/// Weights (in %) that must total 100 across the three categories.
typedef Weights = Map<AssessmentCategory, double>;

/// DepEd Order 8, s. 2015 weights for most SHS academic subjects.
const Weights depedAcademicWeights = {
  AssessmentCategory.writtenWorks: 25,
  AssessmentCategory.performanceTasks: 50,
  AssessmentCategory.termExam: 25,
};

/// Weights for TVL / Arts and Design / Sports track subjects.
const Weights depedTvlWeights = {
  AssessmentCategory.writtenWorks: 20,
  AssessmentCategory.performanceTasks: 60,
  AssessmentCategory.termExam: 20,
};

/// Weights used by subjects whose assessment is largely performance based
/// (e.g. practicum, research).
const Weights depedPerformanceWeights = {
  AssessmentCategory.writtenWorks: 20,
  AssessmentCategory.performanceTasks: 60,
  AssessmentCategory.termExam: 20,
};

/// A named, reusable weight set stored in `grading_configurations`.
class GradingConfig {
  const GradingConfig({
    required this.id,
    required this.name,
    required this.curriculum,
    required this.weights,
    this.transmute = true,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final Curriculum curriculum;
  final Weights weights;

  /// Apply the DO 8, s. 2015 transmutation table to term grades.
  final bool transmute;
  final bool isDefault;

  double weightOf(AssessmentCategory category) => weights[category] ?? 0;

  double get total => weights.values.fold(0, (sum, value) => sum + value);

  bool get isValid => (total - 100).abs() < 0.001;

  GradingConfig copyWith({
    String? name,
    Weights? weights,
    bool? transmute,
    bool? isDefault,
  }) {
    return GradingConfig(
      id: id,
      name: name ?? this.name,
      curriculum: curriculum,
      weights: weights ?? this.weights,
      transmute: transmute ?? this.transmute,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Presets offered in the subject form. They are seeded into the database on
/// first launch and can be edited in Settings.
const List<GradingConfig> builtInGradingConfigs = [
  GradingConfig(
    id: 'cfg-existing-academic',
    name: 'Existing SHS — Academic (25/50/25)',
    curriculum: Curriculum.existingShs,
    weights: depedAcademicWeights,
    isDefault: true,
  ),
  GradingConfig(
    id: 'cfg-existing-tvl',
    name: 'Existing SHS — TVL / Arts & Sports (20/60/20)',
    curriculum: Curriculum.existingShs,
    weights: depedTvlWeights,
  ),
  GradingConfig(
    id: 'cfg-strengthened-academic',
    name: 'Strengthened SHS — Academic (25/50/25)',
    curriculum: Curriculum.strengthenedShs,
    weights: depedAcademicWeights,
    isDefault: true,
  ),
  GradingConfig(
    id: 'cfg-strengthened-tvl',
    name: 'Strengthened SHS — TVL / Arts & Sports (20/60/20)',
    curriculum: Curriculum.strengthenedShs,
    weights: depedTvlWeights,
  ),
];

GradingConfig defaultConfigFor(Curriculum curriculum) => builtInGradingConfigs
    .firstWhere((config) => config.curriculum == curriculum && config.isDefault);

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

/// School year, e.g. `2026-2027`.
class SchoolYear {
  const SchoolYear({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isActive = false,
  });

  final String id;

  /// e.g. "2026-2027"
  final String name;
  final bool isActive;
  final int createdAt;

  SchoolYear copyWith({String? name, bool? isActive}) => SchoolYear(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        isActive: isActive ?? this.isActive,
      );
}

/// One of the three terms of a school year.
class AcademicTerm {
  const AcademicTerm({
    required this.id,
    required this.schoolYear,
    required this.term,
    required this.start,
    required this.end,
  });

  final String id;

  /// School year name, e.g. "2026-2027".
  final String schoolYear;

  /// 1..3
  final int term;

  /// ISO date "YYYY-MM-DD".
  final String start;
  final String end;

  String get label => 'Term $term';
}

/// A class (grade level + section) taught during a school year.
///
/// A class owns its roster and subjects; its subjects can each run for one,
/// two or all three terms, and archiving a class keeps every record intact.
class Section {
  const Section({
    required this.id,
    required this.gradeLevel,
    required this.section,
    required this.schoolYear,
    required this.createdAt,
    this.curriculum = Curriculum.existingShs,
    this.archived = false,
  });

  final String id;

  /// e.g. "Grade 11"
  final String gradeLevel;

  /// e.g. "Sampaguita"
  final String section;

  /// e.g. "2026-2027"
  final String schoolYear;

  final Curriculum curriculum;
  final bool archived;
  final int createdAt;

  Section copyWith({
    String? gradeLevel,
    String? section,
    String? schoolYear,
    Curriculum? curriculum,
    bool? archived,
  }) {
    return Section(
      id: id,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      section: section ?? this.section,
      schoolYear: schoolYear ?? this.schoolYear,
      curriculum: curriculum ?? this.curriculum,
      archived: archived ?? this.archived,
      createdAt: createdAt,
    );
  }

  String get title => '$gradeLevel — $section';

  /// "G11 — Sampaguita"
  String get shortTitle =>
      '$gradeLevel — $section'.replaceFirst('Grade ', 'G');
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
    this.archived = false,
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
  final bool archived;
  final int createdAt;

  Student copyWith({
    String? sectionId,
    int? seatNumber,
    String? fullName,
    String? lrn,
    String? gender,
    String? birthday,
    String? guardianName,
    String? guardianContact,
    bool? archived,
  }) {
    return Student(
      id: id,
      sectionId: sectionId ?? this.sectionId,
      seatNumber: seatNumber ?? this.seatNumber,
      fullName: fullName ?? this.fullName,
      lrn: lrn ?? this.lrn,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      guardianName: guardianName ?? this.guardianName,
      guardianContact: guardianContact ?? this.guardianContact,
      archived: archived ?? this.archived,
      createdAt: createdAt,
    );
  }

  /// Age in whole years on [on] (null when the birthday is unknown/malformed).
  int? ageAt([DateTime? on]) {
    final birth = DateTime.tryParse(birthday);
    if (birth == null) return null;
    final now = on ?? DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }
}

/// A subject taught in a class for one, two or all three terms.
class Subject {
  const Subject({
    required this.id,
    required this.sectionId,
    required this.name,
    required this.teacherName,
    required this.weights,
    required this.transmute,
    required this.createdAt,
    this.termStart = 1,
    this.termEnd = 3,
    this.configId = '',
  });

  final String id;
  final String sectionId;
  final String name;
  final String teacherName;
  final Weights weights;

  /// Use the DepEd transmutation table (DO 8, s. 2015) on term grades.
  final bool transmute;

  /// First term the subject is offered (1..3).
  final int termStart;

  /// Last term the subject is offered (1..3, inclusive).
  final int termEnd;

  /// Grading configuration the weights came from ('' when custom).
  final String configId;
  final int createdAt;

  Subject copyWith({
    String? name,
    String? teacherName,
    Weights? weights,
    bool? transmute,
    int? termStart,
    int? termEnd,
    String? configId,
  }) {
    return Subject(
      id: id,
      sectionId: sectionId,
      name: name ?? this.name,
      teacherName: teacherName ?? this.teacherName,
      weights: weights ?? this.weights,
      transmute: transmute ?? this.transmute,
      termStart: termStart ?? this.termStart,
      termEnd: termEnd ?? this.termEnd,
      configId: configId ?? this.configId,
      createdAt: createdAt,
    );
  }

  /// Terms this subject is actually offered in, in order.
  List<int> get activeTerms =>
      [for (final term in terms) if (term >= termStart && term <= termEnd) term];

  bool covers(int term) => term >= termStart && term <= termEnd;

  String get termSpanLabel => termStart == termEnd
      ? 'Term $termStart'
      : termStart == 1 && termEnd == 3
          ? 'Whole year'
          : 'Terms $termStart–$termEnd';
}

/// One assessment (quiz, activity, performance task, exam ...) inside a
/// subject and term.
class AssessmentItem {
  const AssessmentItem({
    required this.id,
    required this.title,
    required this.max,
    this.category = AssessmentCategory.writtenWorks,
  });

  final String id;
  final String title;

  /// Highest possible score for this item.
  final double max;
  final AssessmentCategory category;

  AssessmentItem copyWith({
    String? title,
    double? max,
    AssessmentCategory? category,
  }) {
    return AssessmentItem(
      id: id,
      title: title ?? this.title,
      max: max ?? this.max,
      category: category ?? this.category,
    );
  }
}

/// The assessments and scores of one subject in one term.
class ScoreSheet {
  /// `${subjectId}::t$term`
  const ScoreSheet({
    required this.id,
    required this.subjectId,
    required this.term,
    required this.items,
  });

  final String id;
  final String subjectId;
  final int term;

  /// Category -> assessment items, in the order they were added.
  final Map<AssessmentCategory, List<AssessmentItem>> items;

  ScoreSheet copyWith({Map<AssessmentCategory, List<AssessmentItem>>? items}) {
    return ScoreSheet(
      id: id,
      subjectId: subjectId,
      term: term,
      items: items ?? this.items,
    );
  }

  List<AssessmentItem> itemsOf(AssessmentCategory category) =>
      items[category] ?? const <AssessmentItem>[];

  int get itemCount =>
      items.values.fold(0, (sum, list) => sum + list.length);
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

  int countOf(AttendanceStatus status) =>
      statuses.values.where((value) => value == status).length;
}

/// A persisted term grade (one row per subject + term + student).
class TermGradeRecord {
  const TermGradeRecord({
    required this.subjectId,
    required this.term,
    required this.studentId,
    required this.initialGrade,
    required this.termGrade,
    required this.computedAt,
  });

  final String subjectId;
  final int term;
  final String studentId;

  /// Weighted grade before transmutation.
  final double initialGrade;

  /// Grade written on the report card (transmuted when enabled).
  final double termGrade;
  final int computedAt;
}

/// A persisted final grade for a subject (average of its term grades).
class FinalGradeRecord {
  const FinalGradeRecord({
    required this.subjectId,
    required this.studentId,
    required this.grade,
    required this.computedAt,
  });

  final String subjectId;
  final String studentId;
  final double grade;
  final int computedAt;
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

/// Grade levels offered by the school.
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

/// Current school year, e.g. "2026-2027" (Philippine SY runs Aug–Jun).
String currentSchoolYear([DateTime? now]) {
  final date = now ?? DateTime.now();
  final startYear = date.month >= 8 ? date.year : date.year - 1;
  return '$startYear-${startYear + 1}';
}

/// The school year the calendar tables should be seeded with.
const String defaultSchoolYear = '2026-2027';

/// Which term of [schoolYear] a date falls in, best effort (returns null when
/// the date is outside every term range).
int? termForDate(String schoolYear, String dateISO, List<AcademicTerm> all) {
  for (final term in all) {
    if (term.schoolYear != schoolYear) continue;
    if (dateISO.compareTo(term.start) >= 0 && dateISO.compareTo(term.end) <= 0) {
      return term.term;
    }
  }
  return null;
}
