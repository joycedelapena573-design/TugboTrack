/**
 * Grade recording: create quizzes, assignments, activities, projects and exams,
 * then score each student. Every assessment belongs to a DepEd component, which
 * is what the grade calculation weights.
 */
import { useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { ClassShell, useClassId } from '@/components/ClassShell';
import { RequireAuth } from '@/components/RequireAuth';
import { Button, Card, Chip, ChoiceChip, EmptyState, Field, SectionTitle } from '@/components/ui';
import { COMPONENT_LABELS, COMPONENT_SHORT } from '@/lib/grades';
import { useStore } from '@/lib/store';
import type { AssessmentType, GradingComponent } from '@/lib/types';
import { colors, radius, spacing } from '@/theme';

const TYPE_OPTIONS: { key: AssessmentType; label: string; component: GradingComponent }[] = [
  { key: 'quiz', label: 'Quiz', component: 'ww' },
  { key: 'assignment', label: 'Assignment', component: 'ww' },
  { key: 'activity', label: 'Activity', component: 'pt' },
  { key: 'project', label: 'Project', component: 'pt' },
  { key: 'exam', label: 'Exam', component: 'qa' },
];

const COMPONENT_OPTIONS: GradingComponent[] = ['ww', 'pt', 'qa'];

const typeLabel = (type: AssessmentType) =>
  TYPE_OPTIONS.find((t) => t.key === type)?.label ?? 'Assessment';

const today = () => new Date().toISOString().slice(0, 10);

export default function AssessmentsScreen() {
  const id = useClassId();
  return (
    <RequireAuth>
      <ClassShell id={id} active="assessments">
        <Assessments id={id} />
      </ClassShell>
    </RequireAuth>
  );
}

function Assessments({ id }: { id: string }) {
  const { studentsOf, assessmentsOf, addAssessment, deleteAssessment, setScore, data } = useStore();
  const students = studentsOf(id);
  const assessments = assessmentsOf(id);
  const cls = data.classes.find((c) => c.id === id);

  const [showForm, setShowForm] = useState(false);
  const [openId, setOpenId] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Record<string, string>>({});

  const [title, setTitle] = useState('');
  const [type, setType] = useState<AssessmentType>('quiz');
  const [component, setComponent] = useState<GradingComponent>('ww');
  const [componentTouched, setComponentTouched] = useState(false);
  const [maxScore, setMaxScore] = useState('20');
  const [date, setDate] = useState(today());
  const [error, setError] = useState<string | null>(null);

  const pickType = (next: AssessmentType) => {
    setType(next);
    if (!componentTouched) {
      setComponent(TYPE_OPTIONS.find((t) => t.key === next)?.component ?? 'ww');
    }
    setError(null);
  };

  const submit = () => {
    const max = Number.parseFloat(maxScore);
    if (!title.trim()) {
      setError('Give the assessment a title, e.g. "Quiz 1".');
      return;
    }
    if (!Number.isFinite(max) || max <= 0) {
      setError('Highest possible score must be greater than 0.');
      return;
    }
    addAssessment(id, { title, type, component, maxScore: max, date: date.trim() });
    setTitle('');
    setType('quiz');
    setComponent('ww');
    setComponentTouched(false);
    setMaxScore('20');
    setDate(today());
    setError(null);
    setShowForm(false);
  };

  const confirmDelete = (assessmentId: string, label: string) => {
    Alert.alert('Delete assessment?', `Remove "${label}" and all scores recorded for it?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteAssessment(assessmentId) },
    ]);
  };

  const onScoreChange = (assessmentId: string, studentId: string, text: string, max: number) => {
    const clean = text.replace(/[^0-9.]/g, '');
    const key = `${assessmentId}:${studentId}`;
    setDrafts((prev) => ({ ...prev, [key]: clean }));
    if (clean === '') {
      setScore(assessmentId, studentId, null);
      return;
    }
    const parsed = Number.parseFloat(clean);
    if (!Number.isFinite(parsed)) return;
    setScore(assessmentId, studentId, Math.max(0, parsed));
    void max;
  };

  const draftFor = (assessmentId: string, studentId: string, stored?: number) => {
    const key = `${assessmentId}:${studentId}`;
    if (key in drafts) return drafts[key];
    return stored === undefined ? '' : String(stored);
  };

  return (
    <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <View style={styles.actions}>
        <Button
          label={showForm ? 'Close form' : '+ Add assessment'}
          onPress={() => {
            setShowForm((v) => !v);
            setError(null);
          }}
          style={styles.flex}
        />
      </View>

      {showForm ? (
        <Card>
          <SectionTitle>Record an assessment</SectionTitle>

          <Field
            label="Title *"
            placeholder="Quiz 1 - Integers"
            value={title}
            onChangeText={(text) => {
              setTitle(text);
              setError(null);
            }}
          />

          <Text style={styles.label}>Type</Text>
          <View style={styles.wrapRow}>
            {TYPE_OPTIONS.map((option) => (
              <ChoiceChip key={option.key} selected={type === option.key} onPress={() => pickType(option.key)}>
                {option.label}
              </ChoiceChip>
            ))}
          </View>

          <Text style={styles.label}>DepEd component</Text>
          <View style={styles.wrapRow}>
            {COMPONENT_OPTIONS.map((option) => (
              <ChoiceChip
                key={option}
                selected={component === option}
                onPress={() => {
                  setComponent(option);
                  setComponentTouched(true);
                }}
              >
                {COMPONENT_SHORT[option]} — {COMPONENT_LABELS[option]}
              </ChoiceChip>
            ))}
          </View>
          <Text style={styles.hint}>
            Weights applied: {cls ? `WW ${cls.weights.ww}% / PT ${cls.weights.pt}% / QA ${cls.weights.qa}%` : ''}
          </Text>

          <View style={styles.rowFields}>
            <View style={styles.flex}>
              <Field
                label="Highest score *"
                keyboardType="decimal-pad"
                value={maxScore}
                onChangeText={setMaxScore}
                placeholder="20"
              />
            </View>
            <View style={styles.flex}>
              <Field label="Date" value={date} onChangeText={setDate} placeholder="YYYY-MM-DD" />
            </View>
          </View>

          {error ? <Text style={styles.error}>{error}</Text> : null}
          <Button label="Save assessment" onPress={submit} />
        </Card>
      ) : null}

      <SectionTitle right={<Chip tone="primary">{assessments.length}</Chip>}>Assessments</SectionTitle>

      {assessments.length === 0 ? (
        <EmptyState
          title="No assessments yet"
          body="Add a quiz, assignment or exam, then score each student. Grades are calculated automatically."
        />
      ) : (
        <View style={styles.list}>
          {assessments.map((assessment) => {
            const scored = students.filter((s) => assessment.scores[s.id] !== undefined).length;
            const isOpen = openId === assessment.id;

            return (
              <Card key={assessment.id}>
                <Pressable
                  onPress={() => setOpenId(isOpen ? null : assessment.id)}
                  onLongPress={() => confirmDelete(assessment.id, assessment.title)}
                  style={styles.assessmentHead}
                >
                  <View style={styles.flex}>
                    <Text style={styles.assessmentTitle}>{assessment.title}</Text>
                    <Text style={styles.muted}>
                      {typeLabel(assessment.type)}
                      {assessment.date ? ` · ${assessment.date}` : ''} · max {assessment.maxScore}
                    </Text>
                  </View>
                  <View style={styles.assessmentChips}>
                    <Chip tone="primary">{COMPONENT_SHORT[assessment.component]}</Chip>
                    <Chip tone={scored === students.length && students.length > 0 ? 'success' : 'neutral'}>
                      {scored}/{students.length}
                    </Chip>
                  </View>
                </Pressable>

                {isOpen ? (
                  students.length === 0 ? (
                    <Text style={styles.hint}>Add students first, then come back to score them.</Text>
                  ) : (
                    <View style={styles.scoreList}>
                      {students.map((student) => {
                        const raw = draftFor(assessment.id, student.id, assessment.scores[student.id]);
                        const parsed = Number.parseFloat(raw);
                        const over = Number.isFinite(parsed) && parsed > assessment.maxScore;
                        return (
                          <View key={student.id} style={styles.scoreRow}>
                            <View style={styles.flex}>
                              <Text style={styles.studentName} numberOfLines={1}>
                                {student.name}
                              </Text>
                              <Text style={[styles.muted, over && styles.warn]}>
                                {over
                                  ? `Over the ${assessment.maxScore}-point maximum`
                                  : `Section ${student.section || '—'}`}
                              </Text>
                            </View>
                            <TextInput
                              keyboardType="decimal-pad"
                              value={raw}
                              onChangeText={(text) =>
                                onScoreChange(assessment.id, student.id, text, assessment.maxScore)
                              }
                              placeholder="/"
                              placeholderTextColor={colors.textMuted}
                              style={[styles.scoreInput, over && styles.scoreInputWarn]}
                            />
                            <Text style={styles.scoreMax}>/ {assessment.maxScore}</Text>
                          </View>
                        );
                      })}
                    </View>
                  )
                ) : null}

                <Text style={styles.hint}>{isOpen ? 'Tap the header to close' : 'Tap to record scores'}</Text>
              </Card>
            );
          })}
        </View>
      )}

      <Text style={styles.footnote}>Press and hold an assessment to delete it.</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg, paddingBottom: spacing.xxl },
  actions: { flexDirection: 'row', gap: spacing.sm },
  flex: { flex: 1 },
  label: { fontSize: 13, fontWeight: '600', color: colors.textMuted, marginBottom: -spacing.xs },
  hint: { fontSize: 12, color: colors.textMuted },
  wrapRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  rowFields: { flexDirection: 'row', gap: spacing.sm },
  error: { fontSize: 13, color: colors.danger, fontWeight: '600' },
  list: { gap: spacing.md },
  assessmentHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  assessmentChips: { flexDirection: 'row', gap: spacing.xs },
  assessmentTitle: { fontSize: 16, fontWeight: '700', color: colors.text },
  muted: { fontSize: 13, color: colors.textMuted },
  warn: { color: colors.danger, fontWeight: '600' },
  studentName: { fontSize: 15, fontWeight: '600', color: colors.text },
  scoreList: { gap: spacing.sm, marginTop: spacing.xs },
  scoreRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.md,
    padding: spacing.sm,
  },
  scoreInput: {
    width: 68,
    minHeight: 40,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.sm,
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.sm,
    fontSize: 16,
    textAlign: 'center',
    color: colors.text,
  },
  scoreInputWarn: { borderColor: colors.danger },
  scoreMax: { fontSize: 13, color: colors.textMuted },
  footnote: { fontSize: 12, color: colors.textMuted, textAlign: 'center' },
});