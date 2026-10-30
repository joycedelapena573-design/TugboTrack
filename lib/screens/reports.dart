/// Reports & exports (requirements 4.1–4.4): search and review records,
/// generate class record reports, print/save as PDF, and export CSV backups.
library;

import 'package:flutter/material.dart' hide Badge;
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/backup.dart';
import '../services/grading.dart';
import '../services/reports.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.sectionId});

  final String? sectionId;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _sectionId;
  String? _subjectId;
  int _quarter = 1;
  String _busy = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sectionId != null) return;
    final state = context.read<AppState>();
    final sections = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _sectionId = widget.sectionId ??
        state.activeSectionId ??
        (sections.isEmpty ? null : sections.first.id);
  }

  Future<void> _withBusy(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sections = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final section =
        state.sections[_sectionId] ?? (sections.isEmpty ? null : sections.first);

    final subjectList = state.subjects.values
        .where((s) => section != null && s.sectionId == section.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final subject = subjectList.where((s) => s.id == _subjectId).firstOrNull ??
        (subjectList.isEmpty ? null : subjectList.first);

    final roster = section == null
        ? <Student>[]
        : (state.students.values
                .where((s) => s.sectionId == section.id)
                .toList()
              ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber)));

    _Summary? summary;
    if (subject != null) {
      final sheet = state.sheets[state.sheetIdOf(subject.id, _quarter)];
      final finals = <double>[];
      for (final student in roster) {
        if (sheet == null) break;
        final grade = computeQuarterGrade(
          subject.weights,
          subject.transmute,
          sheet,
          state.scores,
          student.id,
        ).finalGrade;
        if (grade != null) finals.add(grade);
      }
      if (finals.isNotEmpty) {
        summary = _Summary(
          avg: finals.reduce((a, b) => a + b) / finals.length,
          high: finals.reduce((a, b) => a > b ? a : b),
          low: finals.reduce((a, b) => a < b ? a : b),
          passed: finals.where((f) => f >= passingGrade).length,
          total: roster.length,
        );
      }
    }

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Reports & Exports',
            subtitle: 'Class records, print, PDF and CSV backups',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 30),
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
                                  _subjectId = null;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (section == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: AppCard(
                      child: Text(
                        'Create a class first to generate reports.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                  )
                else if (subjectList.isEmpty || subject == null)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: AppCard(
                      child: Text(
                        'Add a subject to generate a class record report.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSoft,
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
                          for (final sub in subjectList)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label: sub.name,
                                active: sub.id == subject.id,
                                onTap: () => setState(() => _subjectId = sub.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Segmented<int>(
                      options: [
                        for (final q in quarters) SegmentedOption(q, 'Q$q'),
                      ],
                      value: _quarter,
                      onChange: (q) => setState(() => _quarter = q),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Class Record Preview',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: AppFonts.bold,
                                    color: AppColors.navyDark,
                                  ),
                                ),
                              ),
                              if (subject.transmute)
                                const Badge(
                                  label: 'Transmuted',
                                  color: AppColors.amber,
                                  bg: Color(0xFFFFF1D6),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${section.gradeLevel} — ${section.section} · '
                            '${subject.name} · Q$_quarter · SY ${section.schoolYear}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSoft,
                            ),
                          ),
                          Text(
                            '${roster.length} students · teacher '
                            '${subject.teacherName.isEmpty
                                ? state.teacherName
                                : subject.teacherName}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSoft,
                            ),
                          ),
                          if (summary == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'No computed grades yet for this selection.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Row(
                                children: [
                                  _Stat(
                                      label: 'Average',
                                      value: summary.avg.toStringAsFixed(1)),
                                  const SizedBox(width: 8),
                                  _Stat(
                                      label: 'Highest',
                                      value: summary.high.toStringAsFixed(1)),
                                  const SizedBox(width: 8),
                                  _Stat(
                                      label: 'Lowest',
                                      value: summary.low.toStringAsFixed(1)),
                                  const SizedBox(width: 8),
                                  _Stat(
                                      label: 'Passed',
                                      value:
                                          '${summary.passed}/${summary.total}'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const _SectionTitle('Class Record Actions'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ActionTile(
                          icon: Ionicons.print,
                          label: 'Print',
                          hint: 'Direct printer',
                          loading: _busy == 'print',
                          onTap: () => _withBusy('print', () async {
                            await printClassRecord(
                              state.backupData(),
                              section,
                              subject,
                              _quarter,
                            );
                          }),
                        ),
                        _ActionTile(
                          icon: Ionicons.document,
                          label: 'Save PDF',
                          hint: 'Share or store',
                          loading: _busy == 'pdf',
                          onTap: () => _withBusy('pdf', () async {
                            await shareClassRecordPdf(
                              state.backupData(),
                              section,
                              subject,
                              _quarter,
                            );
                          }),
                        ),
                        _ActionTile(
                          icon: Ionicons.grid,
                          label: 'Roster PDF',
                          hint: 'Names + LRN',
                          loading: _busy == 'roster',
                          onTap: () => _withBusy('roster', () async {
                            await shareRosterPdf(
                              state.backupData(),
                              section.id,
                              section,
                            );
                          }),
                        ),
                        _ActionTile(
                          icon: Ionicons.grid,
                          label: 'Class CSV',
                          hint: 'Grades for Excel',
                          loading: _busy == 'csv',
                          onTap: () => _withBusy('csv', () async {
                            final csv = buildClassRecordCsv(
                              state.backupData(),
                              section,
                              subject,
                              _quarter,
                            );
                            final path = await exportCsvFile(
                              'class-record-${subject.name}-Q$_quarter',
                              csv,
                            );
                            await shareFile(path,
                                title: 'Export class record CSV');
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                const _SectionTitle('Data Backup'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: AppCard(
                    child: _BackupCard(),
                  ),
                ),
                const _SectionTitle('Search Records'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: AppCard(
                    child: Text(
                      'Use the search box inside each class (Students tab) to '
                      'find a learner by name or LRN, or tap any student to '
                      'open their full profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSoft,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary {
  const _Summary({
    required this.avg,
    required this.high,
    required this.low,
    required this.passed,
    required this.total,
  });

  final double avg;
  final double high;
  final double low;
  final int passed;
  final int total;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: AppFonts.extrabold,
                color: AppColors.navyDark,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 42) / 2,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ice,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.navy,
                        ),
                      )
                    : Icon(icon, size: 20, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: AppFonts.semibold,
                  color: AppColors.navyDark,
                ),
              ),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
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

class _BackupCard extends StatefulWidget {
  const _BackupCard();

  @override
  State<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<_BackupCard> {
  String? _path;
  String _busy = '';

  @override
  void initState() {
    super.initState();
    autoBackupDirPath().then(
          (value) => mounted ? setState(() => _path = value) : null,
        );
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final today = todayIso();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFDFF5E7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Ionicons.cloudDone,
                  size: 20, color: AppColors.green),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic CSV backup',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    'Runs after every save (attendance, scores, edits).',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSoft,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Latest: ${formatShortDate(today)}',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSoft),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Ionicons.refresh,
                label: 'Back up now',
                hint: 'Rewrite CSV files',
                loading: _busy == 'auto',
                onTap: () => _run('auto', () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await writeAutoBackups(state.backupData());
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Latest CSV backups saved in: $_path',
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Ionicons.cloudUpload,
                label: 'Full backup',
                hint: 'Share one CSV',
                loading: _busy == 'backup',
                onTap: () => _run('backup', () async {
                  final path =
                      await exportFullBackupCsv(state.backupData());
                  await shareFile(path, title: 'Full CSV backup');
                }),
              ),
            ),
          ],
        ),
        if (_path != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Backup folder: $_path',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}
