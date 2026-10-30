/// Splash / loading screen (mockup 1). Shown on every app open, whether the
/// teacher is new or returning, then routes to MPIN setup or MPIN login.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/mpin.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/decor.dart';
import '../widgets/school_logo.dart';
import 'mpin_login.dart';
import 'mpin_setup.dart';

const Duration _splashMs = Duration(milliseconds: 2400);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _splashMs)
      ..forward();
    _decide();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _decide() async {
    final state = context.read<AppState>();
    await Future.wait([
      Future<void>.delayed(_splashMs),
      _waitForHydration(state),
    ]);
    final mpinSet = await MpinService().hasMpin();
    if (!mounted || _decided) return;
    setState(() => _decided = true);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) =>
            mpinSet ? const MpinLoginScreen() : const MpinSetupScreen(),
      ),
    );
  }

  Future<void> _waitForHydration(AppState state) async {
    while (!state.hydrated) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7FAFF), Color(0xFFE3EDFD)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -width * 0.02,
              left: -width * 0.14,
              child: topCornerCurve(
                width: width * 0.62,
                height: width * 0.44,
              ),
            ),
            Positioned(
              top: height * 0.02,
              right: width * 0.04,
              child: Opacity(
                opacity: 0.9,
                child: bookDoodle(size: width * 0.28),
              ),
            ),
            Positioned(
              top: height * 0.55,
              left: -8,
              child: Opacity(opacity: 0.5, child: leaf(size: 44)),
            ),
            Positioned(
              top: height * 0.5,
              right: -6,
              child: Opacity(
                opacity: 0.45,
                child: leaf(size: 38, color: '#A9C6F7'),
              ),
            ),
            Positioned(
              bottom: -10,
              left: -width * 0.06,
              child: bookStack(width: width * 0.62),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: bottomWave(
                width: width,
                height: math.max(150, height * 0.16),
              ),
            ),
            SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 8),
                    _center(width: width, height: height),
                    _footer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _center({required double width, required double height}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SchoolLogo(size: width * 0.36),
          const SizedBox(height: 14),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Class',
                          style: TextStyle(color: AppColors.navyDark),
                        ),
                        const TextSpan(
                          text: 'Track',
                          style: TextStyle(color: AppColors.blue),
                        ),
                      ],
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 42,
                        fontWeight: AppFonts.extrabold,
                        letterSpacing: -1,
                      ),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              Positioned(
                top: -34,
                left: width * 0.31,
                child: capIcon(size: 46),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 26, height: 3, color: AppColors.blueSoft),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Tugbo Integrated School',
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.navy,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 26, height: 3, color: AppColors.blueSoft),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Smarter Class Records,\nMade Simple.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 34,
              fontWeight: AppFonts.bold,
              color: AppColors.navy,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          swoosh(width: width * 0.4),
          const SizedBox(height: 24),
          Container(
            constraints: BoxConstraints(maxWidth: width * 0.82),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0A3A8C),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                clipboardCheckIcon(size: 30),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Loading your class records...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: AppFonts.semibold,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: width * 0.42,
            height: 12,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFC6D9F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => FractionallySizedBox(
                widthFactor: _controller.value,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _footer() {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Your Class Records,\nOrganized.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 28,
              fontWeight: AppFonts.bold,
              color: AppColors.white,
              height: 1.05,
            ),
          ),
          SizedBox(height: 4),
          SizedBox(width: 110, child: _FooterSwoosh()),
        ],
      ),
    );
  }
}

class _FooterSwoosh extends StatelessWidget {
  const _FooterSwoosh();

  @override
  Widget build(BuildContext context) => swoosh(width: 110);
}
