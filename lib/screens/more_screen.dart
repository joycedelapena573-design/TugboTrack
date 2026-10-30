import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../state/app_lock.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'bmi.dart';
import 'reports.dart';
import 'settings.dart';

/// More tab: quick access to BMI, reports, security and about.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final teacher = state.teacherName.trim();
    final initials = teacher.isEmpty ? 'T' : teacher[0].toUpperCase();

    return Screen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: AppFonts.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.isEmpty ? 'Teacher' : teacher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: AppFonts.bold,
                          color: AppColors.navyDark,
                        ),
                      ),
                      const Text(
                        'Tugbo Integrated School',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(value: state.students.length, label: 'Students'),
              const SizedBox(width: 10),
              _MiniStat(value: state.attendance.length, label: 'Attendance days'),
              const SizedBox(width: 10),
              _MiniStat(value: state.bmi.length, label: 'BMI records'),
            ],
          ),
          const SizedBox(height: 14),
          _Tile(
            icon: Ionicons.body,
            label: 'BMI Monitoring',
            hint: 'Height, weight & interpretation',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BmiScreen()),
            ),
          ),
          _Tile(
            icon: Ionicons.documentText,
            label: 'Reports & Exports',
            hint: 'Print, PDF and CSV backups',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          ),
          _Tile(
            icon: Ionicons.key,
            label: 'Security',
            hint: 'Change your MPIN',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _Tile(
            icon: Ionicons.lockClosed,
            label: 'Lock Now',
            hint: 'Require MPIN to continue',
            iconBg: const Color(0xFFFFF1D6),
            iconColor: AppColors.amber,
            onTap: () {
              context.read<AppLock>().lock();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'All records are stored offline on this device and protected by your 6-digit MPIN.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textFaint,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: AppFonts.extrabold,
                color: AppColors.navyDark,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSoft,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.iconBg = AppColors.ice,
    this.iconColor = AppColors.navy,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: AppFonts.semibold,
                        color: AppColors.navyDark,
                      ),
                    ),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Ionicons.chevronForward, size: 20, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
