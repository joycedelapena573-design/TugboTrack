/**
 * Class detail: roster (search, add, edit, import) + subjects + quick links
 * to attendance, grades, BMI and reports for this class.
 */
import { useMemo, useState } from 'react';
import {
  Alert,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { Card, EmptyState, PageHeader, Screen } from '../../components/ui';
import { initialsOf } from '../../lib/format';
import { pickStudentCsv, toStudentInput } from '../../lib/importer';
import { useStore } from '../../lib/store';
import { colors, fonts, radius, shadow } from '../../lib/theme';
import { DEFAULT_WEIGHTS } from '../../lib/types';

export default function ClassDetail() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const sectionId = typeof id === 'string' ? id : '';

  const section = useStore((s) => s.sections[sectionId]);
  const students = useStore((s) => s.students);
  const subjects = useStore((s) => s.subjects);
  const addStudent = useStore((s) => s.addStudent);
  const bulkAddStudents = useStore((s) => s.bulkAddStudents);
  const setActiveSection = useStore((s) => s.setActiveSection);

  const [query, setQuery] = useState('');

  const roster = useMemo(
    () =>
      Object.values(students)
        .filter((s) => s.sectionId === sectionId)
        .sort((a, b) => a.seatNumber - b.seatNumber),
    [students, sectionId],
  );
  const sectionSubjects = useMemo(
    () =>
      Object.values(subjects)
        .filter((s) => s.sectionId === sectionId)
        .sort((a, b) => a.createdAt - b.createdAt),
    [subjects, sectionId],
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return roster;
    return roster.filter(
      (s) => s.fullName.toLowerCase().includes(q) || s.lrn.toLowerCase().includes(q),
    );
  }, [roster, query]);

  if (!section) {
    return (
      <Screen edges={['top', 'bottom']}>
        <PageHeader title="Class not found" onBack={() => router.back()} />
        <EmptyState icon="alert-circle-outline" title="Missing class" subtitle="This class no longer exists." />
      </Screen>
    );
  }

  const nextSeat = roster.length ? Math.max(...roster.map((s) => s.seatNumber)) + 1 : 1;

  const onAddManually = () => {
    // iOS gets a quick one-line prompt; Android opens the full student form.
    if (Platform.OS === 'ios') {
      Alert.prompt(
        'Add Student',
        'Type the student’s full name',
        [
          { text: 'Cancel', style: 'cancel' },
          {
            text: 'Add',
            onPress: (name?: string) => {
              const trimmed = (name ?? '').trim();
              if (!trimmed) return;
              addStudent({
                sectionId,
                seatNumber: nextSeat,
                fullName: trimmed,
                lrn: '',
                gender: '',
                birthday: '',
                guardianName: '',
                guardianContact: '',
              });
            },
          },
        ],
        'plain-text',
      );
      return;
    }
    router.push({ pathname: '/student/form', params: { sectionId } });
  };

  const onImport = async () => {
    const outcome = await pickStudentCsv();
    if (outcome.status === 'canceled') return;
    if (outcome.status === 'failed') {
      Alert.alert('Import failed', (outcome.errors ?? ['Unknown error.']).join('\n'));
      return;
    }
    const rows = outcome.rows ?? [];
    let seat = nextSeat;
    const inputs = rows.map((row) => {
      const input = toStudentInput(row, sectionId, seat);
      seat = input.seatNumber + 1;
      return input;
    });
    const added = bulkAddStudents(inputs);
    const notes = outcome.errors?.length ? `\n\nNotes:\n${outcome.errors.slice(0, 5).join('\n')}` : '';
    Alert.alert(
      'Students imported',
      `${added} student${added === 1 ? '' : 's'} added from ${outcome.fileName ?? 'the file'}.${notes}`,
    );
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader
        title={`${section.gradeLevel} — ${section.section}`}
        subtitle={`SY ${section.schoolYear} · ${roster.length} students`}
        onBack={() => router.back()}
        right={
          <Pressable
            style={styles.headerBtn}
            onPress={() => router.push({ pathname: '/class/section-form', params: { id: sectionId } })}
          >
            <Ionicons name="create-outline" size={20} color={colors.navy} />
          </Pressable>
        }
      />
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <View style={styles.quickRow}>
          <QuickAction
            icon="calendar"
            label="Attendance"
            onPress={() => {
              setActiveSection(sectionId);
              router.push({ pathname: '/(main)/attendance', params: { sectionId } });
            }}
          />
          <QuickAction
            icon="stats-chart"
            label="Grades"
            onPress={() => {
              setActiveSection(sectionId);
              router.push({ pathname: '/(main)/grades', params: { sectionId } });
            }}
          />
          <QuickAction icon="body" label="BMI" onPress={() => router.push({ pathname: '/bmi', params: { sectionId } })} />
          <QuickAction icon="document-text" label="Reports" onPress={() => router.push({ pathname: '/reports', params: { sectionId } })} />
        </View>

        {/* Subjects */}
        <View style={styles.sectionRow}>
          <Text style={styles.sectionTitle}>Subjects</Text>
          <Pressable style={styles.smallAdd} onPress={() => router.push({ pathname: '/subject/form', params: { sectionId } })}>
            <Ionicons name="add" size={16} color={colors.navy} />
            <Text style={styles.smallAddLabel}>Add</Text>
          </Pressable>
        </View>
        {sectionSubjects.length === 0 ? (
          <Card style={{ marginBottom: 14 }}>
            <Text style={styles.emptyInline}>
              No subjects yet. Add the subjects you teach for this class to start recording grades.
            </Text>
          </Card>
        ) : (
          sectionSubjects.map((sub) => {
            const w = sub.weights ?? DEFAULT_WEIGHTS;
            return (
              <Pressable
                key={sub.id}
                onPress={() =>
                  router.push({
                    pathname: '/(main)/grades',
                    params: { sectionId, subjectId: sub.id },
                  })
                }
              >
                <Card style={styles.subjectCard}>
                  <View style={styles.subjectIcon}>
                    <Ionicons name="book" size={18} color={colors.navy} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.subjectName}>{sub.name}</Text>
                    <Text style={styles.subjectMeta}>
                      WW {w.quizzes + w.assignments + w.activities}% · PT {w.performanceTasks}% · QA{' '}
                      {w.examinations}%
                    </Text>
                  </View>
                  {sub.transmute ? (
                    <View style={styles.tag}>
                      <Text style={styles.tagLabel}>Transmute</Text>
                    </View>
                  ) : null}
                  <Ionicons name="chevron-forward" size={18} color={colors.textFaint} />
                </Card>
              </Pressable>
            );
          })
        )}

        {/* Roster */}
        <View style={styles.sectionRow}>
          <Text style={styles.sectionTitle}>Students</Text>
        </View>
        <View style={styles.searchBox}>
          <Ionicons name="search" size={18} color={colors.textFaint} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search name or LRN"
            placeholderTextColor={colors.textFaint}
            value={query}
            onChangeText={setQuery}
          />
          {query ? (
            <Pressable onPress={() => setQuery('')} hitSlop={8}>
              <Ionicons name="close-circle" size={18} color={colors.textFaint} />
            </Pressable>
          ) : null}
        </View>

        <View style={styles.importRow}>
          <Pressable style={styles.importBtn} onPress={() => router.push({ pathname: '/student/form', params: { sectionId } })}>
            <Ionicons name="person-add" size={16} color={colors.white} />
            <Text style={styles.importBtnLabel}>Add Student</Text>
          </Pressable>
          <Pressable style={[styles.importBtn, styles.importBtnLight]} onPress={() => void onImport()}>
            <Ionicons name="document-attach" size={16} color={colors.navy} />
            <Text style={[styles.importBtnLabel, { color: colors.navy }]}>Import CSV</Text>
          </Pressable>
          <Pressable style={[styles.importBtn, styles.importBtnLight]} onPress={onAddManually}>
            <Ionicons name="create" size={16} color={colors.navy} />
            <Text style={[styles.importBtnLabel, { color: colors.navy }]}>Quick Type</Text>
          </Pressable>
        </View>

        {filtered.length === 0 ? (
          <EmptyState
            icon="people-outline"
            title={roster.length === 0 ? 'No students yet' : 'No matches'}
            subtitle={
              roster.length === 0
                ? 'Add students one by one, or import a CSV list from your file manager.'
                : 'Try a different name or LRN.'
            }
            actionLabel={roster.length === 0 ? 'Add a student' : undefined}
            onAction={
              roster.length === 0
                ? () => router.push({ pathname: '/student/form', params: { sectionId } })
                : undefined
            }
          />
        ) : (
          filtered.map((st) => (
            <Pressable key={st.id} onPress={() => router.push({ pathname: '/student/[id]', params: { id: st.id } })}>
              <Card style={styles.studentRow}>
                <View style={styles.seatBadge}>
                  <Text style={styles.seatLabel}>{st.seatNumber}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.studentName} numberOfLines={1}>
                    {st.fullName}
                  </Text>
                  <Text style={styles.studentMeta} numberOfLines={1}>
                    {st.lrn ? `LRN ${st.lrn}` : 'No LRN yet'}
                  </Text>
                </View>
                <View style={styles.avatar}>
                  <Text style={styles.avatarLabel}>{initialsOf(st.fullName)}</Text>
                </View>
              </Card>
            </Pressable>
          ))
        )}
        <Text style={styles.backupNote}>
          Every change is saved on this device and backed up to CSV automatically.
        </Text>
        <View style={{ height: 24 }} />
      </ScrollView>
    </Screen>
  );
}

