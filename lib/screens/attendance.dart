import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/seat_board.dart';
import '../widgets/ui.dart';

/// Full-screen attendance by seat (requirement 3): tap each seat number to
/// mark Present / Late / Absent / Excused. Everything auto-saves.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key, this.sectionId});

  /// Class to open; falls back to the last active class.
  final String? sectionId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sections = state.sections.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final resolved = sectionId ??
        state.activeSectionId ??
        (sections.isEmpty ? null : sections.first.id);
    final section = state.section(resolved);

    if (section == null) {
      return Screen(
        child: Column(
          children: [
            const PageHeader(
              title: 'Attendance',
              subtitle: 'Create a class first to take attendance',
            ),
            const Expanded(
              child: EmptyState(
                icon: Ionicons.gridOutline,
                title: 'No classes found',
                subtitle: 'Add one from the Home tab.',
              ),
            ),
          ],
        ),
      );
    }

    final subtitle =
        '${section.gradeLevel} — ${section.section} · SY ${section.schoolYear}';

    return Screen(
      child: Column(
        children: [
          PageHeader(
            title: 'Attendance',
            subtitle: subtitle,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          if (sections.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: ChipRow(
                children: [
                  for (final sec in sections)
                    AppChip(
                      label:
                          '${sec.gradeLevel.replaceFirst('Grade ', 'G')} — ${sec.section}',
                      active: sec.id == section.id,
                      onTap: () =>
                          context.read<AppState>().setActiveSection(sec.id),
                    ),
                ],
              ),
            ),
          Expanded(child: SeatBoard(sectionId: section.id)),
        ],
      ),
    );
  }
}
