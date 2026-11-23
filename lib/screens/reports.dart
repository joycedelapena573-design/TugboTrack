/// Reports: class records, term and final grade sheets, rosters, attendance
/// summaries and CSV exports — all generated on the device.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/backup.dart';
import '../services/reports.dart' as reports;
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'section_form.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.sectionId});

  final String? sectionId;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _sectionId = '';
  String? _subjectId;
  int _term = 1;
  String? _busy;

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
      _subjectId = subjects.isEmpty ? null : subjects.first.id;
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
            const PageHeader(title: 'Reports', subtitle: 'No class yet'),
            EmptyState(
              icon: Ionicons.documentTextOutline,
              title: 'Nothing to report yet',
              subtitle: 'Create a class and record scores to generate reports.',
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
    final subjects = state.subjectsOf(section.id);
    final subject = subjects.where((value) => value.id == _subjectId).firstOrNull ??
        (subjects.isEmpty ? null : subjects.first);
    final inTerm = subjects.where((value) => value.covers(_term)).toList();
    final roster = state.studentsOf(section.id);
    final data = state.backupData();

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Reports',
            subtitle: '${section.title} · ${termLabel(_term)}',
            onBack: () => Navigator.of(context).maybePop(),
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
                    });
                    context.read<AppState>().setActiveSection(value.id);
                  },
                ),
            ]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: [
                Segmented<int>(
                  options: [
                    for (final term in terms)
                      SegmentedOption(term, termShortLabel(term)),
                  ],
                  value: _term,
                  onChange: (term) {
                    setState(() => _term = term);
                    context.read<AppState>().setActiveTerm(term);
                  },
                ),
                const SizedBox(height: 14),
                if (_busy != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _busy!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                _ReportCard(
                  icon: Ionicons.readerOutline,
                  title: 'Class Record',
                  subtitle: subject == null
                      ? 'Add a subject to print its class record.'
                      : '${subject.name} · ${termLabel(_term)} — WW/PT/TE '
                          'percentages, initial grade and term grade.',
                  child: subject == null
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subjects.length > 1) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final value in subjects)
                                    AppChip(
                                      label: value.name,
                                      active: value.id == subject.id,
                                      onTap: () =>
                                          setState(() => _subjectId = value.id),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            _ActionRow(
                              busy: _busy != null,
                              actions: [
                                _Action(
                                  label: 'Print PDF',
                                  icon: Ionicons.printOutline,
                                  onTap: () => _run(
                                    'Preparing the class record…',
                                    () async {
                                      final bytes =
                                          await reports.buildClassRecordPdfBytes(
                                        data,
                                        section,
                                        subject,
                                        _term,
                                      );
                                      await reports.printPdfBytes(
                                        bytes,
                                        name: 'class-record-${subject.name}-t$_term',
                                      );
                                    },
                                  ),
                                ),
                                _Action(
                                  label: 'Share PDF',
                                  icon: Ionicons.shareSocialOutline,
                                  onTap: () => _run(
                                    'Preparing the class record…',
                                    () async {
                                      final bytes =
                                          await reports.buildClassRecordPdfBytes(
                                        data,
                                        section,
                                        subject,
                                        _term,
                                      );
                                      await reports.sharePdfBytes(
                                        bytes,
                                        name: 'class-record-${subject.name}-t$_term.pdf',
                                      );
                                    },
                                  ),
                                ),
                                _Action(
                                  label: 'CSV',
                                  icon: Ionicons.gridOutline,
                                  onTap: () => _run('Exporting CSV…', () async {
                                    final origin =
                                        shareOriginOf(context);
                                    final csv = buildClassRecordCsv(
                                      data,
                                      section,
                                      subject,
                                      _term,
                                    );
                                    final path = await exportCsvFile(
                                      'class-record-${_slug(subject.name)}-t$_term.csv',
                                      csv,
                                    );
                                    await shareFile(
                                      path,
                                      title: 'Class record CSV',
                                      origin: origin,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),

                _ReportCard(
                  icon: Ionicons.statsChartOutline,
                  title: 'Term Grades',
                  subtitle: inTerm.isEmpty
                      ? 'No subject is offered in ${termLabel(_term)}.'
                      : 'Every subject offered in ${termLabel(_term)} with each '
                          'learner’s term grade.',
                  child: inTerm.isEmpty
                      ? null
                      : _ActionRow(
                          busy: _busy != null,
                          actions: [
                            _Action(
                              label: 'Print PDF',
                              icon: Ionicons.printOutline,
                              onTap: () => _run('Preparing term grades…', () async {
                                final bytes =
                                    await reports.buildTermGradesPdfBytes(
                                  data,
                                  section,
                                  _term,
                                );
                                await reports.printPdfBytes(
                                  bytes,
                                  name: 'term-grades-t$_term',
                                );
                              }),
                            ),
                            _Action(
                              label: 'Share PDF',
                              icon: Ionicons.shareSocialOutline,
                              onTap: () => _run('Preparing term grades…', () async {
                                final bytes =
                                    await reports.buildTermGradesPdfBytes(
                                  data,
                                  section,
                                  _term,
                                );
                                await reports.sharePdfBytes(
                                  bytes,
                                  name: 'term-grades-${_slug(section.title)}-t$_term.pdf',
                                );
                              }),
                            ),
                          ],
                        ),
                ),

                _ReportCard(
                  icon: Ionicons.trophyOutline,
                  title: 'Final Grades',
                  subtitle: 'Average of the term grades of every subject, with '
                      'the general average.',
                  child: _ActionRow(
                    busy: _busy != null,
                    actions: [
                      _Action(
                        label: 'Print PDF',
                        icon: Ionicons.printOutline,
                        onTap: () => _run('Preparing final grades…', () async {
                          final bytes =
                              await reports.buildFinalGradesPdfBytes(data, section);
                          await reports.printPdfBytes(
                            bytes,
                            name: 'final-grades-${_slug(section.title)}',
                          );
                        }),
                      ),
                      _Action(
                        label: 'Share PDF',
                        icon: Ionicons.shareSocialOutline,
                        onTap: () => _run('Preparing final grades…', () async {
                          final bytes =
                              await reports.buildFinalGradesPdfBytes(data, section);
                          await reports.sharePdfBytes(
                            bytes,
                            name: 'final-grades-${_slug(section.title)}.pdf',
                          );
                        }),
                      ),
                      _Action(
                        label: 'CSV',
                        icon: Ionicons.gridOutline,
                        onTap: () => _run('Exporting CSV…', () async {
                          final origin = shareOriginOf(context);
                          final path = await exportCsvFile(
                            'final-grades-${_slug(section.title)}.csv',
                            buildFinalGradesCsv(data, section),
                          );
                          await shareFile(
                                      path,
                                      title: 'Final grades CSV',
                                      origin: origin,
                                    );
                        }),
                      ),
                    ],
                  ),
                ),

                _ReportCard(
                  icon: Ionicons.peopleOutline,
                  title: 'Learner Roster',
                  subtitle: '${roster.length} learners with LRN, birthday and '
                      'guardian contact.',
                  child: _ActionRow(
                    busy: _busy != null,
                    actions: [
                      _Action(
                        label: 'Print PDF',
                        icon: Ionicons.printOutline,
                        onTap: () => _run('Preparing the roster…', () async {
                          final bytes =
                              await reports.buildRosterPdfBytes(data, section);
                          await reports.printPdfBytes(
                            bytes,
                            name: 'roster-${_slug(section.title)}',
                          );
                        }),
                      ),
                      _Action(
                        label: 'Share PDF',
                        icon: Ionicons.shareSocialOutline,
                        onTap: () => _run('Preparing the roster…', () async {
                          final bytes =
                              await reports.buildRosterPdfBytes(data, section);
                          await reports.sharePdfBytes(
                            bytes,
                            name: 'roster-${_slug(section.title)}.pdf',
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                _ReportCard(
                  icon: Ionicons.calendarOutline,
                  title: 'Attendance',
                  subtitle: 'Days recorded, present/late/absent/excused totals '
                      'and attendance rate.',
                  child: _ActionRow(
                    busy: _busy != null,
                    actions: [
                      _Action(
                        label: 'Print PDF',
                        icon: Ionicons.printOutline,
                        onTap: () => _run('Preparing attendance…', () async {
                          final bytes =
                              await reports.buildAttendancePdfBytes(data, section);
                          await reports.printPdfBytes(
                            bytes,
                            name: 'attendance-${_slug(section.title)}',
                          );
                        }),
                      ),
                      _Action(
                        label: 'Share PDF',
                        icon: Ionicons.shareSocialOutline,
                        onTap: () => _run('Preparing attendance…', () async {
                          final bytes =
                              await reports.buildAttendancePdfBytes(data, section);
                          await reports.sharePdfBytes(
                            bytes,
                            name: 'attendance-${_slug(section.title)}.pdf',
                          );
                        }),
                      ),
                      _Action(
                        label: 'CSV',
                        icon: Ionicons.gridOutline,
                        onTap: () => _run('Exporting CSV…', () async {
                          final origin = shareOriginOf(context);
                          final path = await exportCsvFile(
                            'attendance-${_slug(section.title)}.csv',
                            buildAttendanceCsv(data, section),
                          );
                          await shareFile(
                                      path,
                                      title: 'Attendance CSV',
                                      origin: origin,
                                    );
                        }),
                      ),
                    ],
                  ),
                ),

                _ReportCard(
                  icon: Ionicons.readerOutline,
                  title: 'Report Cards (whole section)',
                  subtitle: 'One printable report card per learner in '
                      '${section.section}, with each saved remark.',
                  child: roster.isEmpty
                      ? null
                      : _ActionRow(
                          busy: _busy != null,
                          actions: [
                            _Action(
                              label: 'Print all',
                              icon: Ionicons.printOutline,
                              onTap: () => _run(
                                'Preparing the report cards…',
                                () async {
                                  final bytes = await reports
                                      .buildSectionReportCardsPdfBytes(
                                    data,
                                    section,
                                    comments: state.reportComments,
                                  );
                                  await reports.printPdfBytes(
                                    bytes,
                                    name:
                                        'report-cards-${_slug(section.title)}',
                                  );
                                },
                              ),
                            ),
                            _Action(
                              label: 'Share all',
                              icon: Ionicons.shareSocialOutline,
                              onTap: () => _run(
                                'Preparing the report cards…',
                                () async {
                                  final bytes = await reports
                                      .buildSectionReportCardsPdfBytes(
                                    data,
                                    section,
                                    comments: state.reportComments,
                                  );
                                  await reports.sharePdfBytes(
                                    bytes,
                                    name:
                                        'report-cards-${_slug(section.title)}.pdf',
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),

                _ReportCard(
                  icon: Ionicons.cloudDownloadOutline,
                  title: 'Full CSV Backup',
                  subtitle: 'Every class, learner, assessment, score, attendance '
                      'mark and BMI record in one spreadsheet-ready file.',
                  child: _ActionRow(
                    busy: _busy != null,
                    actions: [
                      _Action(
                        label: 'Share backup',
                        icon: Ionicons.shareSocialOutline,
                        onTap: () => _run('Building the backup…', () async {
                          final origin = shareOriginOf(context);
                          final path = await exportFullBackupCsv(data);
                          await shareFile(
                            path,
                            title: 'TugboTrack backup',
                            origin: origin,
                          );
                        }),
                      ),
                      _Action(
                        label: 'Export school year',
                        icon: Ionicons.folderOpenOutline,
                        onTap: () => _run('Exporting the school year…', () async {
                          final origin = shareOriginOf(context);
                          final year = state.activeSchoolYear ??
                              currentSchoolYear();
                          final paths = await exportSchoolYear(data, year);
                          await shareFiles(
                            paths,
                            title: 'TugboTrack $year export',
                            origin: origin,
                          );
                        }),
                      ),
                      _Action(
                        label: 'Write now',
                        icon: Ionicons.saveOutline,
                        onTap: () => _run('Writing the automatic backup…', () async {
                          await writeAutoBackups(data);
                        }),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FutureBuilder<String>(
                    future: autoBackupDirPath(),
                    builder: (context, snapshot) {
                      final dir = snapshot.data;
                      if (dir == null) return const SizedBox.shrink();
                      return Text(
                        'Automatic CSV backups are saved on this device in\n$dir',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                          height: 1.4,
                        ),
                      );
                    },
                  ),
                ),
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

  String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  Future<void> _run(String label, Future<void> Function() task) async {
    if (_busy != null) return;
    setState(() => _busy = label);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await task();
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not generate the report: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
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
                  child: Icon(icon, size: 19, color: AppColors.navy),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
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
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSoft,
                height: 1.4,
              ),
            ),
            if (child != null) ...[
              const SizedBox(height: 12),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Action {
  const _Action({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions, required this.busy});

  final List<_Action> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          _ActionChip(
            label: action.label,
            icon: action.icon,
            onTap: busy ? null : action.onTap,
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.ice,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.navy),
              const SizedBox(width: 6),
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
    );
  }
}

/// Kept so the settings screen can report the database file location.
Future<String> databaseFileLabel(AppState state) async {
  final path = await state.databasePath();
  return File(path).existsSync() ? path : path;
}
