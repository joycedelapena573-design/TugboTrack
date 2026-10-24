/**
 * Dashboard: overview of every class, the add-class form and CSV import for a
 * ready-made class list.
 */
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { CsvImport } from '@/components/CsvImport';
import { RequireAuth } from '@/components/RequireAuth';
import { Button, Card, ChoiceChip, Chip, EmptyState, Field, SectionTitle } from '@/components/ui';
import { presetByKey, WEIGHT_PRESETS, weightTotal } from '@/lib/grades';
import { parseCsv, pick, toTable } from '@/lib/csv';
import { useStore } from '@/lib/store';
import type { Weights } from '@/lib/types';
import { colors, radius, spacing } from '@/theme';

const currentSchoolYear = () => {
  const year = new Date().getFullYear();
  return `${year}-${(year + 1) % 100}`;
};

export default function Dashboard() {
  return (
    <RequireAuth>
      <DashboardScreen />
    </RequireAuth>
  );
}

function DashboardScreen() {
  const { data, addClass, importClasses, deleteClass, studentsOf, assessmentsOf } = useStore();

  const [showForm, setShowForm] = useState(false);
  const [showImport, setShowImport] = useState(false);

  const [subject, setSubject] = useState('');
  const [section, setSection] = useState('');
  const [gradeLevel, setGradeLevel] = useState('');
  const [schoolYear, setSchoolYear] = useState(currentSchoolYear());
  const [presetKey, setPresetKey] = useState('math_science');
  const [weights, setWeights] = useState<Weights>(presetByKey('math_science').weights);
  const [error, setError] = useState<string | null>(null);

  const totals = useMemo(
    () => ({
      classes: data.classes.length,
      students: data.students.length,
      assessments: data.assessments.length,
    }),
    [data.classes.length, data.students.length, data.assessments.length],
  );

  const choosePreset = (key: string) => {
    setPresetKey(key);
    if (key !== 'custom') setWeights(presetByKey(key).weights);
  };

  const resetForm = () => {
    setSubject('');
    setSection('');
    setGradeLevel('');
    setSchoolYear(currentSchoolYear());
    setPresetKey('math_science');
    setWeights(presetByKey('math_science').weights);
    setError(null);
  };

  const submit = () => {
    if (!subject.trim()) {
      setError('Enter a subject or learning area.');
      return;
    }
    if (weightTotal(weights) !== 100) {
      setError(`Weights must add up to 100% (currently ${weightTotal(weights)}%).`);
      return;
    }
    addClass({ subject, section, gradeLevel, schoolYear, presetKey, weights });
    resetForm();
    setShowForm(false);
  };

  const confirmDelete = (id: string, name: string) => {
    Alert.alert('Delete class?', `This removes "${name}" with its students and assessments.`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteClass(id) },
    ]);
  };

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.stats}>
          <Stat label="Classes" value={totals.classes} />
          <Stat label="Students" value={totals.students} />
          <Stat label="Assessments" value={totals.assessments} />
        </View>

        <View style={styles.actions}>
          <Button
            label={showForm ? 'Close form' : '+ Add class'}
            onPress={() => {
              setShowForm((v) => !v);
              setShowImport(false);
              setError(null);
            }}
            style={styles.flex}
          />
          <Button
            label="Import CSV"
            variant="secondary"
            onPress={() => {
              setShowImport((v) => !v);
              setShowForm(false);
            }}
            style={styles.flex}
          />
        </View>

        {showForm ? (
          <Card>
            <SectionTitle>New class</SectionTitle>
            <Field
              label="Subject / learning area *"
              placeholder="Mathematics 8"
              value={subject}
              onChangeText={setSubject}
            />
            <Field
              label="Section"
              placeholder="Rose"
              value={section}
              onChangeText={setSection}
            />
            <Field
              label="Grade level"
              placeholder="Grade 8"
              value={gradeLevel}
              onChangeText={setGradeLevel}
            />
            <Field
              label="School year"
              placeholder="2026-27"
              value={schoolYear}
              onChangeText={setSchoolYear}
            />

            <Text style={styles.label}>Grading weights</Text>
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
            <Text style={styles.muted}>
              {presetByKey(presetKey).label} — WW {weights.ww}% / PT {weights.pt}% / QA {weights.qa}%
            </Text>

            <View style={styles.weightRow}>
              {(['ww', 'pt', 'qa'] as const).map((key) => (
                <View key={key} style={styles.flex}>
                  <Field
                    label={key.toUpperCase()}
                    keyboardType="number-pad"
                    value={String(weights[key])}
                    onChangeText={(text) => {
                      const parsed = Number.parseInt(text.replace(/[^0-9]/g, ''), 10);
                      setPresetKey('custom');
                      setWeights((prev) => ({ ...prev, [key]: Number.isFinite(parsed) ? parsed : 0 }));
                    }}
                  />
                </View>
              ))}
            </View>

            {error ? <Text style={styles.error}>{error}</Text> : null}
            <Button label="Save class" onPress={submit} />
          </Card>
        ) : null}

        {showImport ? (
          <CsvImport
            hint="Import your list of classes. One class per row."
            example={'subject,section,gradelevel\nMathematics 8,Rose,Grade 8'}
            parse={(text) =>
              toTable(parseCsv(text)).records.map((record) => ({
                subject: pick(record, ['subject', 'class', 'learningarea', 'course', 'col0']),
                section: pick(record, ['section', 'sec', 'grp', 'group', 'col1']),
                gradeLevel: pick(record, ['gradelevel', 'grade', 'level', 'col2']),
              }))
            }
            onImport={(rows) => importClasses(rows)}
            onCancel={() => setShowImport(false)}
          />
        ) : null}

        <SectionTitle>My classes</SectionTitle>

        {data.classes.length === 0 ? (
          <EmptyState
            title="No classes yet"
            body="Add your first class, or import a list you already have, to start recording students and grades."
          />
        ) : (
          <View style={styles.list}>
            {data.classes.map((cls) => (
              <Pressable
                key={cls.id}
                onPress={() => router.push(`/classes/${cls.id}`)}
                onLongPress={() => confirmDelete(cls.id, cls.subject)}
                style={({ pressed }) => [styles.classCard, pressed && styles.classCardPressed]}
              >
                <View style={styles.classHeader}>
                  <Text style={styles.classSubject}>{cls.subject}</Text>
                  <Chip tone="neutral">{cls.section || 'No section'}</Chip>
                </View>
                <Text style={styles.muted}>
                  {[cls.gradeLevel, cls.schoolYear].filter(Boolean).join(' · ') || 'No details yet'}
                </Text>
                <View style={styles.wrapRow}>
                  <Chip tone="primary">{studentsOf(cls.id).length} students</Chip>
                  <Chip tone="neutral">{assessmentsOf(cls.id).length} assessments</Chip>
                  <Chip tone="neutral">
                    WW {cls.weights.ww} / PT {cls.weights.pt} / QA {cls.weights.qa}
                  </Chip>
                </View>
              </Pressable>
            ))}
          </View>
        )}

        <Text style={styles.footnote}>Press and hold a class to delete it.</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.bg },
  content: { padding: spacing.lg, gap: spacing.lg, paddingBottom: spacing.xxl },
  stats: { flexDirection: 'row', gap: spacing.sm },
  stat: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    alignItems: 'center',
    gap: 2,
  },
  statValue: { fontSize: 22, fontWeight: '800', color: colors.primary },
  statLabel: { fontSize: 12, color: colors.textMuted },
  actions: { flexDirection: 'row', gap: spacing.sm },
  flex: { flex: 1 },
  label: { fontSize: 13, fontWeight: '600', color: colors.textMuted },
  wrapRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  weightRow: { flexDirection: 'row', gap: spacing.sm },
  error: { fontSize: 13, color: colors.danger, fontWeight: '600' },
  list: { gap: spacing.md },
  classCard: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.lg,
    gap: spacing.sm,
  },
  classCardPressed: { backgroundColor: colors.surfaceAlt },
  classHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm },
  classSubject: { fontSize: 17, fontWeight: '700', color: colors.text, flexShrink: 1 },
  muted: { fontSize: 13, color: colors.textMuted },
  footnote: { fontSize: 12, color: colors.textMuted, textAlign: 'center' },
});