/// Spreadsheet-style score entry: every learner down the side, every
/// assessment of the term across the top. Keyboard/Tab moves between cells,
/// scores save as you go, and a column can be filled for the whole class in
/// one step.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/grading.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

class ScoreGridScreen extends StatefulWidget {
  const ScoreGridScreen({
    super.key,
    required this.subjectId,
    required this.term,
  });

  final String subjectId;
  final int term;

  @override
  State<ScoreGridScreen> createState() => _ScoreGridScreenState();
}

class _ScoreGridScreenState extends State<ScoreGridScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  String _layoutKey = '';
  late int _term = widget.term;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _cellKey(String studentId, String itemId) => '$studentId|$itemId';

  /// Creates (or keeps) one controller per score cell for the current layout.
  void _syncControllers(AppState state, ScoreSheet sheet, List<Student> roster) {
    final items = [
      for (final category in AssessmentCategory.values)
        ...sheet.itemsOf(category),
    ];
    final layout = '${sheet.id}::${items.map((i) => i.id).join(',')}::'
        '${roster.map((s) => s.id).join(',')}';
    if (layout == _layoutKey) return;
    _layoutKey = layout;

    final live = <String>{};
    for (final student in roster) {
      for (final item in items) {
        final key = _cellKey(student.id, item.id);
        live.add(key);
        final score = state.scores[scoreKey(sheet.id, student.id, item.id)];
        final text = score == null ? '' : formatScore(score);
        final existing = _controllers[key];
        if (existing == null) {
          _controllers[key] = TextEditingController(text: text);
          _focusNodes[key] = FocusNode();
        } else if (existing.text.isEmpty && text.isNotEmpty) {
          existing.text = text;
        }
      }
    }
    for (final key in _controllers.keys.toList()) {
      if (live.contains(key)) continue;
      _controllers.remove(key)?.dispose();
      _focusNodes.remove(key)?.dispose();
    }
  }

  void _commit(
    AppState state,
    ScoreSheet sheet,
    Student student,
    AssessmentItem item,
  ) {
    final controller = _controllers[_cellKey(student.id, item.id)];
    if (controller == null) return;
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      state.setScore(
        sheet.id,
        student.id,
        item.id,
        null,
        term: _term,
        subjectId: sheet.subjectId,
      );
      return;
    }
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null) {
      controller.text =
          formatScore(state.scores[scoreKey(sheet.id, student.id, item.id)]);
      return;
    }
    final clamped = value.clamp(0, item.max).toDouble();
    if (clamped != value) controller.text = formatScore(clamped);
    state.setScore(
      sheet.id,
      student.id,
      item.id,
      clamped,
      term: _term,
      subjectId: sheet.subjectId,
    );
  }

  Future<void> _fillColumn(
    AppState state,
    ScoreSheet sheet,
    AssessmentItem item,
    List<Student> roster,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Fill ${item.title}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: AppFonts.bold,
            color: AppColors.navyDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Give every learner the same score (highest ${formatScore(item.max)}). '
              'Individual scores can still be changed afterwards.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            label: 'Cancel',
            variant: ButtonVariant.ghost,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: 'Apply to all',
            onTap: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
      ),
    );
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (parsed == null) return;
    final clamped = parsed.clamp(0, item.max).toDouble();
    for (final student in roster) {
      final key = _cellKey(student.id, item.id);
      _controllers[key]?.text = formatScore(clamped);
      state.setScore(
        sheet.id,
        student.id,
        item.id,
        clamped,
        term: _term,
        subjectId: sheet.subjectId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final subject = state.subject(widget.subjectId);
    final section = state.section(subject?.sectionId);

    if (subject == null || section == null) {
      return Screen(
        child: Column(
          children: [
            const PageHeader(title: 'Score Grid'),
            const Expanded(
              child: EmptyState(
                icon: Ionicons.gridOutline,
                title: 'Subject not found',
                subtitle: 'It may have been deleted.',
              ),
            ),
          ],
        ),
      );
    }

    // Never create a sheet during build; the Grade Book is where assessments
    // are created, so a missing sheet simply means "nothing to score yet".
    final sheet = state.sheetOf(subject.id, _term);
    final roster = state.studentsOf(section.id);
    if (sheet != null) _syncControllers(state, sheet, roster);

    final columns = <({AssessmentCategory category, AssessmentItem item})>[
      for (final category in AssessmentCategory.values)
        for (final item in sheet?.itemsOf(category) ?? const <AssessmentItem>[])
          (category: category, item: item),
    ];

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Score Grid',
            subtitle: '${subject.name} · ${section.section} · ${termLabel(_term)}',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Segmented<int>(
              options: [
                for (final term in subject.activeTerms)
                  SegmentedOption(term, termShortLabel(term)),
              ],
              value: subject.covers(_term) ? _term : subject.activeTerms.first,
              onChange: (term) => setState(() => _term = term),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: roster.isEmpty
                ? const EmptyState(
                    icon: Ionicons.peopleOutline,
                    title: 'No learners',
                    subtitle: 'Add learners to this class first.',
                  )
                : sheet == null || columns.isEmpty
                    ? const EmptyState(
                        icon: Ionicons.createOutline,
                        title: 'No assessments yet',
                        subtitle:
                            'Add a Written Work, Performance Task or Term Exam '
                            'from the Grade Book, then come back here.',
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 30),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppShadow.soft,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeaderRow(
                                  columns: columns,
                                  onFill: (item) =>
                                      _fillColumn(state, sheet, item, roster),
                                ),
                                for (var index = 0; index < roster.length; index++)
                                  _LearnerRow(
                                    student: roster[index],
                                    columns: columns,
                                    controllers: _controllers,
                                    focusNodes: _focusNodes,
                                    cellKey: _cellKey,
                                    stripe: index.isOdd,
                                    termGrade: state
                                        .gradeOf(subject, _term, roster[index].id)
                                        .termGrade,
                                    onCommit: (item) => _commit(
                                      state,
                                      sheet,
                                      roster[index],
                                      item,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
          if (roster.isNotEmpty && sheet != null && columns.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Text(
                'Type a score and press Enter (or tap elsewhere) to save. Tap a '
                'column header to fill the whole class at once.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.onFill});

  final List<({AssessmentCategory category, AssessmentItem item})> columns;
  final void Function(AssessmentItem item) onFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ice,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text(
              'Learner',
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFonts.semibold,
                color: AppColors.navy,
              ),
            ),
          ),
          for (final column in columns)
            SizedBox(
              width: 62,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () => onFill(column.item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Text(
                          column.category.short,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: AppFonts.semibold,
                            color: AppColors.textFaint,
                          ),
                        ),
                        Text(
                          '${column.item.title}\n/${formatScore(column.item.max)}',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: AppFonts.semibold,
                            color: AppColors.navy,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(
            width: 56,
            child: Text(
              'Grade',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFonts.semibold,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnerRow extends StatelessWidget {
  const _LearnerRow({
    required this.student,
    required this.columns,
    required this.controllers,
    required this.focusNodes,
    required this.cellKey,
    required this.stripe,
    required this.termGrade,
    required this.onCommit,
  });

  final Student student;
  final List<({AssessmentCategory category, AssessmentItem item})> columns;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final String Function(String, String) cellKey;
  final bool stripe;
  final double? termGrade;
  final void Function(AssessmentItem item) onCommit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: stripe ? AppColors.bg : AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              student.fullName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: AppFonts.medium,
                color: AppColors.text,
                height: 1.25,
              ),
            ),
          ),
          for (final column in columns)
            SizedBox(
              width: 62,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: controllers[cellKey(student.id, column.item.id)],
                    focusNode: focusNodes[cellKey(student.id, column.item.id)],
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(AppRadius.sm)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(AppRadius.sm)),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    onSubmitted: (_) => onCommit(column.item),
                    onTapOutside: (_) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      onCommit(column.item);
                    },
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 56,
            child: Text(
              termGrade == null ? '-' : '${reportGrade(termGrade!)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFonts.bold,
                color: termGrade == null
                    ? AppColors.textFaint
                    : (termGrade! < passingGrade
                        ? AppColors.red
                        : AppColors.navy),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