function QuickAction({
  icon,
  label,
  onPress,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable style={styles.quickAction} onPress={onPress}>
      <View style={styles.quickIcon}>
        <Ionicons name={icon} size={20} color={colors.navy} />
      </View>
      <Text style={styles.quickLabel}>{label}</Text>
    </Pressable>
  );
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
  quickRow: { flexDirection: 'row', gap: 10, marginBottom: 18 },
  quickAction: {
    flex: 1,
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
    paddingVertical: 12,
    gap: 6,
    ...shadow.soft,
  },
  quickIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  quickLabel: { fontFamily: fonts.semibold, fontSize: 11.5, color: colors.navy },
  sectionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
    marginTop: 4,
  },
  sectionTitle: { fontFamily: fonts.bold, fontSize: 16.5, color: colors.navyDark },
  smallAdd: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    backgroundColor: colors.ice,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: radius.pill,
  },
  smallAddLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.navy },
  subjectCard: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 10, padding: 14 },
  subjectIcon: {
    width: 40,
    height: 40,
    borderRadius: 14,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  subjectName: { fontFamily: fonts.semibold, fontSize: 15, color: colors.navyDark },
  subjectMeta: { fontFamily: fonts.regular, fontSize: 12, color: colors.textSoft, marginTop: 1 },
  tag: { backgroundColor: '#FFF1D6', paddingHorizontal: 8, paddingVertical: 3, borderRadius: radius.pill },
  tagLabel: { fontFamily: fonts.semibold, fontSize: 10.5, color: colors.amber },
  emptyInline: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, lineHeight: 19 },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: 12,
    minHeight: 48,
    marginBottom: 10,
  },
  searchInput: { flex: 1, fontFamily: fonts.medium, fontSize: 14.5, color: colors.text, paddingVertical: 8 },
  importRow: { flexDirection: 'row', gap: 8, marginBottom: 12 },
  importBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: colors.navy,
    paddingHorizontal: 10,
    paddingVertical: 11,
    borderRadius: radius.md,
  },
  importBtnLight: { backgroundColor: colors.ice, borderWidth: 1.5, borderColor: colors.border },
  importBtnLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.white },
  studentRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 10, padding: 12 },
  seatBadge: {
    width: 40,
    height: 40,
    borderRadius: 14,
    backgroundColor: colors.navy,
    alignItems: 'center',
    justifyContent: 'center',
  },
  seatLabel: { fontFamily: fonts.bold, fontSize: 15, color: colors.white },
  studentName: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.navyDark },
  studentMeta: { fontFamily: fonts.regular, fontSize: 12, color: colors.textSoft, marginTop: 1 },
  avatar: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarLabel: { fontFamily: fonts.bold, fontSize: 13, color: colors.navy },
  backupNote: {
    fontFamily: fonts.regular,
    fontSize: 11.5,
    color: colors.textFaint,
    textAlign: 'center',
    marginTop: 10,
  },
});
