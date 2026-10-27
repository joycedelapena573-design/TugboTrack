/**
 * Add / edit a student. The basic form is name + seat; a separate
 * "Add Student Information" button reveals birthday, age, LRN and
 * guardian details (requirement 4.7).
 */
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';

import { AppButton, Card, Field, PageHeader, Screen, Segmented } from '../../components/ui';
import { ageFromBirthday, formatLongDate, normalizeBirthday } from '../../lib/format';
import { useStore } from '../../lib/store';
import { colors, fonts, radius } from '../../lib/theme';
import type { Gender } from '../../lib/types';

export default function StudentForm() {
  const router = useRouter();
  const params = useLocalSearchParams<{ sectionId?: string; studentId?: string }>();
  const studentId = typeof params.studentId === 'string' ? params.studentId : undefined;
  const sectionIdParam = typeof params.sectionId === 'string' ? params.sectionId : undefined;

  const existing = useStore((s) => (studentId ? s.students[studentId] : undefined));
  const sectionId = existing?.sectionId ?? sectionIdParam ?? '';
  const sections = useStore((s) => s.sections);
  const students = useStore((s) => s.students);
  const addStudent = useStore((s) => s.addStudent);
  const updateStudent = useStore((s) => s.updateStudent);
  const deleteStudent = useStore((s) => s.deleteStudent);

  const section = sections[sectionId];

  const rosterSeats = Object.values(students)
    .filter((s) => s.sectionId === sectionId && s.id !== studentId)
    .map((s) => s.seatNumber);
  const nextSeat = rosterSeats.length ? Math.max(...rosterSeats) + 1 : 1;

  const [fullName, setFullName] = useState(existing?.fullName ?? '');
  const [seat, setSeat] = useState(String(existing?.seatNumber ?? nextSeat));
  const [showInfo, setShowInfo] = useState(Boolean(existing?.lrn || existing?.birthday || existing?.guardianName));
  const [lrn, setLrn] = useState(existing?.lrn ?? '');
  const [gender, setGender] = useState<Gender>(existing?.gender ?? '');
  const [birthday, setBirthday] = useState(existing?.birthday ?? '');
  const [guardianName, setGuardianName] = useState(existing?.guardianName ?? '');
  const [guardianContact, setGuardianContact] = useState(existing?.guardianContact ?? '');
  const [error, setError] = useState('');

  const age = ageFromBirthday(normalizeBirthday(birthday) ?? '');

  const onSave = () => {
    if (!fullName.trim()) {
      setError('Please enter the student’s full name.');
      return;
    }
    const seatNum = /^\d+$/.test(seat.trim()) ? Number(seat.trim()) : nextSeat;
    const payload = {
      sectionId,
      seatNumber: seatNum,
      fullName: fullName.trim(),
      lrn: lrn.trim(),
      gender,
      birthday: normalizeBirthday(birthday) ?? '',
      guardianName: guardianName.trim(),
      guardianContact: guardianContact.trim(),
    };
    if (studentId) updateStudent(studentId, payload);
    else addStudent(payload);
    router.back();
  };

  const onDelete = () => {
    if (!studentId) return;
    Alert.alert('Delete student?', 'This removes the student together with their grades, attendance and BMI records.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          deleteStudent(studentId);
          router.back();
        },
      },
    ]);
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader
        title={studentId ? 'Edit Student' : 'New Student'}
        subtitle={section ? `${section.gradeLevel} — ${section.section}` : undefined}
        onBack={() => router.back()}
      />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <Field
            label="Full Name"
            icon="person"
            placeholder="Last name, First name, M.I."
            value={fullName}
            onChangeText={(t) => {
              setFullName(t);
              setError('');
            }}
            autoCapitalize="words"
          />
          <Field
            label="Seat Number"
            icon="grid"
            placeholder="Seat number in class"
            value={seat}
            onChangeText={setSeat}
            keyboardType="number-pad"
            hint={`Next available seat: ${nextSeat}`}
          />

          {!showInfo ? (
            <Pressable style={styles.addInfoBtn} onPress={() => setShowInfo(true)}>
              <View style={styles.addInfoIcon}>
                <Ionicons name="information-circle" size={20} color={colors.navy} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.addInfoTitle}>Add Student Information</Text>
                <Text style={styles.addInfoSub}>Birthday, age, LRN and guardian details</Text>
              </View>
              <Ionicons name="add-circle" size={24} color={colors.navy} />
            </Pressable>
          ) : (
            <Card style={{ marginBottom: 14 }}>
              <View style={styles.infoHeader}>
                <Text style={styles.infoTitle}>Student Information</Text>
                <Pressable onPress={() => setShowInfo(false)} hitSlop={8}>
                  <Ionicons name="chevron-up" size={20} color={colors.textFaint} />
                </Pressable>
              </View>

              <Text style={styles.label}>Gender</Text>
              <Segmented
                options={[
                  { value: 'Female', label: 'Female' },
                  { value: 'Male', label: 'Male' },
                ]}
                value={gender === 'Male' ? 'Male' : 'Female'}
                onChange={(v) => setGender(v as Gender)}
              />

              <Field
                label="Birthday"
                icon="calendar"
                placeholder="YYYY-MM-DD"
                value={birthday}
                onChangeText={(t) => {
                  setBirthday(t);
                  setError('');
                }}
                keyboardType="numbers-and-punctuation"
                hint={
                  birthday
                    ? normalizeBirthday(birthday)
                      ? `${formatLongDate(normalizeBirthday(birthday)!)}${age !== null ? ` · ${age} years old` : ''}`
                      : 'Use the format YYYY-MM-DD or MM/DD/YYYY.'
                    : 'Used to compute age automatically.'
                }
              />
              <Field
                label="Learners Reference Number (LRN)"
                icon="key"
                placeholder="e.g. 123456789012"
                value={lrn}
                onChangeText={setLrn}
                keyboardType="number-pad"
                maxLength={15}
              />
              <Field
                label="Guardian / Parent Name"
                icon="home"
                placeholder="e.g. Maria Dela Cruz"
                value={guardianName}
                onChangeText={setGuardianName}
                autoCapitalize="words"
              />
              <Field
                label="Guardian Contact Number"
                icon="call"
                placeholder="e.g. 09171234567"
                value={guardianContact}
                onChangeText={setGuardianContact}
                keyboardType="phone-pad"
              />
            </Card>
          )}

          {error ? <Text style={styles.error}>{error}</Text> : null}

          <AppButton label={studentId ? 'Save Changes' : 'Add Student'} icon="checkmark" onPress={onSave} />

          {studentId ? (
            <AppButton label="Delete Student" variant="danger" icon="trash" onPress={onDelete} style={{ marginTop: 12 }} />
          ) : null}
          <View style={{ height: 24 }} />
        </ScrollView>
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 30 },
  addInfoBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    backgroundColor: colors.ice,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderStyle: 'dashed',
    borderRadius: radius.md,
    padding: 14,
  },
  addInfoIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: colors.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  addInfoTitle: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.navyDark },
  addInfoSub: { fontFamily: fonts.regular, fontSize: 12, color: colors.textSoft },
  infoHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  infoTitle: { fontFamily: fonts.bold, fontSize: 15.5, color: colors.navyDark },
  label: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.text, marginBottom: 8, marginLeft: 4 },
  error: { fontFamily: fonts.medium, fontSize: 13.5, color: colors.red, textAlign: 'center', marginBottom: 10 },
});
