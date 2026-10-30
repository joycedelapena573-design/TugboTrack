/// Add or edit a subject: name, teacher, grading weights, transmutation.
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
  Weights _weights = Map<ComponentKey, double>.from(defaultWeights);
  bool _transmute = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    final existing = _existing();
    if (existing != null) {
      _name.text = existing.name;
      _weights = Map<ComponentKey, double>.from(existing.weights);
      _transmute = existing.transmute;
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

  int get _total => ComponentKey.values.fold<int>(
      0, (sum, key) => sum + (_weights[key] ?? 0).round());

  void _onSave() {
    final state = context.read<AppState>();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the subject name.');
      return;
    }
    if (_total != 100) {
      setState(
        () => _error = 'Weights must add up to 100%. Current total: $_total%.',
      );
      return;
    }
    final subjectId = widget.subjectId;
    if (subjectId != null) {
      state.updateSubject(
        subjectId,
        name: _name.text.trim(),
        weights: _weights,
        transmute: _transmute,
      );
    } else {
      state.addSubject(
        sectionId: widget.sectionId ?? '',
        name: _name.text.trim(),
        teacherName: state.teacherName,
        weights: _weights,
        transmute: _transmute,
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
          'This removes the subject with all its recorded scores '
          'and computed grades.',
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
    final existing = widget.subjectId == null
        ? null
        : state.subjects[widget.subjectId];
    final sectionId = existing?.sectionId ?? widget.sectionId ?? '';
    final section = state.sections[sectionId];

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: existing == null ? 'New Subject' : 'Edit Subject',
            subtitle: section == null
                ? null
                : '${section.gradeLevel} — ${section.section}',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                Field(
                  label: 'Subject Name',
                  icon: Ionicons.book,
                  placeholder: 'e.g. Mathematics',
                  controller: _name,
                  keyboardType: TextInputType.name,
                  onChanged: (_) => setState(() => _error = ''),
                ),
                const SizedBox(height: 14),
                const _Label('Grading Weights'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in weightPresets)
                      Builder(builder: (context) {
                        final active = ComponentKey.values
                            .every((c) => preset.weights[c] == _weights[c]);
                        return InkWell(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          onTap: () => setState(
                            () =>
                                _weights = Map<ComponentKey, double>.from(preset.weights),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color:
                                  active ? AppColors.navy : AppColors.white,
                              border: Border.all(
                                color: active
                                    ? AppColors.navy
                                    : AppColors.border,
                                width: 1.5,
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              preset.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFonts.semibold,
                                color: active
                                    ? AppColors.white
                                    : AppColors.text,
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
                      for (final (index, key)
                          in ComponentKey.values.indexed) ...[
                        if (index > 0) const Divider(height: 1, color: AppColors.bg),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  key.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: AppFonts.semibold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                              ),
                              _StepButton(
                                label: '−',
                                onTap: () => setState(
                                  () => _weights[key] =
                                      ((_weights[key] ?? 0) - 5)
                                          .clamp(0, 100)
                                          .toDouble(),
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '${(_weights[key] ?? 0).round()}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: AppFonts.bold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                              ),
                              _StepButton(
                                label: '+',
                                onTap: () => setState(
                                  () => _weights[key] =
                                      ((_weights[key] ?? 0) + 5)
                                          .clamp(0, 100)
                                          .toDouble(),
                                ),
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
                                fontSize: 14,
                                fontWeight: AppFonts.bold,
                                color: AppColors.navyDark,
                              ),
                            ),
                            Text(
                              '$_total%',
                              style: TextStyle(
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
                                fontSize: 14,
                                fontWeight: AppFonts.semibold,
                                color: AppColors.navyDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Convert raw grades using the DO 8, s. 2015 '
                              'transmutation table (60% mastery → 75).',
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
                        onChanged: (v) => setState(() => _transmute = v),
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
