/// Learner profile (requirement 4.6): every piece of information associated
/// with the student — personal details, guardian, grades, attendance, BMI.
library;

import 'package:flutter/material.dart' hide Badge;
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/bmi.dart';
import '../services/grading.dart';
import '../services/reports.dart' as reports;
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/seat_board.dart';
import '../widgets/ui.dart';
import 'bmi.dart';
import 'student_form.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  int _term = _currentTerm();
  String? _reportBusy;

  static int _currentTerm() {
    final month = DateTime.now().month;
    if (month <= 9) return 1;
    if (month <= 11) return 2;
    return 3;
  }

  String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  /// Builds this learner's report card and sends it to the print dialog or
  /// the platform share sheet, like the class reports.
  Future<void> _reportCard(BuildContext context, {required bool print}) async {
    if (_reportBusy != null) return;
    final state = context.read<AppState>();
    final student = state.students[widget.studentId];
    final section = student == null ? null : state.sections[student.sectionId];
    if (student == null || section == null) return;
    setState(() => _reportBusy =
        print ? 'Opening the print dialog…' : 'Preparing the report card…');
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final bytes = await reports.buildReportCardPdfBytes(
        state.backupData(),
        section,
        student,
        comment: state.reportCommentFor(student.id),
      );
      final name = 'report-card-${_slug(student.fullName)}.pdf';
      if (print) {
        await reports.printPdfBytes(bytes, name: name);
      } else {
        await reports.sharePdfBytes(bytes, name: name);
      }
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not generate the report card: $error')),
      );
    } finally {
      if (mounted) setState(() => _reportBusy = null);
    }
  }

  /// Teacher's remark printed at the bottom of the report card.
  Future<void> _editRemark(BuildContext context, Student student) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(
      text: state.reportCommentFor(student.id),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          "Teacher's remark",
          style: TextStyle(
            fontSize: 17,
            fontWeight: AppFonts.bold,
            color: AppColors.navyDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Printed on this learner’s report card, under the grades. '
              'Leave it empty to remove the remark.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Shows steady improvement in written work.',
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
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: 'Save remark',
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (saved == true) state.setReportComment(student.id, controller.text);
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final student = state.students[widget.studentId];

    if (student == null) {
      return Screen(
        child: Column(
          children: [
            PageHeader(
              title: 'Learner Profile',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const EmptyState(
              icon: Ionicons.personOutline,
              title: 'Student not found',
              subtitle: 'This student record no longer exists.',
            ),
          ],
        ),
      );
    }

    final section = state.sections[student.sectionId];
    final sectionId = section?.id;
    final subjectList = state.subjects.values
        .where((s) => sectionId != null && s.sectionId == sectionId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Attendance summary for this student in this class.
    final counts = <AttendanceStatus, int>{
      for (final status in AttendanceStatus.values) status: 0,
    };
    for (final day in state.attendance.values) {
      if (sectionId != null && day.sectionId != sectionId) continue;
      final status = day.statuses[student.id];
      if (status != null) counts[status] = counts[status]! + 1;
    }
    final marked = counts.values.fold<int>(0, (sum, c) => sum + c);
    final rate = marked == 0
        ? null
        : ((counts[AttendanceStatus.present]! + counts[AttendanceStatus.late]!) /
            marked) *
            100;

    final bmiRecords = state.bmiHistory(widget.studentId);
    final latestBmi = bmiRecords.isEmpty ? null : bmiRecords.first;
    final latestInterpretation = interpretBmi(
      latestBmi == null
          ? null
          : computeBmi(latestBmi.heightCm, latestBmi.weightKg),
      ageYears: student.ageAt(),
      sex: student.gender,
    );

    final age = ageFromBirthday(student.birthday);

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Learner Profile',
            subtitle: section == null
                ? null
                : '${section.gradeLevel} — ${section.section}',
            onBack: () => Navigator.of(context).maybePop(),
            right: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentFormScreen(studentId: student.id),
                ),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Ionicons.createOutline,
                    size: 20, color: AppColors.navy),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                AppCard(
                  style: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 22),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          initialsOf(student.fullName),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: AppFonts.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        student.fullName,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: AppFonts.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      Text(
                        'Seat ${student.seatNumber}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: AppFonts.medium,
                          color: AppColors.textSoft,
                        ),
                      ),
                      if (student.lrn.isNotEmpty)
                        Text(
                          'LRN: ${student.lrn}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: AppFonts.medium,
                            color: AppColors.blue,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.ice,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Ionicons.documentTextOutline,
                                size: 19, color: AppColors.navy),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Report Card',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: AppFonts.bold,
                                color: AppColors.navyDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _reportBusy ??
                            'Subjects with term and final grades, general '
                                'average, attendance and BMI on one sheet.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSoft,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Print PDF',
                              icon: Ionicons.printOutline,
                              variant: ButtonVariant.secondary,
                              loading: _reportBusy != null,
                              disabled: _reportBusy != null,
                              onTap: () => _reportCard(context, print: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'Share PDF',
                              icon: Ionicons.shareSocialOutline,
                              loading: _reportBusy != null,
                              disabled: _reportBusy != null,
                              onTap: () => _reportCard(context, print: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _RemarkRow(
                        comment: state.reportCommentFor(student.id),
                        onTap: () => _editRemark(context, student),
                      ),
                    ],
                  ),
                ),
                const _SectionTitle('Personal Information'),
                AppCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Ionicons.calendar,
                        label: 'Birthday',
                        value: student.birthday.isEmpty
                            ? 'Not set'
                            : formatLongDate(student.birthday),
                      ),
                      _InfoRow(
                        icon: Ionicons.hourglass,
                        label: 'Age',
                        value: age == null ? 'Not set' : '$age years old',
                      ),
                      _InfoRow(
                        icon: Ionicons.person,
                        label: 'Gender',
                        value: student.gender.isEmpty ? 'Not set' : student.gender,
                      ),
                      _InfoRow(
                        icon: Ionicons.key,
                        label: 'LRN',
                        value: student.lrn.isEmpty ? 'Not set' : student.lrn,
                      ),
                    ],
                  ),
                ),
                const _SectionTitle('Guardian / Parent'),
                AppCard(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Ionicons.home,
                        label: 'Name',
                        value: student.guardianName.isEmpty
                            ? 'Not set'
                            : student.guardianName,
                      ),
                      _InfoRow(
                        icon: Ionicons.call,
                        label: 'Contact Number',
                        value: student.guardianContact.isEmpty
                            ? 'Not set'
                            : student.guardianContact,
                        last: true,
                      ),
                    ],
                  ),
                ),
                const _SectionTitle('Attendance Summary'),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final status in AttendanceStatus.values)
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: attendanceMeta(status).bg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      status.code,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: AppFonts.bold,
                                        color: attendanceMeta(status).color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${counts[status]}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: AppFonts.bold,
                                      color: AppColors.navyDark,
                                    ),
                                  ),
                                  Text(
                                    status.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Ionicons.trendingUp,
                                size: 16, color: AppColors.green),
                            const SizedBox(width: 6),
                            Text(
                              rate == null
                                  ? 'No attendance recorded yet.'
                                  : 'Attendance rate: ${rate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: AppFonts.semibold,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _SectionTitle('Academic Performance'),
                Segmented<int>(
                  options: [
                    for (final term in terms)
                      SegmentedOption(term, termShortLabel(term)),
                  ],
                  value: _term,
                  onChange: (term) => setState(() => _term = term),
                ),
                const SizedBox(height: 10),
                if (subjectList.isEmpty)
                  const AppCard(
                    child: Text(
                      'No subjects have been added for this class yet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSoft,
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  for (final sub in subjectList)
                    Builder(builder: (context) {
                      final result = state.gradeOf(sub, _term, student.id);
                      final finalGrade = state.finalGradeOf(sub, student.id);
                      final remarks = gradeRemarks(finalGrade);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.name,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: AppFonts.semibold,
                                        color: AppColors.navyDark,
                                      ),
                                    ),
                                    Text(
                                      result.termGrade == null
                                          ? (sub.covers(_term)
                                              ? 'No scores recorded'
                                              : 'Not offered in ${termLabel(_term)}')
                                          : '${reportGrade(result.termGrade!)} · ${termLabel(_term)}'
                                              '${finalGrade == null ? '' : ' · Final ${reportGrade(finalGrade)}'}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (remarks.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Badge(
                                    label: remarks,
                                    color: AppColors.green,
                                    bg: const Color(0xFFDFF5E7),
                                  ),
                                ),
                              Text(
                                result.termGrade == null
                                    ? '—'
                                    : '${reportGrade(result.termGrade!)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: AppFonts.extrabold,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'BMI Record',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: AppFonts.bold,
                            color: AppColors.navyDark,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BmiScreen(
                              sectionId: student.sectionId,
                              studentId: student.id,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.ice,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Row(
                            children: [
                              Icon(Ionicons.add,
                                  size: 16, color: AppColors.navy),
                              SizedBox(width: 2),
                              Text(
                                'Record',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: AppFonts.semibold,
                                  color: AppColors.navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (latestBmi != null)
                  Builder(builder: (context) {
                    final value = computeBmi(
                        latestBmi.heightCm, latestBmi.weightKg);
                    return AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: latestInterpretation?.color ??
                                    AppColors.navy,
                                width: 3,
                              ),
                            ),
                            child: Text(
                              value == null ? '—' : value.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: AppFonts.extrabold,
                                color: latestInterpretation?.color ??
                                    AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${latestInterpretation?.category ?? '—'} · '
                                  '${formatShortDate(latestBmi.date)}',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: AppFonts.semibold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                                Text(
                                  '${fmtHeight(latestBmi.heightCm)} cm · '
                                  '${fmtWeight(latestBmi.weightKg)} kg',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSoft,
                                  ),
                                ),
                                if (latestInterpretation != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      latestInterpretation.advice,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSoft,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  const AppCard(
                    child: Text(
                      'No BMI recorded yet. Track height and weight from the '
                      'BMI screen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSoft,
                        height: 1.45,
                      ),
                    ),
                  ),
                if (bmiRecords.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${bmiRecords.length} recorded measurements in total.',
                      style: const TextStyle(
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
    );
  }
}

class _RemarkRow extends StatelessWidget {
  const _RemarkRow({required this.comment, required this.onTap});

  final String comment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Ionicons.chatbubbleEllipsesOutline,
                  size: 17, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.isEmpty ? "Add a teacher's remark" : comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle:
                        comment.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color:
                        comment.isEmpty ? AppColors.textSoft : AppColors.text,
                    height: 1.35,
                  ),
                ),
              ),
              const Icon(Ionicons.createOutline,
                  size: 16, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

String fmtHeight(double v) =>
    v == v.roundToDouble() ? v.round().toString() : '$v';

String fmtWeight(double v) =>
    v == v.roundToDouble() ? v.round().toString() : '$v';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: AppFonts.bold,
          color: AppColors.navyDark,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.bg),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ice,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.navy),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: AppFonts.medium,
                color: AppColors.textSoft,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: AppFonts.semibold,
                color: AppColors.navyDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
