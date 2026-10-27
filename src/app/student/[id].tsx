/**
 * Learner profile (requirement 4.6): every piece of information associated
 * with the student — personal details, guardian, grades, attendance, BMI.
 */
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { Badge, Card, EmptyState, PageHeader, Screen, Segmented } from '../../components/ui';
import { computeBmi, interpretBmi } from '../../lib/bmi';
import { ageFromBirthday, formatLongDate, formatShortDate, initialsOf } from '../../lib/format';
import { computeQuarterGrade, gradeRemarks } from '../../lib/grading';
import { useStore } from '../../lib/store';
import { ATTENDANCE_META, QUARTERS, type AttendanceStatus, type Quarter } from '../../lib/types';
import { colors, fonts, radius } from '../../lib/theme';

export default function LearnerProfile() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const studentId = typeof id === 'string' ? id : '';

  const student = useStore((s) => s.students[studentId]);
  const section = useStore((s) => (student ? s.sections[student.sectionId] : undefined));
  const subjects = useStore((s) => s.subjects);
  const sheets = useStore((s) => s.sheets);
  const scores = useStore((s) => s.scores);
  const attendance = useStore((s) => s.attendance);
  const bmi = useStore((s) => s.bmi);

  const [quarter, setQuarter] = useState<Quarter>(currentQuarter());

  const subjectList = useMemo(
    () =>
      Object.values(subjects)
        .filter((s) => section && s.sectionId === section.id)
        .sort((a, b) => a.createdAt - b.createdAt),
    [subjects, section],
  );

  const attendanceSummary = useMemo(() => {
    const counts: Record<AttendanceStatus, number> = { present: 0, late: 0, absent: 0, excused: 0 };
    for (const day of Object.values(attendance)) {
      if (section && day.sectionId === section.id) {
        const st = day.statuses[studentId];
        if (st) counts[st] += 1;
      }
    }
    const marked = counts.present + counts.late + counts.absent + counts.excused;
    const rate = marked > 0 ? ((counts.present + counts.late) / marked) * 100 : null;
    return { counts, rate };
  }, [attendance, section, studentId]);

  const bmiRecords = useMemo(
    () =>
      Object.values(bmi)
        .filter((r) => r.studentId === studentId)
        .sort((a, b) => b.date.localeCompare(a.date)),
    [bmi, studentId],
  );
  const latestBmi = bmiRecords[0];
  const latestInterpretation = interpretBmi(
    latestBmi ? computeBmi(latestBmi.heightCm, latestBmi.weightKg) : null,
  );

  if (!student) {
    return (
      <Screen edges={['top', 'bottom']}>
        <PageHeader title="Learner Profile" onBack={() => router.back()} />
        <EmptyState icon="person-outline" title="Student not found" subtitle="This student record no longer exists." />
      </Screen>
    );
  }

  const age = ageFromBirthday(student.birthday);

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader
        title="Learner Profile"
        subtitle={section ? `${section.gradeLevel} — ${section.section}` : undefined}
        onBack={() => router.back()}
        right={
          <Pressable
            style={styles.headerBtn}
            onPress={() => router.push({ pathname: '/student/form', params: { studentId } })}
          >
            <Ionicons name="create-outline" size={20} color={colors.navy} />
          </Pressable>
        }
      />
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <Card style={styles.hero}>
          <View style={styles.avatar}>
            <Text style={styles.avatarLabel}>{initialsOf(student.fullName)}</Text>
          </View>
          <Text style={styles.name} numberOfLines={2}>
            {student.fullName}
          </Text>
          <Text style={styles.meta}>Seat {student.seatNumber}</Text>
          {student.lrn ? <Text style={styles.lrn}>LRN: {student.lrn}</Text> : null}
        </Card>

        <Text style={styles.sectionTitle}>Personal Information</Text>
        <Card>
          <InfoRow icon="calendar" label="Birthday" value={student.birthday ? formatLongDate(student.birthday) : 'Not set'} />
          <InfoRow icon="hourglass" label="Age" value={age !== null ? `${age} years old` : 'Not set'} />
          <InfoRow icon="person" label="Gender" value={student.gender || 'Not set'} />
          <InfoRow icon="key" label="LRN" value={student.lrn || 'Not set'} />
        </Card>

        <Text style={styles.sectionTitle}>Guardian / Parent</Text>
        <Card>
          <InfoRow icon="home" label="Name" value={student.guardianName || 'Not set'} />
          <InfoRow icon="call" label="Contact Number" value={student.guardianContact || 'Not set'} last />
        </Card>

        <Text style={styles.sectionTitle}>Attendance Summary</Text>
        <Card>
          <View style={styles.attRow}>
            {(Object.keys(ATTENDANCE_META) as AttendanceStatus[]).map((status) => (
              <View key={status} style={styles.attItem}>
                <View style={[styles.attDot, { backgroundColor: ATTENDANCE_META[status].bg }]}>
                  <Text style={[styles.attCode, { color: ATTENDANCE_META[status].color }]}>
                    {ATTENDANCE_META[status].code}
                  </Text>
                </View>
                <Text style={styles.attValue}>{attendanceSummary.counts[status]}</Text>
                <Text style={styles.attLabel}>{ATTENDANCE_META[status].label}</Text>
              </View>
            ))}
          </View>
          <View style={styles.rateBox}>
            <Ionicons name="trending-up" size={16} color={colors.green} />
            <Text style={styles.rateText}>
              {attendanceSummary.rate === null
                ? 'No attendance recorded yet.'
                : `Attendance rate: ${attendanceSummary.rate.toFixed(1)}%`}
            </Text>
          </View>
        </Card>

        <Text style={styles.sectionTitle}>Academic Performance</Text>
        <Segmented
          options={QUARTERS.map((q) => ({ value: String(q), label: `Q${q}` }))}
          value={String(quarter)}
          onChange={(v) => setQuarter(Number(v) as Quarter)}
        />
        <View style={{ height: 10 }} />
        {subjectList.length === 0 ? (
          <Card>
            <Text style={styles.emptyInline}>No subjects have been added for this class yet.</Text>
          </Card>
        ) : (
          subjectList.map((sub) => {
            const sheet = sheets[`${sub.id}::q${quarter}`];
            const result = computeQuarterGrade(sub.weights, sub.transmute, sheet, scores, studentId);
            const remarks = gradeRemarks(result.final);
            return (
              <Card key={sub.id} style={styles.gradeCard}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.subjectName}>{sub.name}</Text>
                  <Text style={styles.subjectMeta}>
                    {result.final === null ? 'No scores recorded' : `${result.final.toFixed(2)} · Q${quarter}`}
                  </Text>
                </View>
                {remarks ? <Badge label={remarks} color={colors.green} bg="#DFF5E7" /> : null}
                <Text style={styles.gradeValue}>{result.final === null ? '—' : result.final.toFixed(1)}</Text>
              </Card>
            );
          })
        )}

        <View style={styles.bmiHeaderRow}>
          <Text style={styles.sectionTitle}>BMI Record</Text>
          <Pressable
            style={styles.bmiAdd}
            onPress={() => router.push({ pathname: '/bmi', params: { sectionId: student.sectionId, studentId } })}
          >
            <Ionicons name="add" size={16} color={colors.navy} />
            <Text style={styles.bmiAddLabel}>Record</Text>
          </Pressable>
        </View>
        {latestBmi ? (
          <Card>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
              <View
                style={[
                  styles.bmiCircle,
                  { borderColor: latestInterpretation?.color ?? colors.navy },
                ]}
              >
                <Text style={[styles.bmiValue, { color: latestInterpretation?.color ?? colors.navy }]}>
                  {(computeBmi(latestBmi.heightCm, latestBmi.weightKg) ?? 0).toFixed(1)}
                </Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.subjectName}>
                  {latestInterpretation?.category ?? '—'} · {formatShortDate(latestBmi.date)}
                </Text>
                <Text style={styles.subjectMeta}>
                  {latestBmi.heightCm} cm · {latestBmi.weightKg} kg
                </Text>
                {latestInterpretation ? (
                  <Text style={styles.bmiAdvice}>{latestInterpretation.advice}</Text>
                ) : null}
              </View>
            </View>
            {bmiRecords.length > 1 ? (
              <Text style={styles.historyNote}>{bmiRecords.length} recorded measurements in total.</Text>
            ) : null}
          </Card>
        ) : (
          <Card>
            <Text style={styles.emptyInline}>
              No BMI recorded yet. Track height and weight from the BMI screen.
            </Text>
          </Card>
        )}
        <View style={{ height: 28 }} />
      </ScrollView>
    </Screen>
  );
}

