/// TIS ClassTrack — offline class record app for teachers.
///
/// Startup: splash (mockup 1) → MPIN setup or MPIN login (mockup 2) → tabs.
/// All records live in the on-device SQLite database; the MPIN gate re-locks
/// whenever the app goes to the background.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/splash.dart';
import 'state/app_lock.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final appState = AppState();
  final appLock = AppLock();

  // Load the SQLite database while the splash screen runs; the splash waits
  // for `hydrated` before routing to setup/login.
  unawaited(appState.load());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<AppLock>.value(value: appLock),
      ],
      child: const TisClassTrackApp(),
    ),
  );
}

class TisClassTrackApp extends StatelessWidget {
  const TisClassTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TIS ClassTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
