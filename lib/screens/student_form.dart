/// Add / edit a student. The basic form is name + seat; a separate
/// "Add Student Information" button reveals birthday, age, LRN and
/// guardian details (requirement 4.7).
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, this.sectionId, this.studentId});

  final String? sectionId;
  final String? studentId;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _seat;
  late final TextEditingController _lrn;
  late final TextEditingController _birthday;
  late final TextEditingController _guardian;
  late final TextEditingController _contact;
  bool _showInfo = false;
  String _gender = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.studentId == null
        ? null
        : context.read<AppState>().students[widget.studentId];
    _name = TextEditingController(text: existing?.fullName ?? '');
    _seat = TextEditingController();
    _lrn = TextEditingController(text: existing?.lrn ?? '');
    _birthday = TextEditingController(text: existing?.birthday ?? '');
    _guardian = TextEditingController(text: existing?.guardianName ?? '');
    _contact = TextEditingController(text: existing?.guardianContact ?? '');
    _gender = existing?.gender ?? '';
    _showInfo = (existing?.lrn.isNotEmpty ?? false) ||
        (existing?.birthday.isNotEmpty ?? false) ||
        (existing?.guardianName.isNotEmpty ?? false);

    if (existing == null) {
      _seat.text = '${_nextSeat(widget.sectionId, null)}';
    } else {
      _seat.text = '${existing.seatNumber}';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _seat, _lrn, _birthday, _guardian, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  int _nextSeat(String? sectionId, String? excludeId) {
    final students = context.read<AppState>().students.values.where(
          (s) => s.sectionId == sectionId && s.id != excludeId,
        );
    final seats = students.map((s) => s.seatNumber);
    if (seats.isEmpty) return 1;
    return seats.reduce((a, b) => a > b ? a : b) + 1;
  }

  void _onSave() {
    final state = context.read<AppState>();
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the student’s full name.');
      return;
    }
    final sectionId =
        state.students[widget.studentId]?.sectionId ?? widget.sectionId ?? '';
    final nextSeat = _nextSeat(sectionId, widget.studentId);
    final seatText = _seat.text.trim();
    final seatNum =
        RegExp(r'^\d+$').hasMatch(seatText) ? int.parse(seatText) : nextSeat;
    final normalizedBirthday = normalizeBirthday(_birthday.text) ?? '';

    final studentId = widget.studentId;
    if (studentId != null) {
      state.updateStudent(
        studentId,
        seatNumber: seatNum,
        fullName: _name.text.trim(),
        lrn: _lrn.text.trim(),
        gender: _gender,
        birthday: normalizedBirthday,
        guardianName: _guardian.text.trim(),
        guardianContact: _contact.text.trim(),
      );
    } else {
      state.addStudent(Student(
        id: '',
        sectionId: sectionId,
        seatNumber: seatNum,
        fullName: _name.text.trim(),
        lrn: _lrn.text.trim(),
        gender: _gender,
        birthday: normalizedBirthday,
        guardianName: _guardian.text.trim(),
        guardianContact: _contact.text.trim(),
        createdAt: 0,
      ));
    }
    Navigator.of(context).maybePop();
  }

  void _onDelete() {
    final studentId = widget.studentId;
    if (studentId == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete student?'),
        content: const Text(
          'This removes the student together with their grades, attendance '
          'and BMI records.',
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
              context.read<AppState>().deleteStudent(studentId);
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final existing = widget.studentId == null
        ? null
        : state.students[widget.studentId];
    final sectionId = existing?.sectionId ?? widget.sectionId ?? '';
    final section = state.sections[sectionId];
    final nextSeat = _nextSeat(sectionId, widget.studentId);

    final normalized = normalizeBirthday(_birthday.text);
    final age = normalized == null ? null : ageFromBirthday(normalized);
    String birthdayHint;
    if (_birthday.text.isEmpty) {
      birthdayHint = 'Used to compute age automatically.';
    } else if (normalized == null) {
      birthdayHint = 'Use the format YYYY-MM-DD or MM/DD/YYYY.';
    } else {
      birthdayHint = formatLongDate(normalized) +
          (age == null ? '' : ' · $age years old');
    }

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: existing == null ? 'New Student' : 'Edit Student',
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
                  label: 'Full Name',
                  icon: Ionicons.person,
                  placeholder: 'Last name, First name, M.I.',
                  controller: _name,
                  keyboardType: TextInputType.name,
                  onChanged: (_) => setState(() => _error = ''),
                ),
                Field(
                  label: 'Seat Number',
                  icon: Ionicons.grid,
                  placeholder: 'Seat number in class',
                  controller: _seat,
                  keyboardType: TextInputType.number,
                  hint: 'Next available seat: $nextSeat',
                ),
                if (!_showInfo)
                  InkWell(
                    onTap: () => setState(() => _showInfo = true),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.ice,
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Ionicons.informationCircle,
                                size: 20, color: AppColors.navy),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Student Information',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: AppFonts.semibold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                                Text(
                                  'Birthday, age, LRN and guardian details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Ionicons.addCircle,
                              size: 24, color: AppColors.navy),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Student Information',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: AppFonts.bold,
                                  color: AppColors.navyDark,
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => _showInfo = false),
                                child: const Icon(Ionicons.chevronUp,
                                    size: 20, color: AppColors.textFaint),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Gender',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: AppFonts.semibold,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          Segmented<String>(
                            options: const [
                              SegmentedOption('Female', 'Female'),
                              SegmentedOption('Male', 'Male'),
                            ],
                            value: _gender == 'Male' ? 'Male' : 'Female',
                            onChange: (v) => setState(() => _gender = v),
                          ),
                          const SizedBox(height: 12),
                          Field(
                            label: 'Birthday',
                            icon: Ionicons.calendar,
                            placeholder: 'YYYY-MM-DD',
                            controller: _birthday,
                            keyboardType: TextInputType.datetime,
                            hint: birthdayHint,
                            onChanged: (_) => setState(() {}),
                          ),
                          Field(
                            label: 'Learners Reference Number (LRN)',
                            icon: Ionicons.key,
                            placeholder: 'e.g. 123456789012',
                            controller: _lrn,
                            keyboardType: TextInputType.number,
                            maxLength: 15,
                          ),
                          Field(
                            label: 'Guardian / Parent Name',
                            icon: Ionicons.home,
                            placeholder: 'e.g. Maria Dela Cruz',
                            controller: _guardian,
                            keyboardType: TextInputType.name,
                          ),
                          Field(
                            label: 'Guardian Contact Number',
                            icon: Ionicons.call,
                            placeholder: 'e.g. 09171234567',
                            controller: _contact,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                AppButton(
                  label: existing == null ? 'Add Student' : 'Save Changes',
                  icon: Ionicons.checkmark,
                  onTap: _onSave,
                ),
                if (existing != null) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Delete Student',
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
