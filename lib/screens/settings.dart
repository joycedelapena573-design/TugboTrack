/// Settings: teacher profile, change MPIN (requirement 6.3), school logo,
/// backup status, and app information.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/database.dart' show BackupPreview;
import '../models/models.dart';
import '../services/backup.dart';
import '../services/mpin.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/school_logo.dart';
import '../widgets/ui.dart';
import 'reports.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _mpin = MpinService();
  late final TextEditingController _name;
  bool _pickingLogo = false;
  String _logoMessage = '';
  final _oldPin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  String _message = '';
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<AppState>().teacherName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _oldPin.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
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

  void _saveName() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _message = 'Please enter your name.');
      return;
    }
    context.read<AppState>().setTeacherName(name);
    setState(() => _message = 'Teacher name saved.');
  }

  /// Let the teacher insert the actual school logo picture from their gallery.
  Future<void> _pickLogo() async {
    setState(() => _logoMessage = '');
    try {
      setState(() => _pickingLogo = true);
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy out of the picker's cache so the logo survives restarts.
      final documents = await getApplicationDocumentsDirectory();
      final extension = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final destination = File(p.join(documents.path, 'school-logo$extension'));
      if (destination.existsSync()) destination.deleteSync();
      await File(picked.path).copy(destination.path);

      if (!mounted) return;
      context.read<AppState>().setSchoolLogo(destination.path);
      setState(
        () => _logoMessage =
            'School logo updated — it now appears on the loading and MPIN screens.',
      );
    } catch (_) {
      _alert(
        'Could not use that picture',
        'Please try choosing a different image.',
      );
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _changeMpin() async {
    setState(() => _message = '');
    final oldPin = _oldPin.text;
    final newPin = _newPin.text;
    if (!_mpin.isValidMpin(oldPin)) {
      setState(() => _message = 'Enter your current $mpinLength-digit MPIN.');
      return;
    }
    if (!_mpin.isValidMpin(newPin)) {
      setState(
        () => _message = 'The new MPIN must be exactly $mpinLength numbers.',
      );
      return;
    }
    if (newPin != _confirmPin.text) {
      setState(() => _message = 'The new MPINs do not match.');
      return;
    }
    if (newPin == oldPin) {
      setState(
        () => _message = 'The new MPIN must be different from the current one.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _mpin.changeMpin(oldPin, newPin);
      if (!mounted) return;
      if (result.ok) {
        _oldPin.clear();
        _newPin.clear();
        _confirmPin.clear();
        _alert(
          'MPIN changed',
          'Your new MPIN is required the next time you open the app.',
        );
      } else if (result.reason == 'locked') {
        setState(
          () => _message = 'Too many failed attempts. Please wait and try again.',
        );
      } else {
        setState(() => _message = 'Your current MPIN is incorrect.');
      }
    } catch (_) {
      setState(() => _message = 'Could not change the MPIN. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  /// Copies the SQLite database to the backups folder and shares it.
  Future<void> _backupDatabase() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final origin = shareOriginOf(context);
    setState(() => _saving = true);
    try {
      final dir = await autoBackupDirPath();
      final now = DateTime.now();
      final name = 'tugbotrack-${now.year}${_two(now.month)}${_two(now.day)}'
          '-${_two(now.hour)}${_two(now.minute)}.db';
      final file = await state.backupDatabase(p.join(dir, name));
      await shareFile(
        file.path,
        title: 'TugboTrack database backup',
        origin: origin,
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not write the backup: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Saves a timestamped copy of the database on the device (no share sheet).
  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _saving = true);
    final file = await context.read<AppState>().backupNow();
    if (!mounted) return;
    setState(() => _saving = false);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          file == null
              ? 'Could not write the backup. Please try again.'
              : 'Backup saved: ${p.basename(file.path)}',
        ),
      ),
    );
  }

  /// Every class record of the active school year, as CSV files, shared at once.
  Future<void> _exportSchoolYear() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final origin = shareOriginOf(context);
    final year = state.activeSchoolYear ?? currentSchoolYear();
    setState(() => _exporting = true);
    try {
      final paths = await exportSchoolYear(state.backupData(), year);
      if (paths.isEmpty) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('No classes to export for this year.')),
        );
        return;
      }
      await shareFiles(
        paths,
        title: 'TugboTrack $year export',
        origin: origin,
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not export the school year: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Replaces the database with a backup file after an explicit confirmation.
  Future<void> _restoreDatabase() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['db', 'sqlite', 'sqlite3'],
    );
    if (picked == null) return;
    final path = picked.path;
    if (path == null) return;
    if (!mounted) return;

    BackupPreview? preview;
    try {
      preview = await context.read<AppState>().previewBackup(path);
    } catch (_) {
      preview = null;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          [
            'Every class, learner, score, grade and attendance record currently '
                'on this device will be replaced by the contents of “${picked.name}”.',
            if (preview != null)
              '\nThis file holds ${preview.classes} class(es), '
                  '${preview.students} learner(s), ${preview.subjects} subject(s), '
                  '${preview.attendanceDays} attendance day(s) and '
                  '${preview.bmiRecords} BMI record(s).',
            if (preview?.isNewerThanApp ?? false)
              '\nThis backup comes from a newer version of the app and cannot be '
                  'restored until the app is updated.',
          ].join(),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: ButtonVariant.ghost,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: 'Restore',
            variant: ButtonVariant.danger,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (preview?.isNewerThanApp ?? false) return;

    setState(() => _saving = true);
    try {
      await context.read<AppState>().restoreDatabase(path);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Backup restored.')),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not restore the backup: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final schoolLogoUri = state.schoolLogoUri;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Settings',
              subtitle: 'Profile, security and backups',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  const _SectionTitle('Teacher Profile'),
                  AppCard(
                    child: Column(
                      children: [
                        Field(
                          label: 'Your Name',
                          icon: Ionicons.person,
                          placeholder: 'Enter your full name',
                          controller: _name,
                          keyboardType: TextInputType.name,
                        ),
                        AppButton(
                          label: 'Save Name',
                          variant: ButtonVariant.secondary,
                          icon: Ionicons.checkmark,
                          onTap: _saveName,
                        ),
                      ],
                    ),
                  ),
                  const _SectionTitle('School Logo'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: const SchoolLogo(size: 76),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shown on the loading screen and both MPIN screens.',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: AppColors.textSoft,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Shown below',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.5,
                                      fontWeight: AppFonts.semibold,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_logoMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _logoMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.5,
                                fontWeight: AppFonts.medium,
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Insert School Logo',
                          variant: ButtonVariant.secondary,
                          icon: Ionicons.image,
                          onTap: _pickLogo,
                          loading: _pickingLogo,
                        ),
                        if (schoolLogoUri != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: AppButton(
                              label: 'Use Default Logo',
                              variant: ButtonVariant.ghost,
                              icon: Ionicons.refresh,
                              onTap: () =>
                                  context.read<AppState>().setSchoolLogo(null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _SectionTitle('Change MPIN'),
                  AppCard(
                    child: Column(
                      children: [
                        SecureField(
                          label: 'Current $mpinLength-digit MPIN',
                          icon: Ionicons.lockClosed,
                          placeholder: 'Enter current MPIN',
                          value: _oldPin.text,
                          onChanged: (text) => _oldPin.text =
                              text.replaceAll(RegExp(r'\D'), ''),
                        ),
                        SecureField(
                          label: 'New MPIN',
                          icon: Ionicons.key,
                          placeholder: 'Enter $mpinLength new numbers',
                          value: _newPin.text,
                          onChanged: (text) => _newPin.text =
                              text.replaceAll(RegExp(r'\D'), ''),
                        ),
                        SecureField(
                          label: 'Confirm New MPIN',
                          icon: Ionicons.key,
                          placeholder: 'Re-enter $mpinLength numbers',
                          value: _confirmPin.text,
                          onChanged: (text) => _confirmPin.text =
                              text.replaceAll(RegExp(r'\D'), ''),
                        ),
                        if (_message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: AppFonts.medium,
                                color: AppColors.red,
                              ),
                            ),
                          ),
                        AppButton(
                          label: 'Change MPIN',
                          icon: Ionicons.shieldCheckmark,
                          onTap: _changeMpin,
                          loading: _saving,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Your MPIN is stored as a salted hash in this device’s '
                            'secure keychain — it never leaves the phone.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: AppColors.textSoft,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SectionTitle('School Year & Terms'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final year in state.schoolYearNames)
                              AppChip(
                                label: year,
                                active: (state.activeSchoolYear ??
                                        currentSchoolYear()) ==
                                    year,
                                onTap: () =>
                                    context.read<AppState>().setActiveSchoolYear(year),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final term
                            in state.termsOf(state.activeSchoolYear))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Term ${term.term}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12.5,
                                      fontWeight: AppFonts.semibold,
                                      color: state.activeTerm == term.term
                                          ? AppColors.navy
                                          : AppColors.text,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_short(term.start)} – ${_short(term.end)}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: AppColors.textSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Subjects keep separate assessment and grade records for '
                          'each term. Switching terms never deletes anything.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textFaint,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SectionTitle('Display & Guidance'),
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Larger text',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13.5,
                                      fontWeight: AppFonts.semibold,
                                      color: AppColors.navyDark,
                                    ),
                                  ),
                                  Text(
                                    'Makes names, scores and buttons easier to '
                                    'read in class.',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: AppColors.textSoft,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: state.largeText,
                              activeTrackColor: AppColors.navy,
                              onChanged: (value) => context
                                  .read<AppState>()
                                  .setLargeText(value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Show the welcome tips again',
                          variant: ButtonVariant.ghost,
                          icon: Ionicons.bulbOutline,
                          onTap: () {
                            context.read<AppState>().resetTips();
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'The tips will appear on the Home tab.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const _SectionTitle('Data & Storage'),
                  AppCard(
                    child: Column(
                      children: [
                        _StorageRow(
                          label: 'Classes',
                          value:
                              '${state.totalClasses} active · ${state.archivedClasses().length} archived',
                        ),
                        _StorageRow(
                          label: 'Records stored',
                          value: '${state.students.length} students · '
                              '${state.subjects.length} subjects',
                        ),
                        const _StorageRow(
                          label: 'Storage',
                          value: 'Offline SQLite database',
                        ),
                        _StorageRow(
                          label: 'Last database backup',
                          value: state.lastBackupAt == null
                              ? 'Never'
                              : '${state.backupAgeDays == 0 ? 'Today' : '${state.backupAgeDays} days ago'}'
                                  ' · ${formatShortDate(state.lastBackupAt!.split('T').first)}',
                        ),
                        FutureBuilder<String>(
                          future: autoBackupDirPath(),
                          builder: (context, snapshot) => _StorageRow(
                            label: 'Auto-backup folder',
                            value: snapshot.data ?? '…',
                            small: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Open Reports & Backups',
                          variant: ButtonVariant.secondary,
                          icon: Ionicons.documentText,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReportsScreen()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Back up now',
                          variant: ButtonVariant.secondary,
                          icon: Ionicons.cloudDownloadOutline,
                          loading: _saving,
                          onTap: _backupNow,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Export school year (CSV)',
                          variant: ButtonVariant.ghost,
                          icon: Ionicons.folderOpenOutline,
                          loading: _exporting,
                          onTap: _exportSchoolYear,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Export database backup',
                          variant: ButtonVariant.ghost,
                          icon: Ionicons.saveOutline,
                          onTap: _backupDatabase,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Restore from database file',
                          variant: ButtonVariant.danger,
                          icon: Ionicons.refreshOutline,
                          onTap: _restoreDatabase,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A backup is a copy of the SQLite file with every '
                          'learner, score, grade and attendance record. Restoring '
                          'replaces everything currently on this device.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.textFaint,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _SectionTitle('About'),
                  const AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TIS ClassTrack',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: AppFonts.bold,
                            color: AppColors.navyDark,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Smarter Class Records, Made Simple. Built for Tugbo '
                          'Integrated School — student information, grades, '
                          'attendance, BMI and reports, all kept private on your device.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: AppColors.textSoft,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
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
}

String _short(String iso) {
  if (iso.isEmpty) return '—';
  return iso;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: AppFonts.bold,
          color: AppColors.navyDark,
        ),
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.label,
    required this.value,
    this.small = false,
  });

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bg)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: small ? 11 : 13,
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
