/**
 * Auto-calculated quarterly grades: each student's Written Works, Performance
 * Tasks and Quarterly Assessment percentages are weighted, summed into an
 * initial grade, then transmuted to the DepEd report-card grade (pass = 75).
 */
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { ClassShell, useClassId } from '@/components/ClassShell';
import { RequireAuth } from '@/components/RequireAuth';
import { Button, Card, Chip, ChoiceChip, EmptyState, Field, SectionTitle } from '@/components/ui';
import {
  COMPONENT_LABELS,
  COMPONENT_SHORT,
  WEIGHT_PRESETS,
  computeGrade,
  presetByKey,
  weightTotal,
} from '@/lib/grades';
import { useStore } from '@/lib/store';
import type { GradingComponent, Weights } from '@/lib/types';
import { colors, radius, spacing } from '@/theme';

const COMPONENT_ORDER: GradingComponent[] = ['ww', 'pt', 'qa'];

export default function GradesScreen() {
  const id = useClassId();
  return (
    <RequireAuth>
      <ClassShell id={id} active="grades">
        <Grades id={id} />
      </ClassShell>
    </RequireAuth>
  );
}

function Grades({ id }: { id: string }) {
  const { data, studentsOf, assessmentsOf, updateClass } = useStore();
  const cls = data.classes.find((c) => c.id === id);
  const students = studentsOf(id);
  const assessments = assessmentsOf(id);

  const [editing, setEditing] = useState(false);
  const [presetKey, setPresetKey] = useState(cls?.presetKey ?? 'math_science');
  const [weights, setWeights] = useState<Weights>(cls?.weights ?? { ww: 40, pt: 40, qa: 20 });
  const [error, setError] = useState<string | null>(null);

  if (!cls) return null;

  const scoredCount = assessments.filter((a) => Object.keys(a.scores).length > 0).length;

  const choosePreset = (key: string) => {
    setPresetKey(key);
    if (key !== 'custom') setWeights(presetByKey(key).weights);
    setError(null);
  };

  const saveWeights = () => {
    if (weightTotal(weights) !== 100) {
      setError(`Weights must add up to 100% (currently ${weightTotal(weights)}%).`);
      return;
    }
    updateClass(id, { weights, presetKey });
    setError(null);
    setEditing(false);
  };

  const openEditor = () => {
    setPresetKey(cls.presetKey);
    setWeights(cls.weights);
    setError(null);
    setEditing(true);
  };

  return (
    <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <Card>
        <SectionTitle
          right={
            <Button
              label={editing ? 'Cancel' : 'Adjust weights'}
              variant="ghost"
              onPress={() => (editing ? setEditing(false) : openEditor())}
            />
          }
        >
          Grading weights
        </SectionTitle>

        {editing ? (
          <View>
            <View style={styles.wrapRow}>
              {WEIGHT_PRESETS.map((preset) => (
                <ChoiceChip
                  key={preset.key}
                  selected={presetKey === preset.key}
                  onPress={() => choosePreset(preset.key)}
                >
                  {preset.label}
                </ChoiceChip>
              ))}
            </View>
            <View style={styles.weightRow}>
              {COMPONENT_ORDER.map((key) => (
                <View key={key} style={styles.flex}>
                  <Field
                    label={COMPONENT_SHORT[key]}
                    keyboardType="number-pad"
                    value={String(weights[key])}
                    onChangeText={(text) => {
                      const parsed = Number.parseInt(text.replace(/[^0-9]/g, ''), 10);
                      setPresetKey('custom');
                      setWeights((prev) => ({ ...prev, [key]: Number.isFinite(parsed) ? parsed : 0 }));
                      setError(null);
                    }}
                  />
                </View>
              ))}
            </View>
            {error ? <Text style={styles.error}>{error}</Text> : null}
            <Button label="Apply weights" onPress={saveWeights} />
          </View>
        ) : (
          <View style={styles.wrapRow}>
            {COMPONENT_ORDER.map((key) => (
              <Chip key={key} tone="primary">
                {COMPONENT_LABELS[key]} {cls.weights[key]}%
              </Chip>
            ))}
          </View>
        )}
      </Card>

      <SectionTitle right={<Chip tone="primary">{students.length}</Chip>}>
        Quarterly grades
      </SectionTitle>

      <Text style={styles.explainer}>
        Each component score = points earned / points possible. Weighted scores are added into the
        initial grade, which is transmuted once using the DepEd table (passing grade 75).
      </Text>

      {students.length === 0 ? (
        <EmptyState
          title="No students to grade"
          body="Add students to this class first, then record quizzes, assignments and exams."
        />
      ) : assessments.length === 0 ? (
        <EmptyState
          title="No assessments yet"
          body="Create a quiz, assignment or exam on the Grading tab before grades can be computed."
        />
      ) : (
        <View style={styles.list}>
          {students.map((student) => {
            const result = computeGrade(assessments, cls.weights, student.id);
            const studentScored = assessments.filter(
              (a) => a.scores[student.id] !== undefined,
            ).length;

            return (
              <Card key={student.id}>
                <View style={styles.gradeHead}>
                  <View style={styles.flex}>
                    <Text style={styles.studentName}>{student.name}</Text>
                    <Text style={styles.muted}>Section {student.section || '—'}</Text>
                  </View>
                  <View style={styles.gradeBadge}>
                    <Text style={styles.gradeValue}>
                      {result.final === null ? '—' : result.final}
                    </Text>
                    <Text style={styles.gradeLabel}>final grade</Text>
                  </View>
                </View>

                <View style={styles.breakdown}>
                  {result.components.length === 0 ? (
                    <Text style={styles.muted}>No scored work recorded yet.</Text>
                  ) : (
                    COMPONENT_ORDER.map((key) => {
                      const entry = result.components.find((c) => c.component === key);
                      if (!entry || entry.percentage === null) return null;
                      return (
                        <View key={key} style={styles.breakdownRow}>
                          <Text style={styles.breakdownLabel}>
                            {COMPONENT_LABELS[key]} ({entry.appliedWeight.toFixed(0)}%)
                          </Text>
                          <Text style={styles.breakdownValue}>{entry.percentage.toFixed(1)}%</Text>
                        </View>
                      );
                    })
                  )}
                </View>

                {result.initial !== null ? (
                  <View style={styles.footer}>
                    <Text style={styles.muted}>Initial grade {result.initial.toFixed(1)}</Text>
                    <Chip tone={result.final !== null && result.final >= 75 ? 'success' : 'danger'}>
                      {result.remark}
                    </Chip>
                  </View>
                ) : null}

                <Text style={styles.muted}>
                  Scored {studentScored} of {assessments.length} assessment
                  {assessments.length === 1 ? '' : 's'}
                  {scoredCount === 0 ? ' — record scores on the Grading tab' : ''}
                </Text>
              </Card>
            );
          })}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg, paddingBottom: spacing.xxl },
  flex: { flex: 1 },
  wrapRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  weightRow: { flexDirection: 'row', gap: spacing.sm },
  error: { fontSize: 13, color: colors.danger, fontWeight: '600' },
  explainer: { fontSize: 12, color: colors.textMuted, lineHeight: 18 },
  list: { gap: spacing.md },
  gradeHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  studentName: { fontSize: 16, fontWeight: '700', color: colors.text },
  muted: { fontSize: 13, color: colors.textMuted },
  gradeBadge: {
    alignItems: 'center',
    backgroundColor: colors.primarySoft,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    minWidth: 76,
  },
  gradeValue: { fontSize: 26, fontWeight: '800', color: colors.primary },
  gradeLabel: { fontSize: 10, color: colors.primary, fontWeight: '700' },
  breakdown: { gap: 6, borderTopWidth: 1, borderTopColor: colors.border, paddingTop: spacing.sm },
  breakdownRow: { flexDirection: 'row', justifyContent: 'space-between', gap: spacing.sm },
  breakdownLabel: { fontSize: 13, color: colors.textMuted, flexShrink: 1 },
  breakdownValue: { fontSize: 13, fontWeight: '700', color: colors.text },
  footer: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm },
});