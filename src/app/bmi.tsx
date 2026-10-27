/**
 * BMI monitoring (requirement 5): record height/weight, auto-compute BMI,
 * show the interpretation, and keep values private until revealed.
 */
import { useMemo, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { AppButton, Card, ChipRow, PageHeader, Screen } from '../components/ui';
import { bmiForAgeNote, computeBmi, interpretBmi } from '../lib/bmi';
import { formatShortDate, todayISO } from '../lib/format';
import { useStore } from '../lib/store';
import { colors, fonts, radius, shadow } from '../lib/theme';

export default function BmiScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ sectionId?: string; studentId?: string }>();
  const paramSection = typeof params.sectionId === 'string' ? params.sectionId : undefined;
  const paramStudent = typeof params.studentId === 'string' ? params.studentId : undefined;

  const sections = useStore((s) => s.sections);
  const students = useStore((s) => s.students);
  const bmi = useStore((s) => s.bmi);
  const setBmi = useStore((s) => s.setBmi);
  const deleteBmi = useStore((s) => s.deleteBmi);

  const sectionList = useMemo(() => Object.values(sections).sort((a, b) => a.createdAt - b.createdAt), [sections]);
  const [sectionId, setSectionId] = useState(paramSection ?? sectionList[0]?.id ?? '');
  const section = sections[sectionId] ?? sectionList[0];

  const roster = useMemo(
    () =>
      Object.values(students)
        .filter((s) => s.sectionId === (section?.id ?? ''))
        .sort((a, b) => a.seatNumber - b.seatNumber),
    [students, section],
  );
  const [studentId, setStudentId] = useState(paramStudent ?? roster[0]?.id ?? '');
  const student = students[studentId] ?? roster[0];

  const [revealed, setRevealed] = useState(false);
  const [entryOpen, setEntryOpen] = useState(false);
  const [height, setHeight] = useState('');
  const [weight, setWeight] = useState('');
  const [date, setDate] = useState(todayISO());
  const [error, setError] = useState('');

  const studentRecords = useMemo(
    () =>
      Object.values(bmi)
        .filter((r) => r.studentId === (student?.id ?? ''))
        .sort((a, b) => b.date.localeCompare(a.date)),
    [bmi, student],
  );

  const latest = studentRecords[0];
  const latestBmi = latest ? computeBmi(latest.heightCm, latest.weightKg) : null;
  const interpretation = interpretBmi(latestBmi);

  const onSaveEntry = () => {
    const h = Number(height);
    const w = Number(weight);
    if (!(h > 0) || !(w > 0)) {
      setError('Enter a valid height (cm) and weight (kg).');
      return;
    }
    if (!student) return;
    setBmi(student.id, date, h, w);
    setHeight('');
    setWeight('');
    setError('');
    setEntryOpen(false);
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader
        title="BMI Monitoring"
        subtitle="Height, weight and interpretation"
        onBack={() => router.back()}
        right={
          <Pressable
            style={[styles.revealBtn, revealed && styles.revealBtnOn]}
            onPress={() => setRevealed((v) => !v)}
          >
            <Ionicons
              name={revealed ? 'eye' : 'eye-off'}
              size={18}
              color={revealed ? colors.white : colors.navy}
            />
            <Text style={[styles.revealLabel, revealed && { color: colors.white }]}>
              {revealed ? 'Shown' : 'Hidden'}
            </Text>
          </Pressable>
        }
      />
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        {sectionList.length > 1 ? (
          <ChipRow>
            {sectionList.map((sec) => (
              <Pressable
                key={sec.id}
                onPress={() => setSectionId(sec.id)}
                style={[styles.chip, sec.id === section?.id && styles.chipActive]}
              >
                <Text style={[styles.chipLabel, sec.id === section?.id && { color: colors.white }]}>
                  {sec.gradeLevel.replace('Grade ', 'G')} — {sec.section}
                </Text>
              </Pressable>
            ))}
          </ChipRow>
        ) : null}

        {roster.length === 0 ? (
          <Card style={{ marginTop: 16 }}>
            <Text style={styles.emptyInline}>Add students to this class before recording BMI.</Text>
          </Card>
        ) : (
          <>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
              {roster.map((st) => (
                <Pressable
                  key={st.id}
                  onPress={() => setStudentId(st.id)}
                  style={[styles.chip, st.id === student?.id && styles.chipActive]}
                >
                  <Text style={[styles.chipLabel, st.id === student?.id && { color: colors.white }]}>
                    {st.seatNumber}. {st.fullName.split(' ').slice(-1)[0]}
                  </Text>
                </Pressable>
              ))}
            </ScrollView>

            {student ? (
              <>
                <Card style={styles.resultCard}>
                  <View style={styles.resultTop}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.studentName}>{student.fullName}</Text>
                      <Text style={styles.studentMeta}>Seat {student.seatNumber}</Text>
                    </View>
                    <Pressable style={styles.recordBtn} onPress={() => setEntryOpen(true)}>
                      <Ionicons name="add" size={16} color={colors.white} />
                      <Text style={styles.recordLabel}>Record</Text>
                    </Pressable>
                  </View>

                  {!revealed ? (
                    <View style={styles.privacy}>
                      <Ionicons name="lock-closed" size={18} color={colors.textSoft} />
                      <Text style={styles.privacyText}>
                        BMI values are hidden for privacy. Tap the eye button above to reveal.
                      </Text>
                    </View>
                  ) : latestBmi !== null && interpretation ? (
                    <View style={styles.resultBody}>
                      <View style={[styles.bmiRing, { borderColor: interpretation.color }]}>
                        <Text style={[styles.bmiBig, { color: interpretation.color }]}>{latestBmi.toFixed(1)}</Text>
                        <Text style={styles.bmiRingLabel}>BMI</Text>
                      </View>
                      <View style={{ flex: 1 }}>
                        <View style={[styles.categoryPill, { backgroundColor: interpretation.bg }]}>
                          <Text style={[styles.categoryText, { color: interpretation.color }]}>
                            {interpretation.category}
                          </Text>
                        </View>
                        <Text style={styles.detailText}>
                          {latest?.heightCm} cm · {latest?.weightKg} kg
                        </Text>
                        <Text style={styles.detailText}>{latest ? formatShortDate(latest.date) : ''}</Text>
                      </View>
                    </View>
                  ) : (
                    <Text style={styles.emptyInline}>No BMI recorded for this student yet.</Text>
                  )}

                  <Text style={styles.disclaimer}>{bmiForAgeNote()}</Text>
                </Card>

                <Text style={styles.sectionTitle}>History</Text>
                {studentRecords.length === 0 ? (
                  <Card>
                    <Text style={styles.emptyInline}>No measurements recorded yet.</Text>
                  </Card>
                ) : (
                  studentRecords.map((r) => {
                    const b = computeBmi(r.heightCm, r.weightKg);
                    const interp = interpretBmi(b);
                    return (
                      <Card key={r.id} style={styles.historyRow}>
                        <View style={{ flex: 1 }}>
                          <Text style={styles.historyDate}>{formatShortDate(r.date)}</Text>
                          <Text style={styles.historyDetail}>
                            {revealed
                              ? `${r.heightCm} cm · ${r.weightKg} kg`
                              : '•••• cm · •••• kg'}
                          </Text>
                        </View>
                        {revealed && b !== null && interp ? (
                          <>
                            <Text style={[styles.historyBmi, { color: interp.color }]}>{b.toFixed(1)}</Text>
                            <View style={[styles.historyPill, { backgroundColor: interp.bg }]}>
                              <Text style={[styles.historyPillText, { color: interp.color }]}>
                                {interp.category}
                              </Text>
                            </View>
                          </>
                        ) : (
                          <Ionicons name="eye-off" size={16} color={colors.textFaint} />
                        )}
                        <Pressable hitSlop={8} onPress={() => deleteBmi(r.id)}>
                          <Ionicons name="trash-outline" size={17} color={colors.textFaint} />
                        </Pressable>
                      </Card>
                    );
                  })
                )}
                <View style={{ height: 24 }} />
              </>
            ) : null}
          </>
        )}
      </ScrollView>

      {/* Entry modal */}
      <Modal visible={entryOpen} transparent animationType="fade" onRequestClose={() => setEntryOpen(false)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>Record BMI</Text>
            <Text style={styles.modalSub}>{student?.fullName}</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="Height (cm)"
              placeholderTextColor={colors.textFaint}
              keyboardType="numeric"
              value={height}
              onChangeText={(t) => {
                setHeight(t.replace(/[^0-9.]/g, ''));
                setError('');
              }}
            />
            <TextInput
              style={styles.modalInput}
              placeholder="Weight (kg)"
              placeholderTextColor={colors.textFaint}
              keyboardType="numeric"
              value={weight}
              onChangeText={(t) => {
                setWeight(t.replace(/[^0-9.]/g, ''));
                setError('');
              }}
            />
            <TextInput
              style={styles.modalInput}
              placeholder="Date (YYYY-MM-DD)"
              placeholderTextColor={colors.textFaint}
              value={date}
              onChangeText={setDate}
            />
            {(() => {
              const h = Number(height);
              const w = Number(weight);
              const b = h > 0 && w > 0 ? computeBmi(h, w) : null;
              const interp = interpretBmi(b);
              if (!b || !interp) return null;
              return (
                <View style={styles.preview}>
                  <Text style={styles.previewLabel}>Computed BMI</Text>
                  <Text style={[styles.previewValue, { color: interp.color }]}>{b.toFixed(1)}</Text>
                  <View style={[styles.categoryPill, { backgroundColor: interp.bg }]}>
                    <Text style={[styles.categoryText, { color: interp.color }]}>{interp.category}</Text>
                  </View>
                </View>
              );
            })()}
            {error ? <Text style={styles.error}>{error}</Text> : null}
            <View style={{ flexDirection: 'row', gap: 10 }}>
              <AppButton label="Cancel" variant="ghost" onPress={() => setEntryOpen(false)} style={{ flex: 1 }} />
              <AppButton label="Save" onPress={onSaveEntry} style={{ flex: 1 }} />
            </View>
          </View>
        </View>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingBottom: 24 },
  revealBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
    paddingHorizontal: 11,
    paddingVertical: 8,
    borderRadius: radius.pill,
  },
  revealBtnOn: { backgroundColor: colors.navy, borderColor: colors.navy },
  revealLabel: { fontFamily: fonts.semibold, fontSize: 12, color: colors.navy },
  chipRow: { paddingHorizontal: 16, gap: 8, paddingVertical: 4 },
  chip: {
    paddingHorizontal: 13,
    paddingVertical: 8,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  chipActive: { backgroundColor: colors.navy, borderColor: colors.navy },
  chipLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.text },
  resultCard: { marginTop: 12 },
  resultTop: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  studentName: { fontFamily: fonts.bold, fontSize: 16.5, color: colors.navyDark },
  studentMeta: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft },
  recordBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: colors.navy,
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: radius.pill,
  },
  recordLabel: { fontFamily: fonts.semibold, fontSize: 13, color: colors.white },
  privacy: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.bg,
    borderRadius: radius.md,
    padding: 12,
    marginTop: 14,
  },
  privacyText: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft, flex: 1, lineHeight: 18 },
  resultBody: { flexDirection: 'row', alignItems: 'center', gap: 16, marginTop: 14 },
  bmiRing: {
    width: 92,
    height: 92,
    borderRadius: 46,
    borderWidth: 4,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.bg,
  },
  bmiBig: { fontFamily: fonts.extrabold, fontSize: 28 },
  bmiRingLabel: { fontFamily: fonts.semibold, fontSize: 11, color: colors.textSoft },
  categoryPill: {
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: radius.pill,
  },
  categoryText: { fontFamily: fonts.bold, fontSize: 14 },
  detailText: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft, marginTop: 4 },
  disclaimer: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textFaint, marginTop: 14, lineHeight: 15 },
  sectionTitle: { fontFamily: fonts.bold, fontSize: 16, color: colors.navyDark, marginTop: 18, marginBottom: 10, marginLeft: 4 },
  historyRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 10, padding: 14 },
  historyDate: { fontFamily: fonts.semibold, fontSize: 13.5, color: colors.navyDark },
  historyDetail: { fontFamily: fonts.regular, fontSize: 12, color: colors.textSoft, marginTop: 1 },
  historyBmi: { fontFamily: fonts.extrabold, fontSize: 18 },
  historyPill: { paddingHorizontal: 9, paddingVertical: 4, borderRadius: radius.pill },
  historyPillText: { fontFamily: fonts.semibold, fontSize: 10.5 },
  emptyInline: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, lineHeight: 19, textAlign: 'center' },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(8, 30, 74, 0.45)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  modalCard: {
    width: '100%',
    maxWidth: 400,
    backgroundColor: colors.white,
    borderRadius: radius.lg,
    padding: 18,
    gap: 10,
    ...shadow.card,
  },
  modalTitle: { fontFamily: fonts.bold, fontSize: 17, color: colors.navyDark },
  modalSub: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, marginBottom: 2 },
  modalInput: {
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: 12,
    paddingVertical: 11,
    fontFamily: fonts.medium,
    fontSize: 15,
    color: colors.text,
  },
  preview: {
    alignItems: 'center',
    gap: 6,
    backgroundColor: colors.bg,
    borderRadius: radius.md,
    padding: 12,
  },
  previewLabel: { fontFamily: fonts.medium, fontSize: 11.5, color: colors.textSoft },
  previewValue: { fontFamily: fonts.extrabold, fontSize: 30 },
  error: { fontFamily: fonts.medium, fontSize: 13, color: colors.red, textAlign: 'center' },
});
