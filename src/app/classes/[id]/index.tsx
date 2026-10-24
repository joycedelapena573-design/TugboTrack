/**
 * Students roster for one class: add students by hand or bulk-import a CSV,
 * and keep name/section on each record.
 */
import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { ClassShell, useClassId } from '@/components/ClassShell';
import { CsvImport } from '@/components/CsvImport';
import { RequireAuth } from '@/components/RequireAuth';
import { Button, Card, Chip, EmptyState, Field, SectionTitle } from '@/components/ui';
import { parseCsv, pick, toTable } from '@/lib/csv';
import { useStore } from '@/lib/store';
import { colors, radius, spacing } from '@/theme';
import { useState } from 'react';

export default function StudentsScreen() {
  const id = useClassId();
  return (
    <RequireAuth>
      <ClassShell id={id} active="students">
        <Students id={id} />
      </ClassShell>
    </RequireAuth>
  );
}

function Students({ id }: { id: string }) {
  const { data, addStudent, importStudents, deleteStudent, studentsOf } = useStore();
  const students = studentsOf(id);
  const cls = data.classes.find((c) => c.id === id);

  const [showForm, setShowForm] = useState(false);
  const [showImport, setShowImport] = useState(false);
  const [name, setName] = useState('');
  const [section, setSection] = useState('');
  const [error, setError] = useState<string | null>(null);

  const defaultSection = cls?.section ?? '';

  const submit = () => {
    if (!name.trim()) {
      setError('Enter the student name.');
      return;
    }
    addStudent(id, name, section.trim() || defaultSection);
    setName('');
    setSection('');
    setError(null);
  };

  const confirmDelete = (studentId: string, studentName: string) => {
    Alert.alert('Delete student?', `Remove "${studentName}" and their recorded scores?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteStudent(studentId) },
    ]);
  };

  return (
    <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
      <View style={styles.actions}>
        <Button
          label={showForm ? 'Close form' : '+ Add student'}
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
          <SectionTitle>New student</SectionTitle>
          <Field
            label="Student name *"
            placeholder="Juan Dela Cruz"
            value={name}
            onChangeText={(text) => {
              setName(text);
              setError(null);
            }}
          />
          <Field
            label="Section"
            placeholder={defaultSection || 'Rose'}
            value={section}
            onChangeText={setSection}
            hint={defaultSection ? `Defaults to "${defaultSection}" when left blank.` : undefined}
          />
          {error ? <Text style={styles.error}>{error}</Text> : null}
          <Button label="Add student" onPress={submit} />
        </Card>
      ) : null}

      {showImport ? (
        <CsvImport
          hint={`Import students into ${cls?.subject ?? 'this class'}. Names are matched by name + section, so existing students are not duplicated.`}
          example={'name,section\nJuan Dela Cruz,Rose\nMaria Santos,Rose'}
          parse={(text) =>
            toTable(parseCsv(text)).records.map((record) => ({
              name: pick(record, ['name', 'student', 'studentname', 'fullname', 'pupil', 'learner', 'col0']),
              section: pick(record, ['section', 'sec', 'grp', 'group', 'col1']),
            }))
          }
          onImport={(rows) => importStudents(id, rows)}
          onCancel={() => setShowImport(false)}
        />
      ) : null}

      <SectionTitle right={<Chip tone="primary">{students.length}</Chip>}>Roster</SectionTitle>

      {students.length === 0 ? (
        <EmptyState
          title="No students yet"
          body="Add learners one at a time, or import your whole list from a CSV file."
        />
      ) : (
        <Card style={styles.roster}>
          {students.map((student, index) => (
            <Pressable
              key={student.id}
              onLongPress={() => confirmDelete(student.id, student.name)}
              style={({ pressed }) => [styles.studentRow, pressed && styles.studentPressed]}
            >
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>{index + 1}</Text>
              </View>
              <View style={styles.flex}>
                <Text style={styles.studentName}>{student.name}</Text>
                <Text style={styles.muted}>Section {student.section || '—'}</Text>
              </View>
            </Pressable>
          ))}
        </Card>
      )}

      <Text style={styles.footnote}>Press and hold a student to delete them.</Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: spacing.lg, gap: spacing.lg, paddingBottom: spacing.xxl },
  actions: { flexDirection: 'row', gap: spacing.sm },
  flex: { flex: 1 },
  error: { fontSize: 13, color: colors.danger, fontWeight: '600' },
  roster: { paddingVertical: spacing.xs, gap: 0 },
  studentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  studentPressed: { opacity: 0.6 },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.surfaceAlt,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { fontSize: 13, fontWeight: '700', color: colors.textMuted },
  studentName: { fontSize: 15, fontWeight: '600', color: colors.text },
  muted: { fontSize: 13, color: colors.textMuted },
  footnote: { fontSize: 12, color: colors.textMuted, textAlign: 'center' },
});