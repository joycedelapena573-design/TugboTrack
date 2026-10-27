/**
 * Attendance by seat (requirement 3): the teacher taps each student's seat
 * number to mark Present / Late / Absent / Excused. Everything auto-saves.
 */
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams } from 'expo-router';
import * as Haptics from 'expo-haptics';

import { ChipRow, PageHeader, Screen } from '../../components/ui';
import { addDays, formatDayLabel, todayISO } from '../../lib/format';
import { useStore } from '../../lib/store';
import { ATTENDANCE_META, type AttendanceStatus } from '../../lib/types';
import { colors, fonts, radius, shadow } from '../../lib/theme';

const STATUS_ORDER: AttendanceStatus[] = ['present', 'late', 'absent', 'excused'];

export default function Attendance() {
  const params = useLocalSearchParams<{ sectionId?: string }>();
  const paramSection = typeof params.sectionId === 'string' ? params.sectionId : undefined;

  const sections = useStore((s) => s.sections);
  const students = useStore((s) => s.students);
  const attendance = useStore((s) => s.attendance);
  const setAttendance = useStore((s) => s.setAttendance);
  const clearAttendanceSeat = useStore((s) => s.clearAttendanceSeat);
  const markAllAttendance = useStore((s) => s.markAllAttendance);
  const activeSectionId = useStore((s) => s.activeSectionId);
  const setActiveSection = useStore((s) => s.setActiveSection);

  const sectionList = useMemo(() => Object.values(sections).sort((a, b) => a.createdAt - b.createdAt), [sections]);
  const sectionId = paramSection ?? activeSectionId ?? sectionList[0]?.id ?? '';
  const section = sections[sectionId];

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
  const markedCount = counts.present + counts.late + counts.absent + counts.excused;

  if (!section) {
    return (
      <Screen>
        <PageHeader title="Attendance" subtitle="Create a class first to take attendance" />
        <View style={styles.emptyWrap}>
          <Ionicons name="grid-outline" size={44} color={colors.textFaint} />
          <Text style={styles.emptyText}>No classes found. Add one from the Home tab.</Text>
        </View>
      </Screen>
    );
  }

  const assignSeat = (studentId: string) => {
    Haptics.selectionAsync().catch(() => {});
    setAttendance(sectionId, date, studentId, brush);
  };

  const longPressSeat = (studentId: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
    clearAttendanceSeat(sectionId, date, studentId);
  };

  return (
    <Screen>
      <PageHeader title="Attendance" subtitle={`${section.gradeLevel} — ${section.section} · SY ${section.schoolYear}`} />

      {sectionList.length > 1 ? (
        <ChipRow>
          {sectionList.map((sec) => (
            <Pressable
              key={sec.id}
              onPress={() => setActiveSection(sec.id)}
              style={[styles.chip, sec.id === sectionId && styles.chipActive]}
            >
              <Text style={[styles.chipLabel, sec.id === sectionId && { color: colors.white }]}>
                {sec.gradeLevel.replace('Grade ', 'G')} — {sec.section}
              </Text>
            </Pressable>
          ))}
        </ChipRow>
      ) : null}

      {/* Date navigation */}
      <View style={styles.dateRow}>
        <Pressable style={styles.dateArrow} onPress={() => setDate(addDays(date, -1))}>
          <Ionicons name="chevron-back" size={20} color={colors.navy} />
        </Pressable>
        <View style={styles.dateCenter}>
          <Text style={styles.dateText}>{formatDayLabel(date)}</Text>
          <Pressable onPress={() => setDate(todayISO())}>
            <Text style={styles.todayLink}>{date === todayISO() ? 'Today' : 'Jump to today'}</Text>
          </Pressable>
        </View>
        <Pressable
          style={[styles.dateArrow, date >= todayISO() && { opacity: 0.35 }]}
          disabled={date >= todayISO()}
          onPress={() => setDate(addDays(date, 1))}
        >
          <Ionicons name="chevron-forward" size={20} color={colors.navy} />
        </Pressable>
      </View>

      {/* Brush selector */}
      <Text style={styles.hint}>Tap a seat number to mark:</Text>
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
                { backgroundColor: active ? meta.bg : colors.white, borderColor: active ? meta.color : colors.border },
              ]}
            >
              <View style={[styles.brushCode, { backgroundColor: meta.bg }]}>
                <Text style={[styles.brushCodeText, { color: meta.color }]}>{meta.code}</Text>
              </View>
              <Text style={[styles.brushLabel, { color: active ? meta.color : colors.textSoft }]}>{meta.label}</Text>
            </Pressable>
          );
        })}
      </View>

      <View style={styles.actionsRow}>
        <Pressable style={styles.actionBtn} onPress={() => markAllAttendance(sectionId, date, 'present')}>
          <Ionicons name="checkmark-done" size={16} color={colors.white} />
          <Text style={styles.actionLabel}>Mark all present</Text>
        </Pressable>
        <Pressable
          style={[styles.actionBtn, styles.actionLight]}
          onPress={() => markAllAttendance(sectionId, date, 'absent')}
        >
          <Ionicons name="close-circle-outline" size={16} color={colors.navy} />
          <Text style={[styles.actionLabel, { color: colors.navy }]}>All absent</Text>
        </Pressable>
      </View>

      {/* Seat board */}
      <ScrollView contentContainerStyle={styles.boardScroll} showsVerticalScrollIndicator={false}>
        <View style={styles.board}>
          {roster.map((st) => {
            const status = statuses[st.id];
            const meta = status ? ATTENDANCE_META[status] : null;
            return (
              <Pressable
                key={st.id}
                onPress={() => assignSeat(st.id)}
                onLongPress={() => longPressSeat(st.id)}
                style={[
                  styles.seat,
                  meta ? { backgroundColor: meta.bg, borderColor: meta.color } : { backgroundColor: colors.white, borderColor: colors.border },
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
          <Text style={styles.emptyBoard}>
            Add students to this class first — their seat numbers will appear here.
          </Text>
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
          {markedCount === roster.length && roster.length > 0
            ? '✓ All seats marked — saved on this device'
            : `${markedCount}/${roster.length} seats marked · saved automatically`}
        </Text>
        <Text style={styles.longPressHint}>Tip: long-press a seat to clear its mark.</Text>
        <View style={{ height: 20 }} />
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  emptyWrap: { alignItems: 'center', padding: 40, gap: 12 },
  emptyText: { fontFamily: fonts.medium, fontSize: 14, color: colors.textSoft, textAlign: 'center' },
  chip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  chipActive: { backgroundColor: colors.navy, borderColor: colors.navy },
  chipLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.text },
  dateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginHorizontal: 16,
    marginTop: 10,
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.border,
    padding: 8,
  },
  dateArrow: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dateCenter: { alignItems: 'center' },
  dateText: { fontFamily: fonts.bold, fontSize: 16, color: colors.navyDark },
  todayLink: { fontFamily: fonts.semibold, fontSize: 12, color: colors.blue, marginTop: 1 },
  hint: {
    fontFamily: fonts.medium,
    fontSize: 12.5,
    color: colors.textSoft,
    marginHorizontal: 16,
    marginTop: 12,
    marginBottom: 8,
  },
  brushRow: { flexDirection: 'row', gap: 8, paddingHorizontal: 16 },
  brush: {
    flex: 1,
    alignItems: 'center',
    gap: 4,
    paddingVertical: 10,
    borderRadius: radius.md,
    borderWidth: 2,
  },
  brushCode: { width: 28, height: 28, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  brushCodeText: { fontFamily: fonts.bold, fontSize: 14 },
  brushLabel: { fontFamily: fonts.semibold, fontSize: 11 },
  actionsRow: { flexDirection: 'row', gap: 8, paddingHorizontal: 16, marginTop: 10 },
  actionBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: colors.navy,
    paddingVertical: 11,
    borderRadius: radius.md,
  },
  actionLight: { backgroundColor: colors.ice, borderWidth: 1.5, borderColor: colors.border },
  actionLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.white },
  boardScroll: { padding: 16, paddingBottom: 28 },
  board: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  seat: {
    width: '31%',
    aspectRatio: 0.92,
    borderRadius: radius.md,
    borderWidth: 2,
    padding: 10,
    justifyContent: 'space-between',
    ...shadow.soft,
  },
  seatTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  seatNumber: { fontFamily: fonts.extrabold, fontSize: 20, color: colors.navy },
  seatCode: { width: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
  seatCodeText: { fontFamily: fonts.bold, fontSize: 12, color: colors.white },
  seatName: { fontFamily: fonts.semibold, fontSize: 11.5, color: colors.text, lineHeight: 15 },
  emptyBoard: {
    fontFamily: fonts.regular,
    fontSize: 13,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 18,
    lineHeight: 19,
  },
  summary: {
    flexDirection: 'row',
    backgroundColor: colors.white,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: 14,
    marginTop: 18,
  },
  summaryItem: { flex: 1, alignItems: 'center' },
  summaryValue: { fontFamily: fonts.extrabold, fontSize: 20 },
  summaryLabel: { fontFamily: fonts.regular, fontSize: 11, color: colors.textSoft },
  saveNote: {
    fontFamily: fonts.medium,
    fontSize: 12,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 10,
  },
  longPressHint: {
    fontFamily: fonts.regular,
    fontSize: 11,
    color: colors.textFaint,
    textAlign: 'center',
    marginTop: 4,
  },
});
