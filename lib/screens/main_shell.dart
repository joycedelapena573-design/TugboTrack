import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../state/app_lock.dart';
import '../theme/app_theme.dart';
import 'grades.dart';
import 'home.dart';
import 'more_screen.dart';
import 'mpin_login.dart';

/// Main tab shell: Home, Grades, More. Re-locks whenever the app resumes,
/// mirroring the React `useAppLock` store.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      context.read<AppLock>().lock();
    }
  }

  static const _pages = [
    HomeScreen(),
    GradesScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.watch<AppLock>().locked) return const MpinLoginScreen();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _TabButton(
                  icon: Ionicons.home,
                  label: 'Home',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _TabButton(
                  icon: Ionicons.statsChart,
                  label: 'Grades',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _TabButton(
                  icon: Ionicons.ellipsisHorizontalCircle,
                  label: 'More',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.navy : AppColors.textFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontWeight: AppFonts.semibold,
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
