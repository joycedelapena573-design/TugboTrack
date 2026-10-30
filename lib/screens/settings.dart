/// Settings: teacher profile, change MPIN (requirement 6.3), school logo,
/// backup status, and app information.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../services/backup.dart';
import '../services/mpin.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
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
                  const _SectionTitle('Data & Storage'),
                  AppCard(
                    child: Column(
                      children: [
                        _StorageRow(
                          label: 'Records stored',
                          value: '${state.students.length} students',
                        ),
                        const _StorageRow(
                          label: 'Storage',
                          value: 'Offline (this device)',
                        ),
                        FutureBuilder<String>(
                          future: autoBackupDirPath(),
                          builder: (context, snapshot) => _StorageRow(
                            label: 'Auto-backup folder',
                            value: snapshot.data ?? '…',
                            small: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppButton(
                          label: 'Open Reports & Backups',
                          variant: ButtonVariant.secondary,
                          icon: Ionicons.documentText,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReportsScreen()),
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
