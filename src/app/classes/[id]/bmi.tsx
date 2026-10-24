/**
 * BMI record: enter each student's height and weight and the BMI, together with
 * its screening category, is calculated as you type.
 */
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { ClassShell, useClassId } from '@/components/ClassShell';
import { RequireAuth } from '@/components/RequireAuth';
import { Button, Card, Chip, EmptyState, SectionTitle } from '@/components/ui';
import { BMI_NOTE, calculateBmi, categorizeBmi } from '@/lib/bmi';
import { useStore } from '@/lib/store';
import type { Student } from '@/lib/types';
import { colors, radius, spacing, toneColors, type Tone } from '@/theme';

type Drafts = Record<string, { h?: string; w?: string }>;

export default function BmiScreen() {
  const id = useClassId();
  return (
    <RequireAuth>
      <ClassShell id={id} active="bmi">
        <Bmi id={id} />
      </ClassShell>
    </RequireAuth>
  );
}

function Bmi({ id }: { id: string }) {
  const { studentsOf, updateStudent } = useStore();
  const students = studentsOf(id);
  const [drafts, setDrafts] = useState<Drafts>({});

  const text = (student: Student, field: 'h' | 'w') => {
    const stored = field === 'h' ? student.heightCm : student.weightKg;
    const draft = drafts[student.id]?.[field];
    if (draft !== undefined) return draft;
    return stored === null || stored === undefined ? '' : String(stored);
  };

  const update = (student: Student, field: 'h' | 'w', raw: string) => {
    const clean = raw.replace(/[^0-9.]/g, '');
    setDrafts((prev) => ({ ...prev, [student.id]: { ...prev[student.id], [field]: clean } }));

    const parsed = Number.parseFloat(clean);
    const value = clean !== '' && Number.isFinite(parsed) ? parsed : null;
    updateStudent(student.id, field === 'h' ? { heightCm: value } : { weightKg: value });
  };

  const resetAll = () => {
    setDrafts({});
    students.forEach((student) => updateStudent(student.id, { heightCm: null, weightKg: null }));
  };

  const counts: Record<string, number> = {};
  const tones: Record<string, Tone> = {};
  for (const student of students) {
    const category = categorizeBmi(calculateBmi(student.heightCm, student.weightKg));
    if (!category) continue;
    counts[category.label] = (counts[category.label] ?? 0) + 1;
    tones[category.label] = category.tone;
  }
  const summary = Object.entries(counts);

  const recorded = students.filter((s) => s.heightCm !== null && s.weightKg !== null).length;

  if (students.length === 0) {
    return (
      <View style={styles.emptyWrap}>
        <EmptyState
          title="No students yet"
          body="Add students to this class first, then record their height and weight here."
        />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <Card>
        <SectionTitle right={<Chip tone="primary">{recorded}/{students.length}</Chip>}>
          Recorded
        </SectionTitle>
        <Text style={styles.explainer}>{BMI_NOTE}</Text>
        {summary.length > 0 ? (
          <View style={styles.summary}>
            {summary.map(([label, count]) => (
              <Chip key={label} tone={tones[label]}>
                {label}: {count}
              </Chip>
            ))}
          </View>
        ) : null}
        <Button label="Clear all measurements" variant="secondary" onPress={resetAll} />
      </Card>

      <SectionTitle>Height & weight</SectionTitle>

      <View style={styles.list}>
        {students.map((student) => {
          const bmi = calculateBmi(student.heightCm, student.weightKg);
          const category = categorizeBmi(bmi);

          return (
            <Card key={student.id} style={styles.rowCard}>
              <View style={styles.nameRow}>
                <View style={styles.flex}>
                  <Text style={styles.studentName}>{student.name}</Text>
                  <Text style={styles.muted}>Section {student.section || '—'}</Text>
                </View>
                <View
                  style={[
                    styles.bmiBadge,
                    { backgroundColor: category ? toneColors[category.tone].bg : colors.surfaceAlt },
                  ]}
                >
                  <Text
                    style={[
                      styles.bmiValue,
                      { color: category ? toneColors[category.tone].fg : colors.textMuted },
                    ]}
                  >
                    {bmi === null ? '—' : bmi.toFixed(1)}
                  </Text>
                  <Text style={styles.bmiLabel}>BMI</Text>
                </View>
              </View>

              <View style={styles.inputs}>
                <View style={styles.flex}>
                  <Text style={styles.inputLabel}>Height (cm)</Text>
                  <TextInput
                    keyboardType="decimal-pad"
                    value={text(student, 'h')}
                    onChangeText={(value) => update(student, 'h', value)}
                    placeholder="150"
                    placeholderTextColor={colors.textMuted}
                    style={styles.input}
                  />
                </View>
                <View style={styles.flex}>
                  <Text style={styles.inputLabel}>Weight (kg)</Text>
                  <TextInput
                    keyboardType="decimal-pad"
                    value={text(student, 'w')}
                    onChangeText={(value) => update(student, 'w', value)}
                    placeholder="45"
                    placeholderTextColor={colors.textMuted}
                    style={styles.input}
                  />
                </View>
              </View>

              <View style={styles.categoryRow}>
                <Text style={styles.muted}>
                  {category ? category.label : 'Enter height and weight to calculate BMI'}
                </Text>
              </View>
            </Card>
          );
        })}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg, paddingBottom: spacing.xxl },
  emptyWrap: { padding: spacing.lg },
  flex: { flex: 1 },
  explainer: { fontSize: 12, color: colors.textMuted, lineHeight: 18 },
  summary: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  list: { gap: spacing.md },
  rowCard: { gap: spacing.sm },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  studentName: { fontSize: 16, fontWeight: '700', color: colors.text },
  muted: { fontSize: 13, color: colors.textMuted },
  bmiBadge: {
    alignItems: 'center',
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    minWidth: 68,
  },
  bmiValue: { fontSize: 22, fontWeight: '800' },
  bmiLabel: { fontSize: 10, fontWeight: '700', color: colors.textMuted },
  inputs: { flexDirection: 'row', gap: spacing.sm },
  inputLabel: { fontSize: 12, fontWeight: '600', color: colors.textMuted, marginBottom: 4 },
  input: {
    minHeight: 44,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    fontSize: 16,
    color: colors.text,
    backgroundColor: colors.surface,
  },
  categoryRow: {
    borderTopWidth: 1,
    borderTopColor: colors.border,
    paddingTop: spacing.sm,
  },
});