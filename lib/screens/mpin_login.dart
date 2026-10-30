/// MPIN unlock screen. Required every time the app is opened or brought back
/// from the background (requirement 6.2). The whole frame — keypad included —
/// fits on one screen with no scrolling.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/mpin.dart';
import '../state/app_lock.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/decor.dart';
import '../widgets/pin_pad.dart';
import '../widgets/school_logo.dart';
import '../widgets/ui.dart';
import 'main_shell.dart';
import 'mpin_setup.dart';

class MpinLoginScreen extends StatefulWidget {
  const MpinLoginScreen({super.key});

  @override
  State<MpinLoginScreen> createState() => _MpinLoginScreenState();
}

class _MpinLoginScreenState extends State<MpinLoginScreen> {
  final _mpin = MpinService();
  String _pin = '';
  String _error = '';
  int _lockRemaining = 0;
  bool _checking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _mpin.lockoutRemainingMs().then((remaining) {
      if (remaining > 0 && mounted) _startTicker(remaining);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker(int remaining) {
    setState(() => _lockRemaining = remaining);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _lockRemaining -= 1000;
        if (_lockRemaining <= 1000) {
          timer.cancel();
          _lockRemaining = 0;
          _error = '';
        }
      });
    });
  }

  Future<void> _submit(String value) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final result = await _mpin.verifyMpin(value);
      if (!mounted) return;
      if (result.ok) {
        context.read<AppLock>().unlock();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
        return;
      }
      setState(() => _pin = '');
      if (result.reason == 'locked') {
        _startTicker(result.retryInMs);
        setState(
          () => _error = 'Too many attempts. Please wait before trying again.',
        );
      } else if (result.reason == 'unset') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MpinSetupScreen()),
        );
      } else {
        final attempts = result.attemptsLeft;
        setState(
          () => _error = 'Incorrect MPIN. $attempts '
              '${attempts == 1 ? 'attempt' : 'attempts'} left.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _onChange(String value) {
    if (_lockRemaining > 0 || _checking) return;
    setState(() => _pin = value);
    if (value.length == mpinLength) _submit(value);
  }

  @override
  Widget build(BuildContext context) {
    final teacherName = context.select<AppState, String>((s) => s.teacherName);
    final seconds = (_lockRemaining / 1000).ceil();
    final locked = _lockRemaining > 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
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
              Center(child: lockArt(size: 104)),
              const SizedBox(height: 8),
              Text(
                teacherName.isEmpty ? 'Welcome Back' : 'Welcome Back,',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 26,
                  fontWeight: AppFonts.extrabold,
                  color: AppColors.navyDark,
                ),
              ),
              if (teacherName.isNotEmpty)
                Text(
                  teacherName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.5,
                    fontWeight: AppFonts.semibold,
                    color: AppColors.blue,
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Enter your 6-digit MPIN to unlock\nyour class records.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.5,
                  color: AppColors.textSoft,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              PinDots(value: _pin),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    locked ? '$_error ($seconds s)' : _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: AppFonts.medium,
                      color: AppColors.red,
                    ),
                  ),
                ),
              PinPad(value: _pin, onChange: _onChange),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      child: AppButton(
                        label: 'Wait ${seconds}s',
                        variant: ButtonVariant.secondary,
                        onTap: () {},
                        disabled: true,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    children: [
                      const Text(
                        'Your Class Records, Organized.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          color: AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 7),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
