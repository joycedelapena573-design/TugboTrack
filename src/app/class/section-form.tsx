/** Add or edit a class (grade level, section, school year). */
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { AppButton, Card, Field, PageHeader, Screen, Segmented } from '../../components/ui';
import { useStore } from '../../lib/store';
import { colors, fonts } from '../../lib/theme';
import { currentSchoolYear, GRADE_LEVELS } from '../../lib/types';

export default function SectionForm() {
  const router = useRouter();
  const params = useLocalSearchParams<{ id?: string }>();
  const editingId = typeof params.id === 'string' ? params.id : undefined;

  const existing = useStore((s) => (editingId ? s.sections[editingId] : undefined));
  const addSection = useStore((s) => s.addSection);
  const updateSection = useStore((s) => s.updateSection);
  const deleteSection = useStore((s) => s.deleteSection);

  const [gradeLevel, setGradeLevel] = useState(existing?.gradeLevel ?? GRADE_LEVELS[0]);
  const [section, setSection] = useState(existing?.section ?? '');
  const [schoolYear, setSchoolYear] = useState(existing?.schoolYear ?? currentSchoolYear());
  const [error, setError] = useState('');

  const years = useMemo(() => {
    const base = Number((schoolYear || currentSchoolYear()).slice(0, 4));
    return [base - 1, base, base + 1].map((y) => `${y}-${y + 1}`);
  }, [schoolYear]);

  const onSave = () => {
    if (!section.trim()) {
      setError('Please enter a section name (e.g. Sampaguita).');
      return;
    }
    if (editingId) {
      updateSection(editingId, { gradeLevel, section: section.trim(), schoolYear });
    } else {
      addSection({ gradeLevel, section: section.trim(), schoolYear });
    }
    router.back();
  };

  const onDelete = () => {
    if (!editingId) return;
    deleteSection(editingId);
    router.dismissAll?.();
    router.replace('/(main)');
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader
        title={editingId ? 'Edit Class' : 'New Class'}
        subtitle="Organize records by grade, section and school year"
        onBack={() => router.back()}
      />
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <Card>
          <Segmented
            options={GRADE_LEVELS.slice(0, 10).map((g) => ({ value: g, label: g.replace('Grade ', 'G') }))}
            value={gradeLevel}
            onChange={setGradeLevel}
          />
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginTop: 10 }}>
            <View style={{ flexDirection: 'row', gap: 8 }}>
              {GRADE_LEVELS.slice(10).map((g) => (
                <Pressable
                  key={g}
                  onPress={() => setGradeLevel(g)}
                  style={[styles.yearChip, gradeLevel === g && styles.yearChipActive]}
                >
                  <Text style={[styles.yearChipLabel, gradeLevel === g && { color: colors.white }]}>{g}</Text>
                </Pressable>
              ))}
            </View>
          </ScrollView>
        </Card>

        <Field
          label="Section Name"
          icon="people"
          placeholder="e.g. Sampaguita"
          value={section}
          onChangeText={(t) => {
            setSection(t);
            setError('');
          }}
          autoCapitalize="words"
        />

        <Text style={styles.label}>School Year</Text>
        <View style={styles.yearRow}>
          {years.map((y) => (
            <Pressable
              key={y}
              onPress={() => setSchoolYear(y)}
              style={[styles.yearChip, schoolYear === y && styles.yearChipActive, { flex: 1 }]}
            >
              <Text style={[styles.yearChipLabel, schoolYear === y && { color: colors.white }]}>{y}</Text>
            </Pressable>
          ))}
        </View>

        {error ? <Text style={styles.error}>{error}</Text> : null}

        <AppButton label={editingId ? 'Save Changes' : 'Create Class'} icon="checkmark" onPress={onSave} style={{ marginTop: 18 }} />

        {editingId ? (
          <AppButton label="Delete Class" variant="danger" icon="trash" onPress={onDelete} style={{ marginTop: 12 }} />
        ) : null}
        <View style={{ height: 20 }} />
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 30 },
  label: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.text, marginBottom: 8, marginLeft: 4 },
  yearRow: { flexDirection: 'row', gap: 8 },
  yearChip: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 999,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
    alignItems: 'center',
  },
  yearChipActive: { backgroundColor: colors.navy, borderColor: colors.navy },
  yearChipLabel: { fontFamily: fonts.semibold, fontSize: 13, color: colors.text },
  error: { fontFamily: fonts.medium, fontSize: 13, color: colors.red, marginTop: 12, textAlign: 'center' },
});
