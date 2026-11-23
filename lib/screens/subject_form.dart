/// Add or edit a subject: name, term span, grading weights, transmutation.
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/grading.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class SubjectFormScreen extends StatefulWidget {
  const SubjectFormScreen({super.key, this.sectionId, this.subjectId});

  final String? sectionId;
  final String? subjectId;

  @override
  State<SubjectFormScreen> createState() => _SubjectFormScreenState();
}

class _SubjectFormScreenState extends State<SubjectFormScreen> {
  late final TextEditingController _name;
  Weights _weights = Map<AssessmentCategory, double>.from(depedAcademicWeights);
  bool _transmute = true;
  int _termStart = 1;
  int _termEnd = 3;
  String _configId = '';
  String _error = '';

  /// Contiguous term spans offered to the teacher, including single-term
  /// electives and whole-year subjects.
  static const List<(int, int)> _spans = [
    (1, 1),
    (2, 2),
    (3, 3),
    (1, 2),
    (2, 3),
    (1, 3),
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    final existing = _existing();
    if (existing == null) {
      // New subjects start from the weights the teacher used last time.
      final remembered = context.read<AppState>().lastSubjectWeights;
      if (remembered != null) {
        _weights = Map<AssessmentCategory, double>.from(remembered);
      }
    }
    if (existing != null) {
      _name.text = existing.name;
      _weights = Map<AssessmentCategory, double>.from(existing.weights);
      _transmute = existing.transmute;
      _termStart = existing.termStart;
      _termEnd = existing.termEnd;
      _configId = existing.configId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Subject? _existing() {
    final id = widget.subjectId;
    if (id == null) return null;
    return context.read<AppState>().subjects[id];
  }

  double get _total =>
      _weights.values.fold<double>(0, (sum, value) => sum + value);

  void _applyPreset(GradingConfig config) {
    setState(() {
      _weights = Map<AssessmentCategory, double>.from(config.weights);
      _transmute = config.transmute;
      _configId = config.id;
      _error = '';
    });
  }

  void _onSave() {
    final state = context.read<AppState>();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the subject name.');
      return;
    }
    final weightError = validateWeights(_weights);
    if (weightError != null) {
      setState(() => _error = weightError);
      return;
    }
    final subjectId = widget.subjectId;
    if (subjectId != null) {
      state.updateSubject(
        subjectId,
        name: _name.text.trim(),
        weights: _weights,
        transmute: _transmute,
        termStart: _termStart,
        termEnd: _termEnd,
        configId: _configId,
      );
    } else {
      state.addSubject(
        sectionId: widget.sectionId ?? '',
        name: _name.text.trim(),
        teacherName: state.teacherName,
        weights: _weights,
        transmute: _transmute,
        termStart: _termStart,
        termEnd: _termEnd,
        configId: _configId,
      );
    }
    Navigator.of(context).maybePop();
  }

  void _onDelete() {
    final subjectId = widget.subjectId;
    if (subjectId == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete subject?'),
        content: const Text(
          'This removes the subject with all its recorded assessments, scores '
          'and computed grades. Archive the class instead if you only want to '
          'stop teaching it.',
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: ButtonVariant.ghost,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: 'Delete',
            variant: ButtonVariant.danger,
            onTap: () {
              context.read<AppState>().deleteSubject(subjectId);
              Navigator.of(dialogContext).pop();
              Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final existing =
        widget.subjectId == null ? null : state.subjects[widget.subjectId];
    final sectionId = existing?.sectionId ?? widget.sectionId ?? '';
    final section = state.sections[sectionId];
    final curriculum = section?.curriculum ?? Curriculum.existingShs;
    final configs = state.configsFor(curriculum);

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: existing == null ? 'New Subject' : 'Edit Subject',
            subtitle: section?.title,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                Field(
                  label: 'Subject Name',
                  icon: Ionicons.book,
                  placeholder: 'e.g. General Mathematics',
                  controller: _name,
                  keyboardType: TextInputType.name,
                  maxLength: 60,
                  onChanged: (_) => setState(() => _error = ''),
                ),
                const _Label('Terms Offered'),
                const SizedBox(height: 4),
                const Text(
                  'Subjects that run for part of the year keep their own records '
                  'per term; changing the term never deletes anything.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textFaint,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final span in _spans)
                      AppChip(
                        label: span.$1 == span.$2
                            ? termLabel(span.$1)
                            : (span.$1 == 1 && span.$2 == 3
                                ? 'Whole year'
                                : 'Terms ${span.$1}–${span.$2}'),
                        active: _termStart == span.$1 && _termEnd == span.$2,
                        onTap: () => setState(() {
                          _termStart = span.$1;
                          _termEnd = span.$2;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const _Label('Grading Configuration'),
                const SizedBox(height: 4),
                Text(
                  '${curriculum.label} weights. Pick a DepEd preset or set your '
                  'own WW / PT / TE percentages.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textFaint,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final config in configs)
                      Builder(builder: (context) {
                        final active = AssessmentCategory.values.every(
                          (category) =>
                              config.weights[category] == _weights[category],
                        );
                        return InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: () => _applyPreset(config),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: active ? AppColors.navy : AppColors.white,
                              border: Border.all(
                                color: active ? AppColors.navy : AppColors.border,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              config.name,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: AppFonts.semibold,
                                color: active ? AppColors.white : AppColors.text,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(
                  style: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      for (final (index, category)
                          in AssessmentCategory.values.indexed) ...[
                        if (index > 0)
                          const Divider(height: 1, color: AppColors.bg),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.label,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: AppFonts.semibold,
                                        color: AppColors.navyDark,
                                      ),
                                    ),
                                    Text(
                                      '${category.short} weight',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StepButton(
                                label: '−',
                                onTap: () => setState(() {
                                  _weights[category] =
                                      ((_weights[category] ?? 0) - 5)
                                          .clamp(0, 100)
                                          .toDouble();
                                  _configId = '';
                                }),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '${(_weights[category] ?? 0).round()}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14.5,
                                    fontWeight: AppFonts.bold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                              ),
                              _StepButton(
                                label: '+',
                                onTap: () => setState(() {
                                  _weights[category] =
                                      ((_weights[category] ?? 0) + 5)
                                          .clamp(0, 100)
                                          .toDouble();
                                  _configId = '';
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 1, color: AppColors.bg),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: AppFonts.bold,
                                color: AppColors.navyDark,
                              ),
                            ),
                            Text(
                              '${_total.round()}%',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14.5,
                                fontWeight: AppFonts.bold,
                                color: _total == 100
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DepEd Transmutation',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: AppFonts.semibold,
                                color: AppColors.navyDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Converts the initial grade with the DO 8, s. 2015 '
                              'table (60% mastery → 75).',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSoft,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _transmute,
                        activeThumbColor: AppColors.white,
                        activeTrackColor: AppColors.navy,
                        inactiveTrackColor: const Color(0xFFCBD8EE),
                        onChanged: (value) => setState(() => _transmute = value),
                      ),
                    ],
                  ),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: AppFonts.medium,
                        color: AppColors.red,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                AppButton(
                  label: existing == null ? 'Add Subject' : 'Save Changes',
                  icon: Ionicons.checkmark,
                  onTap: _onSave,
                ),
                if (existing != null) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Delete Subject',
                    variant: ButtonVariant.danger,
                    icon: Ionicons.trash,
                    onTap: _onDelete,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.5,
          fontWeight: AppFonts.semibold,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.ice,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: AppFonts.bold,
            color: AppColors.navy,
            height: 1,
          ),
        ),
      ),
    );
  }
}