function InfoRow({
  icon,
  label,
  value,
  last,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  value: string;
  last?: boolean;
}) {
  return (
    <View style={[styles.infoRow, !last && styles.infoRowBorder]}>
      <View style={styles.infoIcon}>
        <Ionicons name={icon} size={16} color={colors.navy} />
      </View>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue} numberOfLines={2}>
        {value}
      </Text>
    </View>
  );
}

function currentQuarter(): Quarter {
  const m = new Date().getMonth() + 1; // 1-12
  if (m <= 9) return 1;
  if (m <= 11) return 2;
  if (m === 12) return 3;
  return 1;
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 32 },
  headerBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: { alignItems: 'center', paddingVertical: 22 },
  avatar: {
    width: 76,
    height: 76,
    borderRadius: 38,
    backgroundColor: colors.navy,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 10,
  },
  avatarLabel: { fontFamily: fonts.bold, fontSize: 26, color: colors.white },
  name: { fontFamily: fonts.bold, fontSize: 19, color: colors.navyDark, textAlign: 'center' },
  meta: { fontFamily: fonts.medium, fontSize: 13, color: colors.textSoft, marginTop: 2 },
  lrn: { fontFamily: fonts.medium, fontSize: 12.5, color: colors.blue, marginTop: 4 },
  sectionTitle: {
    fontFamily: fonts.bold,
    fontSize: 16,
    color: colors.navyDark,
    marginTop: 18,
    marginBottom: 10,
    marginLeft: 4,
  },
  infoRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 11 },
  infoRowBorder: { borderBottomWidth: 1, borderBottomColor: colors.bg },
  infoIcon: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  infoLabel: { fontFamily: fonts.medium, fontSize: 13, color: colors.textSoft, width: 110 },
  infoValue: { fontFamily: fonts.semibold, fontSize: 13.5, color: colors.navyDark, flex: 1, textAlign: 'right' },
  attRow: { flexDirection: 'row', justifyContent: 'space-between' },
  attItem: { alignItems: 'center', flex: 1, gap: 4 },
  attDot: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  attCode: { fontFamily: fonts.bold, fontSize: 15 },
  attValue: { fontFamily: fonts.bold, fontSize: 16, color: colors.navyDark },
  attLabel: { fontFamily: fonts.regular, fontSize: 11, color: colors.textSoft },
  rateBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 12,
    backgroundColor: colors.bg,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 8,
    alignSelf: 'flex-start',
  },
  rateText: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.green },
  gradeCard: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 10, padding: 14 },
  subjectName: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.navyDark },
  subjectMeta: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft, marginTop: 1 },
  gradeValue: { fontFamily: fonts.extrabold, fontSize: 20, color: colors.navy },
  emptyInline: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, lineHeight: 19 },
  bmiHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 18,
    marginBottom: 10,
    marginLeft: 4,
  },
  bmiAdd: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    backgroundColor: colors.ice,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: radius.pill,
  },
  bmiAddLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.navy },
  bmiCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    borderWidth: 3,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.bg,
  },
  bmiValue: { fontFamily: fonts.extrabold, fontSize: 20 },
  bmiAdvice: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textSoft, marginTop: 4, lineHeight: 16 },
  historyNote: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textFaint, marginTop: 10 },
});
