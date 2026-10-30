/// Add or edit a class. Senior-high app: only Grade 11 and Grade 12 are
/// offered, the school year opens as a dropdown that defaults to the present
/// year, and subjects are entered together with the class.
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'main_shell.dart';

/// This app is intended for senior high students only.
const List<String> gradeOptions = ['Grade 11', 'Grade 12'];

/// School years the teacher can choose from, up to 2050-2051.
final List<String> yearOptions = [
  for (var y = 2020; y <= 2050; y++) '$y-${y + 1}',
];

/// Common senior-high subjects the teacher can pick instead of typing.
const List<String> subjectSuggestions = [
  'Oral Communication',
  'Komunikasyon at Pananaliksik',
  'General Mathematics',
  'Earth and Life Science',
  'Personal Development',
  'Physical Education and Health',
  'Understanding Culture, Society and Politics',
  '21st Century Literature from the Philippines and the World',
  'Empowerment Technologies',
  'Media and Information Literacy',
  'Practical Research 1 (Qualitative)',
  'Practical Research 2 (Quantitative)',
  'Statistics and Probability',
  'General Chemistry 1',
  'General Chemistry 2',
  'General Biology 1',
  'General Biology 2',
  'General Physics 1',
  'General Physics 2',
  'Pre-Calculus',
  'Basic Calculus',
  'Applied Economics',
  'Business Math',
  'Organization and Management',
  'Enterprise Development',
  'Contemporary Philippine Arts from the Regions',
  'Creative Writing',
  'English for Academic and Professional Purposes',
  'Filipino sa Piling Larangan',
  'Research Project',
  'Developmental Psychology',
  'Community Engagement, Solidarity and Citizenship',
  'Philippine Politics and Governance',
  'The Global Economy',
  'Bread and Pastry Production',
  'Computer Systems Servicing',
  'Caregiving',
  'Food and Beverage Services',
];

class SectionFormScreen extends StatefulWidget {
  const SectionFormScreen({super.key, this.editingId});

  final String? editingId;

  @override
  State<SectionFormScreen> createState() => _SectionFormScreenState();
}

