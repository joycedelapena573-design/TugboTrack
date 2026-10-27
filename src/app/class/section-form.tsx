/**
 * Add or edit a class. Senior-high app: only Grade 11 and Grade 12 are
 * offered, the school year opens as a dropdown that defaults to the present
 * year, and subjects are entered together with the class.
 */
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { AppButton, Field, PageHeader, Screen } from '../../components/ui';
import { useStore } from '../../lib/store';
import { colors, fonts, radius, shadow } from '../../lib/theme';
import { currentSchoolYear } from '../../lib/types';

/** This app is intended for senior high students only. */
const GRADE_OPTIONS = ['Grade 11', 'Grade 12'];

export default function SectionForm() {
  const router = useRouter();
  const params = useLocalSearchParams<{ id?: string }>();
  const editingId = typeof params.id === 'string' ? params.id : undefined;

  const existing = useStore((s) => (editingId ? s.sections[editingId] : undefined));
  const addSection = useStore((s) => s.addSection);
  const updateSection = useStore((s) => s.updateSection);
  const deleteSection = useStore((s) => s.deleteSection);
  const addSubject = useStore((s) => s.addSubject);
  const subjects = useStore((s) => s.subjects);
  const teacherName = useStore((s) => s.teacherName);

  const present = currentSchoolYear();
  const [gradeLevel, setGradeLevel] = useState(existing?.gradeLevel ?? 'Grade 12');
  const [section, setSection] = useState(existing?.section ?? '');
  const [schoolYear, setSchoolYear] = useState(existing?.schoolYear ?? present);
  const [yearOpen, setYearOpen] = useState(false);
  const [subjectDraft, setSubjectDraft] = useState('');
  const [pendingSubjects, setPendingSubjects] = useState<string[]>([]);
  const [error, setError] = useState('');

  // Keep a legacy grade/SY visible if an older class is being edited.
  const gradeOptions =
    existing && !GRADE_OPTIONS.includes(existing.gradeLevel)
      ? [existing.gradeLevel, ...GRADE_OPTIONS]
      : GRADE_OPTIONS;

  const yearOptions = useMemo(() => {
    const base = Number(present.slice(0, 4));
    const list = [base + 2, base + 1, base, base - 1, base - 2].map((y) => `${y}-${y + 1}`);
    return existing && !list.includes(existing.schoolYear)
      ? [existing.schoolYear, ...list]
      : list;
  }, [present, existing]);

  const existingSubjects = useMemo(() => {
    if (!editingId) return [];
    return Object.values(subjects)
      .filter((s) => s.sectionId === editingId)
      .sort((a, b) => a.createdAt - b.createdAt);
  }, [subjects, editingId]);

  const addSubjectDraft = () => {
    const name = subjectDraft.trim();
    if (!name) return;
    setPendingSubjects((list) => (list.some((s) => s.toLowerCase() === name.toLowerCase()) ? list : [...list, name]));
    setSubjectDraft('');
  };

  const onSave = () => {
    if (!section.trim()) {
      setError('Please enter a section name (e.g. Sampaguita).');
      return;
    }
    let id = editingId;
    if (editingId) {
      updateSection(editingId, { gradeLevel, section: section.trim(), schoolYear });
    } else {
      id = addSection({ gradeLevel, section: section.trim(), schoolYear }).id;
    }
    if (id) {
      pendingSubjects.forEach((name) => addSubject({ sectionId: id, name, teacherName }));
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
        subtitle="Grade level, section, school year and subjects"
        onBack={() => router.back()}
      />
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <Text style={styles.label}>Grade Level</Text>
        <View style={styles.gradeRow}>
          {gradeOptions.map((g) => {
            const active = gradeLevel === g;
            return (
              <Pressable
                key={g}
                onPress={() => setGradeLevel(g)}
                style={[styles.gradeChip, active && styles.gradeChipActive]}
              >
                <Text style={[styles.gradeChipLabel, active && { color: colors.white }]}>{g}</Text>
              </Pressable>
            );
          })}
        </View>

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
        <Pressable style={styles.yearSelect} onPress={() => setYearOpen((o) => !o)}>
          <View style={styles.yearIcon}>
            <Ionicons name="calendar-outline" size={18} color={colors.navy} />
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.yearValue}>{schoolYear}</Text>
            <Text style={styles.yearHint}>
              {schoolYear === present ? 'Present school year' : 'Selected school year'}
            </Text>
          </View>
          <Ionicons name={yearOpen ? 'chevron-up' : 'chevron-down'} size={20} color={colors.navy} />
        </Pressable>

        {yearOpen ? (
          <View style={styles.yearMenu}>
            {yearOptions.map((y) => {
              const active = schoolYear === y;
              return (
                <Pressable
                  key={y}
                  onPress={() => {
                    setSchoolYear(y);
                    setYearOpen(false);
                  }}
                  style={[styles.yearOption, active && styles.yearOptionActive]}
                >
                  <Text style={[styles.yearOptionLabel, active && { color: colors.white }]}>{y}</Text>
                  {active ? (
                    <Ionicons name="checkmark-circle" size={18} color={colors.white} />
                  ) : y === present ? (
                    <View style={styles.presentPill}>
                      <Text style={styles.presentPillText}>Present</Text>
                    </View>
                  ) : null}
                </Pressable>
              );
            })}
          </View>
        ) : null}

        <Text style={[styles.label, { marginTop: 18 }]}>Subjects</Text>
        <View style={styles.subjectRow}>
          <TextInput
            style={styles.subjectInput}
            placeholder="e.g. General Mathematics"
            placeholderTextColor={colors.textFaint}
            value={subjectDraft}
            onChangeText={setSubjectDraft}
            onSubmitEditing={addSubjectDraft}
            returnKeyType="done"
            autoCapitalize="words"
          />
          <Pressable style={styles.subjectAdd} onPress={addSubjectDraft}>
            <Ionicons name="add" size={22} color={colors.white} />
          </Pressable>
        </View>
        <Text style={styles.subjectHint}>
          Type a subject you teach for this class, then tap +. You can add more later from the grade book.
        </Text>

        {existingSubjects.length + pendingSubjects.length > 0 ? (
          <View style={styles.subjectChips}>
            {existingSubjects.map((s) => (
              <View key={s.id} style={styles.subjectChip}>
                <Ionicons name="book" size={13} color={colors.navy} />
                <Text style={styles.subjectChipLabel}>{s.name}</Text>
              </View>
            ))}
            {pendingSubjects.map((name) => (
              <Pressable
                key={name}
                style={[styles.subjectChip, { backgroundColor: colors.navy, borderColor: colors.navy }]}
                onPress={() => setPendingSubjects((list) => list.filter((s) => s !== name))}
              >
                <Ionicons name="book" size={13} color={colors.white} />
                <Text style={[styles.subjectChipLabel, { color: colors.white }]}>{name}</Text>
                <Ionicons name="close" size={14} color={colors.white} />
              </Pressable>
            ))}
          </View>
        ) : null}

        {error ? <Text style={styles.error}>{error}</Text> : null}

        <AppButton
          label={editingId ? 'Save Changes' : 'Create Class'}
          icon="checkmark"
          onPress={onSave}
          style={{ marginTop: 18 }}
        />

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
  label: {
    fontFamily: fonts.semibold,
    fontSize: 14.5,
    color: colors.text,
    marginBottom: 8,
    marginLeft: 4,
  },
  gradeRow: { flexDirection: 'row', gap: 10, marginBottom: 16 },
  gradeChip: {
    flex: 1,
    paddingVertical: 13,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
    alignItems: 'center',
  },
  gradeChipActive: { backgroundColor: colors.navy, borderColor: colors.navy, ...shadow.soft },
  gradeChipLabel: { fontFamily: fonts.bold, fontSize: 15, color: colors.text },
  yearSelect: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minHeight: 56,
    ...shadow.soft,
  },
  yearIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  yearValue: { fontFamily: fonts.bold, fontSize: 16, color: colors.navyDark },
  yearHint: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textSoft, marginTop: 1 },
  yearMenu: {
    marginTop: 8,
    backgroundColor: colors.white,
    borderRadius: radius.lg,
    borderWidth: 1.5,
    borderColor: colors.border,
    overflow: 'hidden',
    ...shadow.card,
  },
  yearOption: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: colors.bg,
  },
  yearOptionActive: { backgroundColor: colors.navy },
  yearOptionLabel: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.text },
  presentPill: { backgroundColor: colors.ice, paddingHorizontal: 9, paddingVertical: 3, borderRadius: radius.pill },
  presentPillText: { fontFamily: fonts.semibold, fontSize: 10.5, color: colors.navy },
  subjectRow: { flexDirection: 'row', gap: 8, alignItems: 'center' },
  subjectInput: {
    flex: 1,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: 12,
    paddingVertical: 12,
    minHeight: 48,
    fontFamily: fonts.medium,
    fontSize: 14.5,
    color: colors.text,
  },
  subjectAdd: {
    width: 48,
    height: 48,
    borderRadius: radius.md,
    backgroundColor: colors.navy,
    alignItems: 'center',
    justifyContent: 'center',
    ...shadow.soft,
  },
  subjectHint: {
    fontFamily: fonts.regular,
    fontSize: 12,
    color: colors.textFaint,
    marginTop: 6,
    marginLeft: 4,
    lineHeight: 17,
  },
  subjectChips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 10 },
  subjectChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: colors.ice,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  subjectChipLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.navy },
  error: { fontFamily: fonts.medium, fontSize: 13, color: colors.red, marginTop: 12, textAlign: 'center' },
});
