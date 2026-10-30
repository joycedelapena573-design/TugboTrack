/// Grade book (requirement 2): record scores for quizzes, assignments,
/// activities, performance tasks and examinations; grades compute instantly
/// with the subject's weights (and optional DepEd transmutation).
library;

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/grading.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'section_form.dart';
import 'student_profile.dart';
import 'subject_form.dart';

String fmtMax(double value) =>
    value == value.roundToDouble() ? value.round().toString() : '$value';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key, this.sectionId, this.subjectId});

  final String? sectionId;
  final String? subjectId;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String _sectionId = '';
  String? _subjectId;
  int _quarter = 1;
  ComponentKey _component = ComponentKey.quizzes;
  String? _activeItemId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (_sectionId.isEmpty) {
      final sorted = state.sections.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _sectionId = widget.sectionId ??
          state.activeSectionId ??
          (sorted.isEmpty ? null : sorted.first.id) ??
          '';
    }
    if (_subjectId == null) {
      final subs = _subjectsOf(state);
      _subjectId = widget.subjectId ?? (subs.isEmpty ? null : subs.first.id);
    }
  }

  List<Subject> _subjectsOf(AppState state) => state.subjects.values
      .where((s) => s.sectionId == _sectionId)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<Student> _rosterOf(AppState state) =>
      state.students.values.where((s) => s.sectionId == _sectionId).toList()
        ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sections = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final section =
        state.sections[_sectionId] ?? (sections.isEmpty ? null : sections.first);

    if (section == null) {
      return Screen(
        child: Column(
          children: [
            const PageHeader(title: 'Grade Book', subtitle: 'Create a class first'),
            EmptyState(
              icon: Ionicons.statsChartOutline,
              title: 'No classes yet',
              subtitle: 'Create a class to start recording grades.',
              actionLabel: 'Create a class',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SectionFormScreen()),
              ),
            ),
          ],
        ),
      );
    }

    final subjectList = _subjectsOf(state);
    final subject = subjectList.where((s) => s.id == _subjectId).firstOrNull ??
        (subjectList.isEmpty ? null : subjectList.first);
    final roster = _rosterOf(state);

    final sheet = subject == null
        ? null
        : state.sheets[state.sheetIdOf(subject.id, _quarter)];
    final items = sheet?.items[_component] ?? const <AssessmentItem>[];
    final activeItem = items.where((it) => it.id == _activeItemId).firstOrNull ??
        (items.isEmpty ? null : items.first);

    final grades = subject == null
        ? <_GradeRow>[]
        : [
            for (final st in roster)
              _GradeRow(
                student: st,
                result: computeQuarterGrade(
                  subject.weights,
                  subject.transmute,
                  sheet,
                  state.scores,
                  st.id,
                ),
              ),
          ];
    final finals =
        grades.map((g) => g.result.finalGrade).whereType<double>().toList();
    final classAverage =
        finals.isEmpty ? null : finals.reduce((a, b) => a + b) / finals.length;

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Grade Book',
            subtitle:
                '${section.gradeLevel} — ${section.section} · SY ${section.schoolYear}',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          if (sections.length > 1)
            _chipRow([
              for (final sec in sections)
                AppChip(
                  label:
                      '${sec.gradeLevel.replaceFirst('Grade ', 'G')} — ${sec.section}',
                  active: sec.id == section.id,
                  onTap: () {
                    setState(() {
                      _sectionId = sec.id;
                      _subjectId = null;
                      _activeItemId = null;
                    });
                    context.read<AppState>().setActiveSection(sec.id);
                  },
                ),
            ]),
          if (subjectList.isEmpty)
            EmptyState(
              icon: Ionicons.bookOutline,
              title: 'No subjects yet',
              subtitle:
                  'Add the subjects you teach for this class to start recording grades.',
              actionLabel: 'Add Subject',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectFormScreen(sectionId: section.id),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _chipRow([
                    for (final sub in subjectList)
                      AppChip(
                        label: sub.name,
                        active: sub.id == subject?.id,
                        onTap: () => setState(() {
                          _subjectId = sub.id;
                          _activeItemId = null;
                        }),
                      ),
                    _AddChip(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubjectFormScreen(sectionId: section.id),
                        ),
                      ),
                    ),
                  ]),
                  if (subject != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Segmented<int>(
                        options: [
                          for (final q in quarters) SegmentedOption(q, 'Q$q'),
                        ],
                        value: _quarter,
                        onChange: (q) => setState(() {
                          _quarter = q;
                          _activeItemId = null;
                        }),
                      ),
                    ),
                    _WeightsNote(
                      subject: subject,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubjectFormScreen(subjectId: subject.id),
                        ),
                      ),
                    ),
                    _chipRow([
                      for (final c in ComponentKey.values)
                        AppChip(
                          label: c.short,
                          active: c == _component,
                          onTap: () => setState(() {
                            _component = c;
                            _activeItemId = null;
                          }),
                        ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 12),
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final item in items)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _ItemChip(
                                  label: '${item.title} · ${fmtMax(item.max)}',
                                  active: item.id == activeItem?.id,
                                  onTap: () =>
                                      setState(() => _activeItemId = item.id),
                                  onLongPress: () => _openItemDialog(item),
                                ),
                              ),
                            _AddChip(
                              label: 'Add ${_component.short}',
                              onTap: () => _openItemDialog(null),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (items.isEmpty)
                      AppCard(
                        child: Text(
                          'No ${_component.label.toLowerCase()} added for Q$_quarter yet. '
                          'Tap “Add” to create the first item (e.g. “Quiz 1” out of 20).',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSoft,
                            height: 1.45,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: AppCard(
                          style: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _TableHead(children: [
                                const _HeadCell('Student', flex: 1),
                                for (final it in items.take(4))
                                  _HeadCell(
                                    '${it.title.replaceAll(RegExp(r'\s+'), '')}\n/${fmtMax(it.max)}',
                                    width: 44,
                                  ),
                                const _HeadCell('%', width: 44),
                              ]),
                              for (final st in roster)
                                _ScoreRow(
                                  student: st,
                                  items: items,
                                  sheetId: sheet?.id,
                                  scores: state.scores,
                                  componentPct: sheet == null
                                      ? null
                                      : computeQuarterGrade(
                                          subject.weights,
                                          subject.transmute,
                                          sheet,
                                          state.scores,
                                          st.id,
                                        ).components[_component]?.percentage,
                                  activeItemId: activeItem?.id,
                                  onTap: activeItem == null
                                      ? null
                                      : () => _openScoreDialog(
                                            st, sheet, activeItem),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                child: Text(
                                  'Tap a row to score the highlighted item'
                                  '${items.length > 4 ? ' (showing first 4 items)' : ''}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textFaint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Quarterly Grades — Q$_quarter',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: AppFonts.bold,
                                color: AppColors.navyDark,
                              ),
                            ),
                          ),
                          if (classAverage != null)
                            Badge(
                              label: 'Avg ${classAverage.toStringAsFixed(1)}',
                              color: AppColors.navy,
                              bg: AppColors.ice,
                            ),
                        ],
                      ),
                    ),
                    AppCard(
                      style: EdgeInsets.zero,
                      child: Column(
                        children: [
                          const _TableHead(children: [
                            _HeadCell('Student', flex: 1),
                            _HeadCell('WW', width: 54),
                            _HeadCell('PT', width: 44),
                            _HeadCell('QA', width: 46),
                            _HeadCell('Grade', width: 52),
                          ]),
                          for (final row in grades)
                            _GradeTableRow(
                              row: row,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StudentProfileScreen(
                                    studentId: row.student.id,
                                  ),
                                ),
                              ),
                            ),
                          if (grades.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Add students to this class to see grades.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'Grades are computed automatically from recorded scores '
                        'and saved on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipRow(List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: children),
          ),
        ),
      );

  /* -------------------------------- dialogs -------------------------------- */

  Future<void> _openItemDialog(AssessmentItem? item) async {
    final titleController = TextEditingController(text: item?.title ?? '');
    final maxController = TextEditingController(
      text: item == null ? '' : fmtMax(item.max),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          item == null
              ? 'New ${_component.label.replaceFirst(RegExp(r's$'), '')}'
              : 'Edit Item',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: AppFonts.bold,
            color: AppColors.navyDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Title (e.g. Quiz 1)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maxController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Highest score (e.g. 20)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (item != null)
            AppButton(
              label: 'Delete',
              variant: ButtonVariant.danger,
              onTap: () {
                final subject = _currentSubject;
                if (subject != null) {
                  context.read<AppState>().deleteItem(
                        subject.id,
                        _quarter,
                        _component,
                        item.id,
                      );
                }
                Navigator.of(dialogContext).pop(true);
              },
            ),
          AppButton(
            label: 'Cancel',
            variant: ButtonVariant.ghost,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: 'Save',
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (saved == true && item == null) {
      final subject = _currentSubject;
      final title = titleController.text.trim();
      final max = double.tryParse(maxController.text.trim()) ?? 0;
      if (subject != null && title.isNotEmpty && max > 0) {
        context
            .read<AppState>()
            .addItem(subject.id, _quarter, _component, title, max);
      }
    } else if (saved == true && item != null) {
      final subject = _currentSubject;
      final title = titleController.text.trim();
      final max = double.tryParse(maxController.text.trim()) ?? 0;
      if (subject != null && title.isNotEmpty && max > 0) {
        context.read<AppState>().updateItem(
              subject.id,
              _quarter,
              _component,
              item.id,
              title: title,
              max: max,
            );
      }
    }
  }

  Subject? get _currentSubject {
    final state = context.read<AppState>();
    return state.subjects.values
        .where((s) => s.sectionId == _sectionId && s.id == _subjectId)
        .firstOrNull;
  }

  Future<void> _openScoreDialog(
    Student student,
    ScoreSheet? sheet,
    AssessmentItem item,
  ) async {
    if (sheet == null) return;
    final state = context.read<AppState>();
    final existing = state.scores[scoreKey(sheet.id, student.id, item.id)];
    final controller = TextEditingController(
      text: existing == null ? '' : fmtMax(existing),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: AppFonts.bold,
            color: AppColors.navyDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.title} — highest score ${fmtMax(item.max)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: AppFonts.bold,
                color: AppColors.text,
              ),
              decoration: const InputDecoration(hintText: '0'),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Clear',
            variant: ButtonVariant.ghost,
            onTap: () {
              state.setScore(sheet.id, student.id, item.id, null);
              Navigator.of(dialogContext).pop();
            },
          ),
          AppButton(
            label: 'Save Score',
            onTap: () {
              HapticFeedback.selectionClick();
              final raw = controller.text.trim();
              final value = raw.isEmpty ? null : double.tryParse(raw);
              if (raw.isEmpty || value != null) {
                state.setScore(sheet.id, student.id, item.id, value);
              }
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }
}

/* --------------------------------- models ---------------------------------- */

class _GradeRow {
  const _GradeRow({required this.student, required this.result});
  final Student student;
  final QuarterGradeResult result;
}

/* ------------------------------ small parts -------------------------------- */

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap, this.label = '+'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.ice,
            border: Border.all(color: AppColors.blue, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(Ionicons.add, size: 15, color: AppColors.navy),
              if (label != '+') ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: AppFonts.semibold,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.blue : AppColors.white,
          border: Border.all(
            color: active ? AppColors.blue : AppColors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFonts.semibold,
            color: active ? AppColors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _WeightsNote extends StatelessWidget {
  const _WeightsNote({required this.subject, required this.onTap});
  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String pct(ComponentKey key) => '${(subject.weights[key] ?? 0).round()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.ice,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            children: [
              const Icon(Ionicons.optionsOutline,
                  size: 15, color: AppColors.textSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Weights: Quiz ${pct(ComponentKey.quizzes)} · '
                  'Assign ${pct(ComponentKey.assignments)} · '
                  'Act ${pct(ComponentKey.activities)} · '
                  'PT ${pct(ComponentKey.performanceTasks)} · '
                  'Exam ${pct(ComponentKey.examinations)}'
                  '${subject.transmute ? ' · transmuted' : ''} — tap to edit',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: AppFonts.medium,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      color: AppColors.ice,
      child: Row(children: children),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.label, {this.flex = 0, this.width});
  final String label;
  final int flex;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: label.length > 6 ? 10 : 11.5,
        fontWeight: AppFonts.bold,
        color: AppColors.navyDark,
      ),
    );
    if (width != null) {
      return SizedBox(width: width, child: text);
    }
    return Expanded(
      child: Align(alignment: Alignment.centerLeft, child: text),
    );
  }
}

/// One score-table row: name + the first four items + the component total.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.student,
    required this.items,
    required this.sheetId,
    required this.scores,
    required this.componentPct,
    required this.activeItemId,
    required this.onTap,
  });

  final Student student;
  final List<AssessmentItem> items;
  final String? sheetId;
  final ScoreMap scores;
  final double? componentPct;
  final String? activeItemId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lastName =
        student.fullName.split(' ').isEmpty ? student.fullName : student.fullName.split(' ').last;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.bg),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student.seatNumber}. $lastName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    student.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items.take(4))
              SizedBox(
                width: 40,
                child: Builder(builder: (context) {
                  final value =
                      sheetId == null ? null : scores[scoreKey(sheetId!, student.id, item.id)];
                  final isActive = activeItemId == item.id;
                  return Text(
                    value == null ? '–' : fmtMax(value),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFonts.medium,
                      color: isActive ? AppColors.blue : AppColors.text,
                      decoration:
                          isActive ? TextDecoration.underline : TextDecoration.none,
                    ),
                  );
                }),
              ),
            SizedBox(
              width: 44,
              child: Text(
                componentPct == null
                    ? '–'
                    : componentPct!.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: AppFonts.bold,
                  color: AppColors.navyDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One computed-grade row: WW / PT / QA / final grade.
class _GradeTableRow extends StatelessWidget {
  const _GradeTableRow({required this.row, required this.onTap});

  final _GradeRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final components = row.result.components;
    List<double> percentages(List<ComponentKey> keys) => [
          for (final key in keys)
            if (components[key]?.percentage != null) components[key]!.percentage!,
        ];

    final wwList = percentages([
      ComponentKey.quizzes,
      ComponentKey.assignments,
      ComponentKey.activities,
    ]);
    final wwPct = wwList.isEmpty
        ? null
        : wwList.reduce((a, b) => a + b) / wwList.length;
    final ptPct = components[ComponentKey.performanceTasks]?.percentage;
    final qaPct = components[ComponentKey.examinations]?.percentage;
    final remarks = gradeRemarks(row.result.finalGrade);
    final lastName = row.student.fullName.split(' ').last;
    final finalGrade = row.result.finalGrade;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.bg)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.student.seatNumber}. $lastName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    remarks.isNotEmpty
                        ? remarks
                        : achievementLabel(row.result.finalGrade),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: remarks.isNotEmpty ? 9.5 : 10,
                      fontWeight: remarks.isNotEmpty
                          ? AppFonts.semibold
                          : AppFonts.regular,
                      color: remarks.isNotEmpty
                          ? AppColors.green
                          : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            _pctCell(wwPct, 54),
            _pctCell(ptPct, 44),
            _pctCell(qaPct, 46),
            SizedBox(
              width: 52,
              child: Text(
                finalGrade == null ? '–' : finalGrade.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFonts.bold,
                  color: finalGrade != null && finalGrade < passingGrade
                      ? AppColors.red
                      : AppColors.navyDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pctCell(double? value, double width) => SizedBox(
        width: width,
        child: Text(
          value == null ? '–' : value.toStringAsFixed(0),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: AppFonts.medium,
            color: AppColors.text,
          ),
        ),
      );
}
