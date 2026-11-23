/// Grade book: assessments (Written Works, Performance Tasks, Term Exam) for a
/// subject in a term, score entry, and the automatic initial → term → final
/// grade computation.
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
import 'score_grid.dart';
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
  int _term = 1;
  AssessmentCategory _category = AssessmentCategory.writtenWorks;
  String? _activeItemId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (_sectionId.isEmpty) {
      final classes = state.classesOf(state.activeSchoolYear);
      _sectionId = widget.sectionId ??
          state.activeSectionId ??
          (classes.isEmpty ? '' : classes.first.id);
    }
    _term = state.activeTerm;
    if (_subjectId == null) {
      final subjects = state.subjectsOf(_sectionId);
      _subjectId = widget.subjectId ?? (subjects.isEmpty ? null : subjects.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final classes = state.classesOf(state.activeSchoolYear);

    if (classes.isEmpty) {
      return Screen(
        child: Column(
          children: [
            const PageHeader(
              title: 'Grade Book',
              subtitle: 'Create a class first',
            ),
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

    final section = state.sections[_sectionId] ?? classes.first;
    final subjectList = state.subjectsOf(section.id);
    final subject =
        subjectList.where((value) => value.id == _subjectId).firstOrNull ??
            (subjectList.isEmpty ? null : subjectList.first);

    if (subject != null && !subject.covers(_term)) {
      // The selected subject is not offered this term; fall back to the first
      // subject that is, so the term view never shows an impossible subject.
      final inTerm = subjectList.where((value) => value.covers(_term)).toList();
      if (inTerm.isNotEmpty && !inTerm.any((value) => value.id == subject.id)) {
        _subjectId = inTerm.first.id;
      }
    }

    final activeSubject =
        subjectList.where((value) => value.id == _subjectId).firstOrNull ??
            (subjectList.isEmpty ? null : subjectList.first);
    final roster = state.studentsOf(section.id);
    final sheet = activeSubject == null
        ? null
        : state.sheetOf(activeSubject.id, _term);
    final items = sheet?.itemsOf(_category) ?? const <AssessmentItem>[];
    final activeItem = items.where((item) => item.id == _activeItemId).firstOrNull ??
        (items.isEmpty ? null : items.first);

    final grades = activeSubject == null
        ? <_GradeRow>[]
        : [
            for (final student in roster)
              _GradeRow(
                student: student,
                result: state.gradeOf(activeSubject, _term, student.id),
                finalGrade: state.finalGradeOf(activeSubject, student.id),
              ),
          ];
    final termValues =
        grades.map((row) => row.result.termGrade).whereType<double>().toList();
    final classAverage = termValues.isEmpty
        ? null
        : termValues.reduce((a, b) => a + b) / termValues.length;

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Grade Book',
            subtitle:
                '${section.title} · SY ${section.schoolYear} · ${termLabel(_term)}',
            onBack: () => Navigator.of(context).maybePop(),
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundButton(
                  icon: Ionicons.gridOutline,
                  onTap: activeSubject == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ScoreGridScreen(
                                subjectId: activeSubject.id,
                                term: _term,
                              ),
                            ),
                          ),
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: Ionicons.settingsOutline,
                  onTap: activeSubject == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SubjectFormScreen(
                                subjectId: activeSubject.id,
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
          if (classes.length > 1)
            _chipRow([
              for (final value in classes)
                AppChip(
                  label: value.shortTitle,
                  active: value.id == section.id,
                  onTap: () {
                    setState(() {
                      _sectionId = value.id;
                      _subjectId = null;
                      _activeItemId = null;
                    });
                    context.read<AppState>().setActiveSection(value.id);
                  },
                ),
            ]),
          if (subjectList.isEmpty)
            Expanded(
              child: EmptyState(
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
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 26),
                children: [
                  _chipRow([
                    for (final value in subjectList)
                      AppChip(
                        label: value.covers(_term)
                            ? value.name
                            : '${value.name} (${value.termSpanLabel})',
                        active: value.id == activeSubject?.id,
                        onTap: () => setState(() {
                          _subjectId = value.id;
                          _activeItemId = null;
                        }),
                      ),
                    _AddChip(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubjectFormScreen(sectionId: section.id),
                        ),
                      ),
                    ),
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Segmented<int>(
                      options: [
                        for (final term in terms)
                          SegmentedOption(term, termShortLabel(term)),
                      ],
                      value: _term,
                      onChange: (term) {
                        setState(() {
                          _term = term;
                          _activeItemId = null;
                        });
                        context.read<AppState>().setActiveTerm(term);
                      },
                    ),
                  ),
                  if (activeSubject == null)
                    const EmptyState(
                      icon: Ionicons.bookOutline,
                      title: 'No subject selected',
                      subtitle: 'Choose a subject above.',
                    )
                  else if (!activeSubject.covers(_term))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: AppCard(
                        child: Row(
                          children: [
                            const Icon(
                              Ionicons.informationCircleOutline,
                              size: 20,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${activeSubject.name} is offered in '
                                '${activeSubject.termSpanLabel}, not in ${termLabel(_term)}. '
                                'Scores for this term are still kept separately.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSoft,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _WeightsNote(
                      subject: activeSubject,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubjectFormScreen(subjectId: activeSubject.id),
                        ),
                      ),
                    ),
                    _chipRow([
                      for (final category in AssessmentCategory.values)
                        AppChip(
                          label: category.short,
                          active: category == _category,
                          onTap: () => setState(() {
                            _category = category;
                            _activeItemId = null;
                          }),
                        ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 10),
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
                              label: 'Add ${_category.short}',
                              onTap: () => _openItemDialog(null),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppCard(
                          child: Text(
                            'No ${_category.label.toLowerCase()} recorded for '
                            '${termLabel(_term)} yet. Tap “Add ${_category.short}” to '
                            'create the first one (for example “${_category.singular} 1” '
                            'out of 20).',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSoft,
                              height: 1.45,
                            ),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppCard(
                          style: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _TableHead(children: [
                                const _HeadCell('Learner', flex: 1),
                                for (final item in items.take(3))
                                  _HeadCell(
                                    '${item.title.replaceAll(RegExp(r'\s+'), '')}\n/${fmtMax(item.max)}',
                                    width: 52,
                                  ),
                                const _HeadCell('Score', width: 58),
                              ]),
                              for (final student in roster)
                                _ScoreRow(
                                  student: student,
                                  items: items.take(3).toList(),
                                  sheetId: sheet!.id,
                                  scores: state.scores,
                                  activeItemId: activeItem?.id,
                                  onTap: activeItem == null
                                      ? null
                                      : () => _openScoreDialog(
                                            state,
                                            activeSubject,
                                            sheet,
                                            student,
                                            activeItem,
                                          ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                child: Text(
                                  activeItem == null
                                      ? 'Add an assessment to start scoring.'
                                      : 'Tap a learner to score “${activeItem.title}” '
                                          '(highest ${fmtMax(activeItem.max)}).',
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
                              'Term Grades — ${termLabel(_term)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AppCard(
                        style: EdgeInsets.zero,
                        child: Column(
                          children: [
                            const _TableHead(children: [
                              _HeadCell('Learner', flex: 1),
                              _HeadCell('WW', width: 38),
                              _HeadCell('PT', width: 38),
                              _HeadCell('TE', width: 38),
                              _HeadCell('Init.', width: 42),
                              _HeadCell('Grade', width: 48),
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
                                  'Add learners to this class to see grades.',
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
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Text(
                        'Grades compute automatically from the recorded scores: '
                        'initial grade = weighted WW/PT/TE, term grade = '
                        '${activeSubject.transmute ? 'transmuted (DO 8, s. 2015)' : 'initial grade'}, '
                        'final grade = average of the term grades.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textFaint,
                          height: 1.4,
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
    final state = context.read<AppState>();
    final subject = state.subject(_subjectId);
    if (subject == null) return;
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
              ? 'New ${_category.singular}'
              : 'Edit ${_category.singular}',
          style: const TextStyle(
            fontFamily: 'Poppins',
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
              textCapitalization: TextCapitalization.words,
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
                hintText: 'Highest possible score (e.g. 20)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Term $_term · ${_category.label}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textFaint,
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
                state.deleteItem(subject.id, _term, _category, item.id);
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

    if (!mounted || saved != true) return;
    final title = titleController.text.trim();
    final max = double.tryParse(maxController.text.trim()) ?? 0;
    if (title.isEmpty || max <= 0) return;
    if (item == null) {
      final created = state.addItem(subject.id, _term, _category, title, max);
      setState(() => _activeItemId = created.id);
    } else {
      state.updateItem(subject.id, _term, _category, item.id, title: title, max: max);
    }
  }

  Future<void> _openScoreDialog(
    AppState state,
    Subject subject,
    ScoreSheet sheet,
    Student student,
    AssessmentItem item,
  ) async {
    final key = scoreKey(sheet.id, student.id, item.id);
    final controller = TextEditingController(
      text: state.scores[key] == null ? '' : fmtMax(state.scores[key]!),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          student.fullName,
          maxLines: 2,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: AppFonts.bold,
            color: AppColors.navyDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.title} · highest ${fmtMax(item.max)}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSoft),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                hintText: 'Score',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Clear',
            variant: ButtonVariant.danger,
            onTap: () {
              state.setScore(
                sheet.id,
                student.id,
                item.id,
                null,
                term: _term,
                subjectId: subject.id,
              );
              Navigator.of(dialogContext).pop(false);
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

    if (!mounted || saved != true) return;
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null) return;
    final clamped = parsed.clamp(0, item.max).toDouble();
    state.setScore(
      sheet.id,
      student.id,
      item.id,
      clamped,
      term: _term,
      subjectId: subject.id,
    );
  }
}

/* --------------------------------- widgets -------------------------------- */

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.border, width: 1.5),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.navy),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap, this.label = 'Add'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Ionicons.add, size: 15, color: AppColors.navy),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: AppFonts.semibold,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
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
    this.onLongPress,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? AppColors.navy : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: AppFonts.semibold,
              color: active ? AppColors.white : AppColors.text,
            ),
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
      color: AppColors.ice,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(children: children),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(this.label, {this.width, this.flex});

  final String label;
  final double? width;
  final int? flex;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      textAlign: width == null ? TextAlign.left : TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10.5,
        fontWeight: AppFonts.semibold,
        color: AppColors.navy,
        height: 1.2,
      ),
    );
    if (flex != null) return Expanded(flex: flex!, child: child);
    return SizedBox(width: width, child: child);
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.student,
    required this.items,
    required this.sheetId,
    required this.scores,
    required this.activeItemId,
    this.onTap,
  });

  final Student student;
  final List<AssessmentItem> items;
  final String sheetId;
  final ScoreMap scores;
  final String? activeItemId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: AppFonts.medium,
                    color: AppColors.text,
                  ),
                ),
              ),
              for (final item in items)
                SizedBox(
                  width: 52,
                  child: Text(
                    scores[scoreKey(sheetId, student.id, item.id)] == null
                        ? '—'
                        : fmtMax(scores[scoreKey(sheetId, student.id, item.id)]!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: item.id == activeItemId
                          ? AppFonts.bold
                          : AppFonts.medium,
                      color: item.id == activeItemId
                          ? AppColors.navy
                          : AppColors.text,
                    ),
                  ),
                ),
              SizedBox(
                width: 58,
                child: Text(
                  activeItemId == null
                      ? '—'
                      : (scores[scoreKey(sheetId, student.id, activeItemId!)] ==
                              null
                          ? '—'
                          : fmtMax(
                              scores[scoreKey(sheetId, student.id, activeItemId!)]!,
                            )),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: AppFonts.bold,
                    color: AppColors.navy,
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

class _GradeRow {
  const _GradeRow({
    required this.student,
    required this.result,
    required this.finalGrade,
  });

  final Student student;
  final TermGradeResult result;
  final double? finalGrade;
}

class _GradeTableRow extends StatelessWidget {
  const _GradeTableRow({required this.row, this.onTap});

  final _GradeRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String pct(AssessmentCategory category) {
      final value = row.result.components[category]?.percentage;
      return value == null ? '—' : value.toStringAsFixed(1);
    }

    final grade = row.result.displayGrade;
    final passed = grade == null ? null : grade >= passingGrade;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: AppFonts.medium,
                        color: AppColors.text,
                      ),
                    ),
                    if (row.finalGrade != null)
                      Text(
                        'Final ${reportGrade(row.finalGrade!)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 38,
                child: _Cell(pct(AssessmentCategory.writtenWorks)),
              ),
              SizedBox(
                width: 38,
                child: _Cell(pct(AssessmentCategory.performanceTasks)),
              ),
              SizedBox(width: 38, child: _Cell(pct(AssessmentCategory.termExam))),
              SizedBox(
                width: 42,
                child: _Cell(
                  row.result.initialGrade == null
                      ? '—'
                      : row.result.initialGrade!.toStringAsFixed(1),
                  faint: true,
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  grade == null ? '—' : '$grade',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: AppFonts.bold,
                    color: passed == null
                        ? AppColors.textFaint
                        : (passed ? AppColors.navy : AppColors.red),
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

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.faint = false});

  final String text;
  final bool faint;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        color: faint ? AppColors.textFaint : AppColors.text,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AppCard(
            style: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Ionicons.calculatorOutline,
                    size: 18, color: AppColors.navy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      for (final category in AssessmentCategory.values)
                        '${category.short} ${(subject.weights[category] ?? 0).round()}%',
                    ].join(' · '),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  subject.termSpanLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
