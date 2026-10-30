/// Seat-tap attendance board shown right inside the class screen.
///
/// The teacher taps each student's assigned seat number to mark them
/// Present / Late / Absent / Excused (requirement 3); a long-press clears a
/// seat. Records save to the device automatically.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

const List<AttendanceStatus> _statusOrder = [
  AttendanceStatus.present,
  AttendanceStatus.late,
  AttendanceStatus.absent,
  AttendanceStatus.excused,
];

/// Brand colours for the four attendance states.
({Color color, Color bg}) attendanceMeta(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.present:
      return (color: const Color(0xFF1B7F4B), bg: const Color(0xFFDFF5E7));
    case AttendanceStatus.late:
      return (color: const Color(0xFFB26A00), bg: const Color(0xFFFFF1D6));
    case AttendanceStatus.absent:
      return (color: const Color(0xFFC0392B), bg: const Color(0xFFFDE4E1));
    case AttendanceStatus.excused:
      return (color: const Color(0xFF2C5FBF), bg: const Color(0xFFE1EBFC));
  }
}

class SeatBoard extends StatefulWidget {
  const SeatBoard({super.key, required this.sectionId, this.onOpenFull});

  final String sectionId;
  final VoidCallback? onOpenFull;

  @override
  State<SeatBoard> createState() => _SeatBoardState();
}

class _SeatBoardState extends State<SeatBoard> {
  String _date = todayIso();
  AttendanceStatus _brush = AttendanceStatus.present;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final roster = state.studentsOf(widget.sectionId);
    final dayId = '${widget.sectionId}::$_date';
    final statuses = state.attendance[dayId]?.statuses ?? const <String, AttendanceStatus>{};

    final counts = <AttendanceStatus, int>{
      for (final status in AttendanceStatus.values) status: 0,
    };
    for (final student in roster) {
      final value = statuses[student.id];
      if (value != null) counts[value] = counts[value]! + 1;
    }
    final marked = counts.values.fold<int>(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateBar(
            date: _date,
            onChanged: (next) => setState(() => _date = next),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final status in _statusOrder)
                Builder(builder: (context) {
                  final meta = attendanceMeta(status);
                  final active = _brush == status;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: active ? meta.bg : AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => setState(() => _brush = status),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: active ? meta.color : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              status.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: AppFonts.semibold,
                                color: active ? meta.color : AppColors.textSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'All present',
                  icon: Ionicons.checkmarkDone,
                  onTap: () => state.markAllAttendance(
                    widget.sectionId,
                    _date,
                    AttendanceStatus.present,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'All absent',
                  icon: Ionicons.closeCircleOutline,
                  light: true,
                  onTap: () => state.markAllAttendance(
                    widget.sectionId,
                    _date,
                    AttendanceStatus.absent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (roster.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Add students first — their seat numbers will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  color: AppColors.textSoft,
                  height: 1.4,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final student in roster)
                  _Seat(
                    seatNumber: student.seatNumber,
                    name: student.fullName,
                    status: statuses[student.id],
                    onTap: () {
                      HapticFeedback.selectionClick();
                      state.setAttendance(widget.sectionId, _date, student.id, _brush);
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      state.clearAttendanceSeat(widget.sectionId, _date, student.id);
                    },
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                for (final status in _statusOrder)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${counts[status]}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            fontWeight: AppFonts.extrabold,
                            color: attendanceMeta(status).color,
                          ),
                        ),
                        Text(
                          status.label,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            roster.isNotEmpty && marked == roster.length
                ? '✓ All seats marked — saved on this device'
                : '$marked/${roster.length} seats marked · saved automatically',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: AppFonts.medium,
              color: AppColors.textSoft,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Tip: long-press a seat to clear its mark.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                color: AppColors.textFaint,
              ),
            ),
          ),
          if (widget.onOpenFull != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Material(
                color: AppColors.ice,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: widget.onOpenFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Open the full attendance screen',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: AppFonts.semibold,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Ionicons.arrowForward,
                          size: 15,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({required this.date, required this.onChanged});

  final String date;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = todayIso();
    final canGoForward = date.compareTo(today) < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ArrowButton(
            icon: Ionicons.chevronBack,
            onTap: () => onChanged(addDays(date, -1)),
          ),
          Text(
            formatDayLabel(date),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.5,
              fontWeight: AppFonts.bold,
              color: AppColors.navyDark,
            ),
          ),
          Opacity(
            opacity: canGoForward ? 1 : 0.35,
            child: _ArrowButton(
              icon: Ionicons.chevronForward,
              onTap: canGoForward ? () => onChanged(addDays(date, 1)) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ice,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 18, color: AppColors.navy),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.light = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? AppColors.navy : AppColors.white;
    return Material(
      color: light ? AppColors.ice : AppColors.navy,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: AppFonts.semibold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.seatNumber,
    required this.name,
    required this.status,
    required this.onTap,
    required this.onLongPress,
  });

  final int seatNumber;
  final String name;
  final AttendanceStatus? status;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final meta = status == null ? null : attendanceMeta(status!);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 3;
        return SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 0.95,
            child: Material(
              color: meta?.bg ?? AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onTap,
                onLongPress: onLongPress,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: meta?.color ?? AppColors.border,
                      width: 2,
                    ),
                    boxShadow: AppShadow.soft,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$seatNumber',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 17,
                              fontWeight: AppFonts.extrabold,
                              color: meta?.color ?? AppColors.navy,
                            ),
                          ),
                          if (meta != null)
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: meta.color,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                status!.code,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: AppFonts.bold,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: AppFonts.semibold,
                          color: AppColors.text,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
