/// First-run MPIN setup (mockup 2). Creates the teacher profile and the
/// 6-digit MPIN that protects every class record on this device.
library;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../services/mpin.dart';
import '../state/app_lock.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/decor.dart';
import '../widgets/school_logo.dart';
import '../widgets/ui.dart';
import 'main_shell.dart';

class MpinSetupScreen extends StatefulWidget {
  const MpinSetupScreen({super.key});

  @override
  State<MpinSetupScreen> createState() => _MpinSetupScreenState();
}

class _MpinSetupScreenState extends State<MpinSetupScreen> {
  final _mpin = MpinService();
  final _name = TextEditingController();
  String _pin = '';
  String _confirm = '';
  String _error = '';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = '');
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (!_mpin.isValidMpin(_pin)) {
      setState(() => _error = 'Your MPIN must be exactly $mpinLength numbers.');
      return;
    }
    if (_pin != _confirm) {
      setState(() => _error = 'The MPINs you entered do not match.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _mpin.createMpin(_pin);
      if (!mounted) return;
      context.read<AppState>().setTeacherName(name);
      context.read<AppLock>().unlock();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (_) {
      setState(() => _error = 'Could not save your MPIN. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SchoolLogo(size: 46, circle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'TIS ',
                                style: TextStyle(color: AppColors.navyDark),
                              ),
                              const TextSpan(
                                text: 'ClassTrack',
                                style: TextStyle(color: AppColors.blue),
                              ),
                            ],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 22,
                              fontWeight: AppFonts.extrabold,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Tugbo Integrated School',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(child: lockArt(size: 100)),
              const SizedBox(height: 10),
              const Text(
                'Set Up Your MPIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 27,
                  fontWeight: AppFonts.extrabold,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your name and create a $mpinLength-digit MPIN\n'
                'to securely access your class records.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.5,
                  color: AppColors.textSoft,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Field(
                label: 'Teacher Name',
                icon: Ionicons.person,
                placeholder: 'Enter your full name',
                controller: _name,
                keyboardType: TextInputType.name,
                style: const EdgeInsets.only(bottom: 10),
              ),
              SecureField(
                label: 'Create $mpinLength-digit MPIN',
                icon: Ionicons.lockClosed,
                placeholder: 'Enter $mpinLength numbers',
                value: _pin,
                onChanged: (text) =>
                    setState(() => _pin = text.replaceAll(RegExp(r'\D'), '')),
              ),
              SecureField(
                label: 'Confirm $mpinLength-digit MPIN',
                icon: Ionicons.lockClosed,
                placeholder: 'Re-enter $mpinLength numbers',
                value: _confirm,
                onChanged: (text) => setState(
                  () => _confirm = text.replaceAll(RegExp(r'\D'), ''),
                ),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
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
              AppButton(
                label: 'Save and Continue',
                icon: Ionicons.arrowForward,
                onTap: _save,
                loading: _saving,
                style: const EdgeInsets.only(top: 2),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  const Text(
                    'Your Class Records, Organized.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: AppColors.textSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
