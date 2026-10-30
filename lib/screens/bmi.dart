/// BMI monitoring (requirement 5): record height/weight, auto-compute BMI,
/// show the interpretation, and keep values private until revealed.
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/bmi.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key, this.sectionId, this.studentId});

  final String? sectionId;
  final String? studentId;

  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  String _sectionId = '';
  String? _studentId;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sectionId.isNotEmpty) return;
    final state = context.read<AppState>();
    final sorted = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _sectionId = widget.sectionId ??
        state.activeSectionId ??
        (sorted.isEmpty ? null : sorted.first.id) ??
        '';
    _studentId = widget.studentId;
  }

  List<Student> _roster(AppState state) =>
      state.students.values.where((s) => s.sectionId == _sectionId).toList()
        ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sections = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final section =
        state.sections[_sectionId] ?? (sections.isEmpty ? null : sections.first);
    final roster = _roster(state);
    final student = state.students[_studentId] ??
        (roster.isEmpty ? null : roster.first);
    final records = student == null
        ? <BmiRecord>[]
        : state.bmiHistory(student.id);
    final latest = records.isEmpty ? null : records.first;
    final latestBmi = latest == null
        ? null
        : computeBmi(latest.heightCm, latest.weightKg);
    final interpretation = interpretBmi(latestBmi);

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'BMI Monitoring',
            subtitle: 'Height, weight and interpretation',
            onBack: () => Navigator.of(context).maybePop(),
            right: InkWell(
              onTap: () => setState(() => _revealed = !_revealed),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: _revealed ? AppColors.navy : AppColors.white,
                  border: Border.all(
                    color: _revealed ? AppColors.navy : AppColors.border,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _revealed ? Ionicons.eye : Ionicons.eyeOff,
                      size: 18,
                      color: _revealed ? AppColors.white : AppColors.navy,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _revealed ? 'Shown' : 'Hidden',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFonts.semibold,
                        color:
                            _revealed ? AppColors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (sections.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final sec in sections)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label:
                                    '${sec.gradeLevel.replaceFirst('Grade ', 'G')} — ${sec.section}',
                                active: sec.id == section?.id,
                                onTap: () => setState(() {
                                  _sectionId = sec.id;
                                  _studentId = null;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (roster.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: AppCard(
                      child: Text(
                        'Add students to this class before recording BMI.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSoft,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final st in roster)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label:
                                    '${st.seatNumber}. ${st.fullName.split(' ').last}',
                                active: st.id == student?.id,
                                onTap: () => setState(() => _studentId = st.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (student != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.fullName,
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: AppFonts.bold,
                                          color: AppColors.navyDark,
                                        ),
                                      ),
                                      Text(
                                        'Seat ${student.seatNumber}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _RecordButton(
                                  onPressed: () => _openEntry(student),
                                ),
                              ],
                            ),
                            if (!_revealed)
                              Container(
                                margin: const EdgeInsets.only(top: 14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Ionicons.lockClosed,
                                        size: 18, color: AppColors.textSoft),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'BMI values are hidden for privacy. '
                                        'Tap the eye button above to reveal.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSoft,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (latest != null &&
                                latestBmi != null &&
                                interpretation != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 92,
                                      height: 92,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.bg,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: interpretation.color,
                                          width: 4,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            latestBmi.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: AppFonts.extrabold,
                                              color: interpretation.color,
                                            ),
                                          ),
                                          const Text(
                                            'BMI',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: AppFonts.semibold,
                                              color: AppColors.textSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: interpretation.bg,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.pill),
                                            ),
                                            child: Text(
                                              interpretation.category,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: AppFonts.bold,
                                                color: interpretation.color,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${latest.heightCm} cm · '
                                            '${latest.weightKg} kg',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textSoft,
                                            ),
                                          ),
                                          Text(
                                            formatShortDate(latest.date),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.textSoft,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: Text(
                                  'No BMI recorded for this student yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSoft,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                bmiForAgeNote(),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textFaint,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 18, 4, 10),
                      child: Text(
                        'History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFonts.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                    ),
                    if (records.isEmpty)
                      const AppCard(
                        child: Text(
                          'No measurements recorded yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSoft,
                          ),
                        ),
                      )
                    else
                      for (final record in records)
                        _HistoryRow(
                          record: record,
                          revealed: _revealed,
                          onDelete: () => state.deleteBmi(record.id),
                        ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntry(Student student) async {
    final height = TextEditingController();
    final weight = TextEditingController();
    final date = TextEditingController(text: todayIso());
    var error = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final h = double.tryParse(height.text.trim()) ?? 0;
          final w = double.tryParse(weight.text.trim()) ?? 0;
          final preview = h > 0 && w > 0 ? computeBmi(h, w) : null;
          final previewInterp = interpretBmi(preview);

          return AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: const Text(
              'Record BMI',
              style: TextStyle(
                fontSize: 17,
                fontWeight: AppFonts.bold,
                color: AppColors.navyDark,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      student.fullName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: height,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Height (cm)',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(AppRadius.md)),
                      ),
                    ),
                    onChanged: (_) =>
                        setDialogState(() => error = ''),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: weight,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Weight (kg)',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(AppRadius.md)),
                      ),
                    ),
                    onChanged: (_) =>
                        setDialogState(() => error = ''),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      hintText: 'Date (YYYY-MM-DD)',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(AppRadius.md)),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (preview != null && previewInterp != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Computed BMI',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: AppFonts.medium,
                              color: AppColors.textSoft,
                            ),
                          ),
                          Text(
                            preview.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: AppFonts.extrabold,
                              color: previewInterp.color,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: previewInterp.bg,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              previewInterp.category,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFonts.bold,
                                color: previewInterp.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: AppFonts.medium,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              AppButton(
                label: 'Cancel',
                variant: ButtonVariant.ghost,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
              AppButton(
                label: 'Save',
                onTap: () {
                  final h = double.tryParse(height.text.trim()) ?? 0;
                  final w = double.tryParse(weight.text.trim()) ?? 0;
                  if (h <= 0 || w <= 0) {
                    setDialogState(
                        () => error = 'Enter a valid height (cm) and weight (kg).');
                    return;
                  }
                  context.read<AppState>().setBmi(
                        student.id,
                        date.text.trim().isEmpty
                            ? todayIso()
                            : date.text.trim(),
                        h,
                        w,
                      );
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Ionicons.add, size: 16, color: AppColors.white),
            SizedBox(width: 4),
            Text(
              'Record',
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFonts.semibold,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.revealed,
    required this.onDelete,
  });

  final BmiRecord record;
  final bool revealed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bmi = computeBmi(record.heightCm, record.weightKg);
    final interp = interpretBmi(bmi);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatShortDate(record.date),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    revealed
                        ? '${record.heightCm} cm · ${record.weightKg} kg'
                        : '•••• cm · •••• kg',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (revealed && bmi != null && interp != null) ...[
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: AppFonts.extrabold,
                  color: interp.color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: interp.bg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  interp.category,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: AppFonts.semibold,
                    color: interp.color,
                  ),
                ),
              ),
            ] else
              const Icon(Ionicons.eyeOff,
                  size: 16, color: AppColors.textFaint),
            const SizedBox(width: 8),
            InkWell(
              onTap: onDelete,
              child: const Icon(Ionicons.trashOutline,
                  size: 17, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
