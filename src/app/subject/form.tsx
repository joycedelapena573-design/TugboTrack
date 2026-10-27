/** Add or edit a subject: name, teacher, grading weights, transmutation. */
import { useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { AppButton, Card, Field, PageHeader, Screen } from '../../components/ui';
import { WEIGHT_PRESETS } from '../../lib/grading';
import { useStore } from '../../lib/store';
import { colors, fonts, radius } from '../../lib/theme';
import { COMPONENTS, DEFAULT_WEIGHTS, type Weights } from '../../lib/types';

export default function SubjectForm() {
  const router = useRouter();
  const params = useLocalSearchParams<{ sectionId?: string; subjectId?: string }>();
  const subjectId = typeof params.subjectId === 'string' ? params.subjectId : undefined;

  const existing = useStore((s) => (subjectId ? s.subjects[subjectId] : undefined));
  const sectionId = existing?.sectionId ?? (typeof params.sectionId === 'string' ? params.sectionId : '');
  const section = useStore((s) => s.sections[sectionId]);
  const teacherName = useStore((s) => s.teacherName);
  const addSubject = useStore((s) => s.addSubject);
  const updateSubject = useStore((s) => s.updateSubject);
  const deleteSubject = useStore((s) => s.deleteSubject);

  const [name, setName] = useState(existing?.name ?? '');
  const [weights, setWeights] = useState<Weights>(existing?.weights ?? DEFAULT_WEIGHTS);
  const [transmute, setTransmute] = useState(existing?.transmute ?? false);
  const [error, setError] = useState('');

  const total = COMPONENTS.reduce((sum, c) => sum + (weights[c.key] || 0), 0);

  const onSave = () => {
    if (!name.trim()) {
      setError('Please enter the subject name.');
      return;
    }
    if (total !== 100) {
      setError(`Weights must add up to 100%. Current total: ${total}%.`);
      return;
    }
    if (subjectId) updateSubject(subjectId, { name: name.trim(), weights, transmute });
    else addSubject({ sectionId, name: name.trim(), teacherName, weights, transmute });
    router.back();
  };

  const onDelete = () => {
    if (!subjectId) return;
    Alert.alert(
      'Delete subject?',
      'This removes the subject with all its recorded scores and computed grades.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => {
            deleteSubject(subjectId);
            router.back();
          },
        },
      ],
    );
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader
        title={subjectId ? 'Edit Subject' : 'New Subject'}
        subtitle={section ? `${section.gradeLevel} — ${section.section}` : undefined}
        onBack={() => router.back()}
      />
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <Field
          label="Subject Name"
          icon="book"
          placeholder="e.g. Mathematics"
          value={name}
          onChangeText={(t) => {
            setName(t);
            setError('');
          }}
          autoCapitalize="words"
        />

        <Text style={styles.label}>Grading Weights</Text>
        <View style={styles.presetWrap}>
          {WEIGHT_PRESETS.map((preset) => {
            const active =
              COMPONENTS.every((c) => preset.weights[c.key] === weights[c.key]);
            return (
              <Pressable
                key={preset.label}
                onPress={() => setWeights({ ...preset.weights })}
                style={[styles.presetChip, active && styles.presetChipActive]}
              >
                <Text style={[styles.presetLabel, active && { color: colors.white }]}>{preset.label}</Text>
              </Pressable>
            );
          })}
        </View>

        <Card style={{ marginTop: 12 }}>
          {COMPONENTS.map((c, i) => (
            <View key={c.key} style={[styles.weightRow, i < COMPONENTS.length - 1 && styles.weightBorder]}>
              <Text style={styles.weightLabel}>{c.label}</Text>
              <View style={styles.stepper}>
                <Pressable
                  style={styles.stepBtn}
                  onPress={() => setWeights((w) => ({ ...w, [c.key]: Math.max(0, w[c.key] - 5) }))}
                >
                  <Text style={styles.stepBtnText}>−</Text>
                </Pressable>
                <Text style={styles.weightValue}>{weights[c.key]}%</Text>
                <Pressable
                  style={styles.stepBtn}
                  onPress={() => setWeights((w) => ({ ...w, [c.key]: Math.min(100, w[c.key] + 5) }))}
                >
                  <Text style={styles.stepBtnText}>+</Text>
                </Pressable>
              </View>
            </View>
          ))}
          <View style={[styles.weightRow, { borderTopWidth: 1, borderTopColor: colors.bg, marginTop: 4 }]}>
            <Text style={[styles.weightLabel, { fontFamily: fonts.bold }]}>Total</Text>
            <Text style={[styles.weightValue, { color: total === 100 ? colors.green : colors.red }]}>
              {total}%
            </Text>
          </View>
        </Card>

        <Card style={styles.transmuteCard}>
          <View style={{ flex: 1 }}>
            <Text style={styles.weightLabel}>DepEd Transmutation</Text>
            <Text style={styles.transmuteHint}>
              Convert raw grades using the DO 8, s. 2015 transmutation table (60% mastery → 75).
            </Text>
          </View>
          <Switch
            value={transmute}
            onValueChange={setTransmute}
            trackColor={{ true: colors.navy, false: '#CBD8EE' }}
            thumbColor={colors.white}
          />
        </Card>

        {error ? <Text style={styles.error}>{error}</Text> : null}

        <AppButton label={subjectId ? 'Save Changes' : 'Add Subject'} icon="checkmark" onPress={onSave} style={{ marginTop: 16 }} />
        {subjectId ? (
          <AppButton label="Delete Subject" variant="danger" icon="trash" onPress={onDelete} style={{ marginTop: 12 }} />
        ) : null}
        <View style={{ height: 24 }} />
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 30 },
  label: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.text, marginBottom: 8, marginLeft: 4 },
  presetWrap: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  presetChip: {
    paddingHorizontal: 12,
    paddingVertical: 9,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  presetChipActive: { backgroundColor: colors.navy, borderColor: colors.navy },
  presetLabel: { fontFamily: fonts.semibold, fontSize: 12, color: colors.text },
  weightRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 9 },
  weightBorder: { borderBottomWidth: 1, borderBottomColor: colors.bg },
  weightLabel: { fontFamily: fonts.semibold, fontSize: 14, color: colors.navyDark },
  stepper: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  stepBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepBtnText: { fontFamily: fonts.bold, fontSize: 18, color: colors.navy },
  weightValue: { fontFamily: fonts.bold, fontSize: 14.5, color: colors.navyDark, width: 48, textAlign: 'center' },
  transmuteCard: { flexDirection: 'row', alignItems: 'center', gap: 12, marginTop: 12 },
  transmuteHint: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textSoft, marginTop: 2, lineHeight: 16 },
  error: { fontFamily: fonts.medium, fontSize: 13.5, color: colors.red, textAlign: 'center', marginTop: 12 },
});
