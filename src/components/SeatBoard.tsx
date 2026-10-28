/**
 * Seat-tap attendance board shown right inside the class screen.
 * The teacher taps each student's assigned seat number to mark them
 * Present / Late / Absent / Excused (requirement 3); a long-press clears a
 * seat. Records save to the device automatically.
 */
import { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';

import { addDays, formatDayLabel, todayISO } from '../lib/format';
import { useStore } from '../lib/store';
import { ATTENDANCE_META, type AttendanceStatus } from '../lib/types';
import { colors, fonts, radius, shadow } from '../lib/theme';

const STATUS_ORDER: AttendanceStatus[] = ['present', 'late', 'absent', 'excused'];

export function SeatBoard({
  sectionId,
  onOpenFull,
}: {
  sectionId: string;
  onOpenFull?: () => void;
}) {
  const students = useStore((s) => s.students);
  const attendance = useStore((s) => s.attendance);
  const setAttendance = useStore((s) => s.setAttendance);
  const clearAttendanceSeat = useStore((s) => s.clearAttendanceSeat);
  const markAllAttendance = useStore((s) => s.markAllAttendance);

  const [date, setDate] = useState(todayISO());
  const [brush, setBrush] = useState<AttendanceStatus>('present');

  const roster = useMemo(
    () =>
      Object.values(students)
        .filter((s) => s.sectionId === sectionId)
        .sort((a, b) => a.seatNumber - b.seatNumber),
    [students, sectionId],
  );

  const dayId = `${sectionId}::${date}`;
  const statuses = useMemo(() => attendance[dayId]?.statuses ?? {}, [attendance, dayId]);
  const counts = useMemo(() => {
    const c: Record<AttendanceStatus, number> = { present: 0, late: 0, absent: 0, excused: 0 };
    for (const st of roster) {
      const v = statuses[st.id];
      if (v) c[v] += 1;
    }
    return c;
  }, [roster, statuses]);
  const marked = counts.present + counts.late + counts.absent + counts.excused;

  const markSeat = (studentId: string) => {
    Haptics.selectionAsync().catch(() => {});
    setAttendance(sectionId, date, studentId, brush);
  };

  const clearSeat = (studentId: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    clearAttendanceSeat(sectionId, date, studentId);
  };

  return (
    <View style={styles.wrap}>
      {/* Date navigation */}
      <View style={styles.dateRow}>
        <Pressable style={styles.dateArrow} onPress={() => setDate(addDays(date, -1))} hitSlop={6}>
          <Ionicons name="chevron-back" size={18} color={colors.navy} />
        </Pressable>
        <Text style={styles.dateText}>{formatDayLabel(date)}</Text>
        <Pressable
          style={[styles.dateArrow, date >= todayISO() && { opacity: 0.35 }]}
          disabled={date >= todayISO()}
          onPress={() => setDate(addDays(date, 1))}
          hitSlop={6}
        >
          <Ionicons name="chevron-forward" size={18} color={colors.navy} />
        </Pressable>
      </View>

      {/* Status brush */}
      <View style={styles.brushRow}>
        {STATUS_ORDER.map((status) => {
          const meta = ATTENDANCE_META[status];
          const active = brush === status;
          return (
            <Pressable
              key={status}
              onPress={() => setBrush(status)}
              style={[
                styles.brush,
                {
                  backgroundColor: active ? meta.bg : colors.white,
                  borderColor: active ? meta.color : colors.border,
                },
              ]}
            >
              <Text style={[styles.brushLabel, { color: active ? meta.color : colors.textSoft }]}>
                {meta.label}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <View style={styles.actionsRow}>
        <Pressable style={styles.actionBtn} onPress={() => markAllAttendance(sectionId, date, 'present')}>
          <Ionicons name="checkmark-done" size={15} color={colors.white} />
          <Text style={styles.actionLabel}>All present</Text>
        </Pressable>
        <Pressable
          style={[styles.actionBtn, styles.actionLight]}
          onPress={() => markAllAttendance(sectionId, date, 'absent')}
        >
          <Ionicons name="close-circle-outline" size={15} color={colors.navy} />
          <Text style={[styles.actionLabel, { color: colors.navy }]}>All absent</Text>
        </Pressable>
      </View>

      {/* Seat board — tap to mark, long-press to clear */}
      <View style={styles.board}>
        {roster.map((st) => {
          const status = statuses[st.id];
          const meta = status ? ATTENDANCE_META[status] : null;
          return (
            <Pressable
              key={st.id}
              onPress={() => markSeat(st.id)}
              onLongPress={() => clearSeat(st.id)}
              style={[
                styles.seat,
                meta
                  ? { backgroundColor: meta.bg, borderColor: meta.color }
                  : { backgroundColor: colors.white, borderColor: colors.border },
              ]}
            >
              <View style={styles.seatTop}>
                <Text style={[styles.seatNumber, meta && { color: meta.color }]}>{st.seatNumber}</Text>
                {meta ? (
                  <View style={[styles.seatCode, { backgroundColor: meta.color }]}>
                    <Text style={styles.seatCodeText}>{meta.code}</Text>
                  </View>
                ) : null}
              </View>
              <Text style={styles.seatName} numberOfLines={2}>
                {st.fullName}
              </Text>
            </Pressable>
          );
        })}
      </View>

      {roster.length === 0 ? (
        <Text style={styles.empty}>Add students first — their seat numbers will appear here.</Text>
      ) : null}

      {/* Summary */}
      <View style={styles.summary}>
        {STATUS_ORDER.map((status) => {
          const meta = ATTENDANCE_META[status];
          return (
            <View key={status} style={styles.summaryItem}>
              <Text style={[styles.summaryValue, { color: meta.color }]}>{counts[status]}</Text>
              <Text style={styles.summaryLabel}>{meta.label}</Text>
            </View>
          );
        })}
      </View>
      <Text style={styles.saveNote}>
        {roster.length > 0 && marked === roster.length
          ? '✓ All seats marked — saved on this device'
          : `${marked}/${roster.length} seats marked · saved automatically`}
      </Text>
      <Text style={styles.longPressHint}>Tip: long-press a seat to clear its mark.</Text>

      {onOpenFull ? (
        <Pressable style={styles.fullLink} onPress={onOpenFull}>
          <Text style={styles.fullLinkText}>Open the full attendance screen</Text>
          <Ionicons name="arrow-forward" size={15} color={colors.blue} />
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    backgroundColor: colors.bg,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.lg,
    padding: 12,
    marginBottom: 16,
    ...shadow.soft,
  },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.border,
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  dateArrow: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dateText: { fontFamily: fonts.bold, fontSize: 14.5, color: colors.navyDark },
  brushRow: { flexDirection: 'row', gap: 6, marginTop: 10 },
  brush: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 9,
    borderRadius: radius.md,
    borderWidth: 2,
  },
  brushLabel: { fontFamily: fonts.semibold, fontSize: 11.5 },
  actionsRow: { flexDirection: 'row', gap: 8, marginTop: 8 },
  actionBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: colors.navy,
    paddingVertical: 10,
    borderRadius: radius.md,
  },
  actionLight: { backgroundColor: colors.ice, borderWidth: 1.5, borderColor: colors.border },
  actionLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.white },
  board: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 10 },
  seat: {
    width: '31%',
    aspectRatio: 0.95,
    borderRadius: radius.md,
    borderWidth: 2,
    padding: 8,
    justifyContent: 'space-between',
    ...shadow.soft,
  },
  seatTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  seatNumber: { fontFamily: fonts.extrabold, fontSize: 17, color: colors.navy },
  seatCode: { width: 20, height: 20, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  seatCodeText: { fontFamily: fonts.bold, fontSize: 11, color: colors.white },
  seatName: { fontFamily: fonts.semibold, fontSize: 11, color: colors.text, lineHeight: 14 },
  empty: {
    fontFamily: fonts.regular,
    fontSize: 12.5,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 12,
    lineHeight: 18,
  },
  summary: {
    flexDirection: 'row',
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    paddingVertical: 10,
    marginTop: 10,
  },
  summaryItem: { flex: 1, alignItems: 'center' },
  summaryValue: { fontFamily: fonts.extrabold, fontSize: 17 },
  summaryLabel: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textSoft },
  saveNote: {
    fontFamily: fonts.medium,
    fontSize: 11.5,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 8,
  },
  longPressHint: {
    fontFamily: fonts.regular,
    fontSize: 10.5,
    color: colors.textFaint,
    textAlign: 'center',
    marginTop: 2,
  },
  fullLink: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    marginTop: 10,
    paddingVertical: 9,
    borderRadius: radius.md,
    backgroundColor: colors.ice,
    borderWidth: 1.5,
    borderColor: colors.border,
  },
  fullLinkText: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.blue },
});