class _SectionFormScreenState extends State<SectionFormScreen> {
  late String _gradeLevel;
  late final TextEditingController _section;
  late String _schoolYear;
  bool _yearOpen = false;
  final _subjectDraft = TextEditingController();
  bool _subjectSheet = false;
  String _subjectQuery = '';
  final List<String> _pendingSubjects = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final existing =
        widget.editingId == null ? null : state.sections[widget.editingId];
    _gradeLevel = existing?.gradeLevel ?? 'Grade 12';
    _section = TextEditingController(text: existing?.section ?? '');
    _schoolYear = existing?.schoolYear ?? currentSchoolYear();
  }

  @override
  void dispose() {
    _section.dispose();
    _subjectDraft.dispose();
    super.dispose();
  }

  Section? get _existing {
    final id = widget.editingId;
    if (id == null) return null;
    return context.read<AppState>().sections[id];
  }

  /// Every school year from 2020-2021 up to 2050-2051, plus an older one being edited.
  List<String> get _years {
    final list = [...yearOptions];
    final existing = _existing;
    if (existing != null && !list.contains(existing.schoolYear)) {
      list.insert(0, existing.schoolYear);
    }
    if (!list.contains(_schoolYear)) list.insert(0, _schoolYear);
    return list;
  }

  List<String> get _gradeChoices {
    final existing = _existing;
    if (existing != null && !gradeOptions.contains(existing.gradeLevel)) {
      return [existing.gradeLevel, ...gradeOptions];
    }
    return gradeOptions;
  }

  List<Subject> get _existingSubjects {
    final id = widget.editingId;
    if (id == null) return const [];
    return context.read<AppState>().subjectsOf(id);
  }

  void _addSubjectDraft() {
    final name = _subjectDraft.text.trim();
    if (name.isEmpty) return;
    final lower = name.toLowerCase();
    final exists = _pendingSubjects.any((s) => s.toLowerCase() == lower) ||
        _existingSubjects.any((s) => s.name.toLowerCase() == lower);
    if (!exists) setState(() => _pendingSubjects.add(name));
    _subjectDraft.clear();
  }

  bool _isChosen(String name) {
    final lower = name.toLowerCase();
    return _pendingSubjects.any((s) => s.toLowerCase() == lower) ||
        _existingSubjects.any((s) => s.name.toLowerCase() == lower);
  }

  void _toggleSuggestion(String name) {
    final lower = name.toLowerCase();
    setState(() {
      final index =
          _pendingSubjects.indexWhere((s) => s.toLowerCase() == lower);
      if (index >= 0) {
        _pendingSubjects.removeAt(index);
      } else {
        _pendingSubjects.add(name);
      }
    });
  }

  void _save() {
    final state = context.read<AppState>();
    final name = _section.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a section name (e.g. Sampaguita).');
      return;
    }
    String? id = widget.editingId;
    if (id != null) {
      state.updateSection(
        id,
        gradeLevel: _gradeLevel,
        section: name,
        schoolYear: _schoolYear,
      );
    } else {
      id = state
          .addSection(
            gradeLevel: _gradeLevel,
            section: name,
            schoolYear: _schoolYear,
          )
          .id;
    }
    for (final subject in _pendingSubjects) {
      state.addSubject(
        sectionId: id,
        name: subject,
        teacherName: state.teacherName,
      );
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    final id = widget.editingId;
    if (id == null) return;
    context.read<AppState>().deleteSection(id);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final present = currentSchoolYear();
    final editing = widget.editingId != null;
    final suggestions = _subjectQuery.trim().isEmpty
        ? subjectSuggestions
        : subjectSuggestions
            .where((s) =>
                s.toLowerCase().contains(_subjectQuery.trim().toLowerCase()))
            .toList();
    final existingSubjects = _existingSubjects;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: editing ? 'Edit Class' : 'New Class',
              subtitle: 'Grade level, section, school year and subjects',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const _Label('Grade Level'),
                  Row(
                    children: [
                      for (final grade in _gradeChoices) ...[
                        Expanded(
                          child: Builder(builder: (context) {
                            final active = _gradeLevel == grade;
                            return Material(
                              color: active ? AppColors.navy : AppColors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                onTap: () =>
                                    setState(() => _gradeLevel = grade),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color:
                                          active ? AppColors.navy : AppColors.border,
                                      width: 1.5,
                                    ),
                                    boxShadow:
                                        active ? AppShadow.soft : null,
                                  ),
                                  child: Text(
                                    grade,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: AppFonts.bold,
                                      color: active
                                          ? AppColors.white
                                          : AppColors.text,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        if (grade != _gradeChoices.last) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Field(
                    label: 'Section Name',
                    icon: Ionicons.people,
                    placeholder: 'e.g. Sampaguita',
                    controller: _section,
                    keyboardType: TextInputType.name,
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const _Label('School Year'),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => setState(() => _yearOpen = !_yearOpen),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border, width: 1.5),
                        boxShadow: AppShadow.soft,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.ice,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Ionicons.calendarOutline,
                              size: 18,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _schoolYear,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: AppFonts.bold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                                Text(
                                  _schoolYear == present
                                      ? 'Present school year'
                                      : 'Selected school year',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: AppColors.textSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _yearOpen
                                ? Ionicons.chevronUp
                                : Ionicons.chevronDown,
                            size: 20,
                            color: AppColors.navy,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_yearOpen) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 282),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border, width: 1.5),
                        boxShadow: AppShadow.card,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        shrinkWrap: true,
                        children: [
                          for (final year in _years)
                            Builder(builder: (context) {
                              final active = _schoolYear == year;
                              return InkWell(
                                onTap: () => setState(() {
                                  _schoolYear = year;
                                  _yearOpen = false;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  color: active ? AppColors.navy : null,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        year,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14.5,
                                          fontWeight: AppFonts.semibold,
                                          color: active
                                              ? AppColors.white
                                              : AppColors.text,
                                        ),
                                      ),
                                      if (active)
                                        const Icon(
                                          Ionicons.checkmarkCircle,
                                          size: 18,
                                          color: AppColors.white,
                                        )
                                      else if (year == present)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.ice,
                                            borderRadius:
                                                BorderRadius.circular(
                                              AppRadius.pill,
                                            ),
                                          ),
                                          child: const Text(
                                            'Present',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10.5,
                                              fontWeight: AppFonts.semibold,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const _Label('Subjects'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subjectDraft,
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _addSubjectDraft(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.5,
                            fontWeight: AppFonts.medium,
                            color: AppColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. General Mathematics',
                            hintStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.5,
                              color: AppColors.textFaint,
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                color: AppColors.blue,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => setState(() {
                            _subjectQuery = '';
                            _subjectSheet = true;
                          }),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadow.soft,
                            ),
                            child: Icon(
                              Ionicons.add,
                              size: 22,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      'Tap + to pick a subject from the list, or type your own and press return. '
                      'You can add more later from the grade book.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textFaint,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (existingSubjects.isNotEmpty || _pendingSubjects.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final subject in existingSubjects)
                            _SubjectChip(label: subject.name),
                          for (final name in _pendingSubjects)
                            _SubjectChip(
                              label: name,
                              selected: true,
                              onTap: () => setState(
                                () => _pendingSubjects.remove(name),
                              ),
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
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: AppFonts.medium,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: editing ? 'Save Changes' : 'Create Class',
                    icon: Ionicons.checkmark,
                    onTap: _save,
                  ),
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: AppButton(
                        label: 'Delete Class',
                        variant: ButtonVariant.danger,
                        icon: Ionicons.trash,
                        onTap: _delete,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _subjectSheet
          ? _SubjectSheet(
              query: _subjectQuery,
              suggestions: suggestions,
              isChosen: _isChosen,
              onQuery: (text) => setState(() => _subjectQuery = text),
              onToggle: _toggleSuggestion,
              addedCount: _pendingSubjects.length,
              onClose: () => setState(() => _subjectSheet = false),
            )
          : null,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
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

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Ionicons.book,
          size: 13,
          color: selected ? AppColors.white : AppColors.navy,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: AppFonts.semibold,
            color: selected ? AppColors.white : AppColors.navy,
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 6),
          const Icon(Ionicons.close, size: 14, color: AppColors.white),
        ],
      ],
    );

    return Material(
      color: selected ? AppColors.navy : AppColors.ice,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.border,
              width: 1.5,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _SubjectSheet extends StatelessWidget {
  const _SubjectSheet({
    required this.query,
    required this.suggestions,
    required this.isChosen,
    required this.onQuery,
    required this.onToggle,
    required this.addedCount,
    required this.onClose,
  });

  final String query;
  final List<String> suggestions;
  final bool Function(String) isChosen;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onToggle;
  final int addedCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.86,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose a subject',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: AppFonts.bold,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap to add — tap again to remove.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Ionicons.search, size: 17, color: AppColors.textFaint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    autocorrect: false,
                    onChanged: onQuery,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: AppFonts.medium,
                      color: AppColors.text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      hintText: 'Search subjects',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  GestureDetector(
                    onTap: () => onQuery(''),
                    child: Icon(
                      Ionicons.closeCircle,
                      size: 18,
                      color: AppColors.textFaint,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: suggestions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 18,
                    ),
                    child: Text(
                      'No subject matches “$query”. Go back and type it in the field instead.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textSoft,
                        height: 1.45,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final name = suggestions[index];
                      final chosen = isChosen(name);
                      return InkWell(
                        onTap: () => onToggle(name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          color: chosen ? AppColors.ice : null,
                          child: Row(
                            children: [
                              Icon(
                                chosen
                                    ? Ionicons.checkmarkCircle
                                    : Ionicons.addCircleOutline,
                                size: 20,
                                color: chosen
                                    ? AppColors.green
                                    : AppColors.textFaint,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: AppFonts.medium,
                                    color: chosen
                                        ? AppColors.navyDark
                                        : AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: addedCount > 0
                ? 'Done ($addedCount added)'
                : 'Done',
            icon: Ionicons.checkmark,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}
