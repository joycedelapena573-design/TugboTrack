/// Class detail: quick links to attendance, grades and reports for this class,
/// plus the roster (search, add one-by-one, import CSV).
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/importer.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/seat_board.dart';
import '../widgets/ui.dart';
import 'attendance.dart';
import 'bmi.dart';
import 'grades.dart';
import 'reports.dart';
import 'section_form.dart';
import 'student_profile.dart';

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.sectionId});

  final String sectionId;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  String _query = '';
  bool _addingStudent = false;
  bool _attendanceOpen = true;
  final _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final section = state.sections[widget.sectionId];

    if (section == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              const PageHeader(title: 'Class not found'),
              const EmptyState(
                icon: Ionicons.alertCircleOutline,
                title: 'Missing class',
                subtitle: 'This class no longer exists.',
              ),
            ],
          ),
        ),
      );
    }

    final roster = state.studentsOf(widget.sectionId);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? roster
        : roster
            .where((s) =>
                s.fullName.toLowerCase().contains(q) ||
                s.lrn.toLowerCase().contains(q))
            .toList();
    final nextSeat = roster.isEmpty
        ? 1
        : roster.map((s) => s.seatNumber).reduce((a, b) => a > b ? a : b) + 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: '${section.gradeLevel} — ${section.section}',
              subtitle:
                  'SY ${section.schoolYear} · ${roster.length} students',
              onBack: () => Navigator.of(context).pop(),
              right: Material(
                color: AppColors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.border, width: 1.5),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SectionFormScreen(editingId: widget.sectionId),
                    ),
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Ionicons.createOutline,
                      size: 20,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Ionicons.calendar,
                          label: 'Attendance',
                          active: _attendanceOpen,
                          onTap: () {
                            state.setActiveSection(widget.sectionId);
                            setState(() => _attendanceOpen = !_attendanceOpen);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Ionicons.statsChart,
                          label: 'Grades',
                          onTap: () {
                            state.setActiveSection(widget.sectionId);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GradesScreen(
                                  sectionId: widget.sectionId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Ionicons.documentText,
                          label: 'Reports',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReportsScreen(sectionId: widget.sectionId),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  /// Seat-tap attendance lives right here on the class screen.
                  if (_attendanceOpen)
                    SeatBoard(
                      sectionId: widget.sectionId,
                      onOpenFull: () {
                        state.setActiveSection(widget.sectionId);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AttendanceScreen(sectionId: widget.sectionId),
                          ),
                        );
                      },
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Students',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16.5,
                          fontWeight: AppFonts.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _SearchBox(
                    value: _query,
                    hint: 'Search name or LRN',
                    onChanged: (text) => setState(() => _query = text),
                  ),
                  const SizedBox(height: 10),
                  if (_addingStudent)
                    _AddStudentFrame(
                      controller: _newName,
                      onCancel: () {
                        _newName.clear();
                        setState(() => _addingStudent = false);
                      },
                      onDone: () {
                        final name = _newName.text.trim();
                        if (name.isEmpty) return;
                        state.addStudent(Student(
                          id: '',
                          sectionId: widget.sectionId,
                          seatNumber: nextSeat,
                          fullName: name,
                          lrn: '',
                          gender: '',
                          birthday: '',
                          guardianName: '',
                          guardianContact: '',
                          createdAt: 0,
                        ));
                        _newName.clear();
                        setState(() => _addingStudent = false);
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _ImportButton(
                            label: 'Add Student',
                            icon: Ionicons.personAdd,
                            light: false,
                            onTap: () =>
                                setState(() => _addingStudent = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ImportButton(
                            label: 'Import CSV',
                            icon: Ionicons.documentAttach,
                            light: true,
                            onTap: () => _import(state),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    EmptyState(
                      icon: Ionicons.peopleOutline,
                      title: roster.isEmpty ? 'No students yet' : 'No matches',
                      subtitle: roster.isEmpty
                          ? 'Add students one by one, or import a CSV list from your file manager.'
                          : 'Try a different name or LRN.',
                      actionLabel: roster.isEmpty ? 'Add a student' : null,
                      onAction: roster.isEmpty
                          ? () => setState(() => _addingStudent = true)
                          : null,
                    )
                  else
                    for (final student in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          style: const EdgeInsets.all(12),
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    StudentProfileScreen(studentId: student.id),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '${student.seatNumber}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: AppFonts.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14.5,
                                          fontWeight: AppFonts.semibold,
                                          color: AppColors.navyDark,
                                        ),
                                      ),
                                      Text(
                                        student.lrn.isEmpty
                                            ? 'No LRN yet'
                                            : 'LRN ${student.lrn}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.textSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _BmiButton(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BmiScreen(
                                        sectionId: widget.sectionId,
                                        studentId: student.id,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.ice,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    initialsOf(student.fullName),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: AppFonts.bold,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Every change is saved on this device and backed up to CSV automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import(AppState state) async {
    final outcome = await pickStudentCsv();
    if (outcome.status == ImportStatus.canceled) return;
    if (!mounted) return;
    if (outcome.status == ImportStatus.failed) {
      _alert(
        'Import failed',
        (outcome.errors ?? ['Unknown error.']).join('\n'),
      );
      return;
    }
    final roster = state.studentsOf(widget.sectionId);
    var seat = roster.isEmpty
        ? 1
        : roster.map((s) => s.seatNumber).reduce((a, b) => a > b ? a : b) + 1;
    final rows = outcome.rows ?? [];
    final inputs = <Student>[];
    for (final row in rows) {
      final input = toStudentInput(row, widget.sectionId, seat);
      seat = input.seatNumber + 1;
      inputs.add(input);
    }
    final added = state.bulkAddStudents(inputs);
    final notes = (outcome.errors ?? []).isEmpty
        ? ''
        : '\n\nNotes:\n${(outcome.errors!).take(5).join('\n')}';
    _alert(
      'Students imported',
      '$added ${added == 1 ? 'student' : 'students'} added from '
      '${outcome.fileName ?? 'the file'}.$notes',
    );
  }

  void _alert(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.ice : AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: active ? AppColors.navy : AppColors.border,
              width: active ? 2 : 1,
            ),
            boxShadow: AppShadow.soft,
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.ice,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: AppFonts.semibold,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.light,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? AppColors.navy : AppColors.white;
    return Material(
      color: light ? AppColors.ice : AppColors.navy,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: AppFonts.semibold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiButton extends StatelessWidget {
  const _BmiButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ice,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Ionicons.body, size: 13, color: AppColors.navy),
              SizedBox(width: 3),
              Text(
                'BMI',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: AppFonts.semibold,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Ionicons.search, size: 18, color: AppColors.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              autocorrect: false,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.5,
                fontWeight: AppFonts.medium,
                color: AppColors.text,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.5,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          if (value.isNotEmpty)
            GestureDetector(
              onTap: () => onChanged(''),
              child: Icon(
                Ionicons.closeCircle,
                size: 18,
                color: AppColors.textFaint,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddStudentFrame extends StatelessWidget {
  const _AddStudentFrame({
    required this.controller,
    required this.onCancel,
    required this.onDone,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.blue, width: 1.5),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Type the student’s full name',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: AppFonts.semibold,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => onDone(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: AppFonts.medium,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              hintText: 'Last name, First name, M.I.',
              hintStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: AppColors.textFaint,
              ),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: AppColors.ice,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: onCancel,
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: AppFonts.semibold,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: onDone,
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Ionicons.checkmark, size: 16, color: AppColors.white),
                          const SizedBox(width: 4),
                          const Text(
                            'Done',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: AppFonts.semibold,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
