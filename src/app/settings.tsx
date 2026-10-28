/**
 * Settings: teacher profile, change MPIN (requirement 6.3), backup status,
 * and app information.
 */
import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, View } from 'react-native';
import { File, Paths } from 'expo-file-system';
import * as ImagePicker from 'expo-image-picker';
import { useRouter } from 'expo-router';

import { SchoolLogo } from '../components/SchoolLogo';
import { AppButton, Card, Field, PageHeader, Screen, SecureField } from '../components/ui';
import { autoBackupDirPath } from '../lib/backup';
import { MPIN_LENGTH, changeMpin, isValidMpin } from '../lib/mpin';
import { useStore } from '../lib/store';
import { colors, fonts } from '../lib/theme';

export default function Settings() {
  const router = useRouter();
  const teacherName = useStore((s) => s.teacherName);
  const setTeacherName = useStore((s) => s.setTeacherName);
  const students = useStore((s) => s.students);
  const schoolLogoUri = useStore((s) => s.schoolLogoUri);
  const setSchoolLogo = useStore((s) => s.setSchoolLogo);

  const [name, setName] = useState(teacherName);
  const [pickingLogo, setPickingLogo] = useState(false);
  const [logoMessage, setLogoMessage] = useState('');
  const [oldPin, setOldPin] = useState('');
  const [newPin, setNewPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [message, setMessage] = useState('');
  const [saving, setSaving] = useState(false);

  const onSaveName = () => {
    if (!name.trim()) {
      setMessage('Please enter your name.');
      return;
    }
    setTeacherName(name);
    setMessage('Teacher name saved.');
  };

  /** Let the teacher insert the actual school logo picture from their gallery. */
  const onPickLogo = async () => {
    setLogoMessage('');
    try {
      setPickingLogo(true);
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        Alert.alert('Photo access needed', 'Allow photo access so you can choose your school logo.');
        return;
      }
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.85,
      });
      if (result.canceled || !result.assets?.[0]) return;
      const asset = result.assets[0];
      const ext = (asset.fileName ?? asset.uri).match(/\.[A-Za-z0-9]+$/)?.[0] ?? '.jpg';
      // Copy out of the picker's cache so the logo survives restarts.
      const dest = new File(Paths.document, `school-logo${ext}`);
      if (dest.exists) await dest.delete();
      await new File(asset.uri).copy(dest);
      setSchoolLogo(dest.uri);
      setLogoMessage('School logo updated — it now appears on the loading and MPIN screens.');
    } catch {
      Alert.alert('Could not use that picture', 'Please try choosing a different image.');
    } finally {
      setPickingLogo(false);
    }
  };

  const onChangeMpin = async () => {
    setMessage('');
    if (!isValidMpin(oldPin)) {
      setMessage(`Enter your current ${MPIN_LENGTH}-digit MPIN.`);
      return;
    }
    if (!isValidMpin(newPin)) {
      setMessage(`The new MPIN must be exactly ${MPIN_LENGTH} numbers.`);
      return;
    }
    if (newPin !== confirmPin) {
      setMessage('The new MPINs do not match.');
      return;
    }
    if (newPin === oldPin) {
      setMessage('The new MPIN must be different from the current one.');
      return;
    }
    setSaving(true);
    try {
      const result = await changeMpin(oldPin, newPin);
      if (result.ok) {
        setOldPin('');
        setNewPin('');
        setConfirmPin('');
        Alert.alert('MPIN changed', 'Your new MPIN is required the next time you open the app.');
      } else if (result.reason === 'locked') {
        setMessage('Too many failed attempts. Please wait and try again.');
      } else {
        setMessage('Your current MPIN is incorrect.');
      }
    } catch {
      setMessage('Could not change the MPIN. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader title="Settings" subtitle="Profile, security and backups" onBack={() => router.back()} />
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
          <Text style={styles.sectionTitle}>Teacher Profile</Text>
          <Card>
            <Field
              label="Your Name"
              icon="person"
              placeholder="Enter your full name"
              value={name}
              onChangeText={setName}
              autoCapitalize="words"
            />
            <AppButton label="Save Name" variant="secondary" icon="checkmark" onPress={onSaveName} />
          </Card>

          <Text style={styles.sectionTitle}>School Logo</Text>
          <Card>
            <View style={styles.logoRow}>
              <SchoolLogo size={76} style={styles.logoPreview} />
              <View style={styles.logoInfo}>
                <Text style={styles.storageLabel}>
                  Shown on the loading screen and both MPIN screens.
                </Text>
                <Text style={styles.logoHint}>
                  {schoolLogoUri ? 'Your own picture is in use' : 'Using the default school seal'}
                </Text>
              </View>
            </View>
            {logoMessage ? <Text style={styles.logoMessage}>{logoMessage}</Text> : null}
            <AppButton
              label="Insert School Logo"
              variant="secondary"
              icon="image"
              onPress={() => void onPickLogo()}
              loading={pickingLogo}
            />
            {schoolLogoUri ? (
              <AppButton
                label="Use Default Logo"
                variant="ghost"
                icon="refresh"
                onPress={() => setSchoolLogo(null)}
                style={{ marginTop: 10 }}
              />
            ) : null}
          </Card>

          <Text style={styles.sectionTitle}>Change MPIN</Text>
          <Card>
            <SecureField
              label={`Current ${MPIN_LENGTH}-digit MPIN`}
              icon="lock-closed"
              placeholder="Enter current MPIN"
              value={oldPin}
              onChangeText={(t) => setOldPin(t.replace(/\D/g, ''))}
            />
            <SecureField
              label="New MPIN"
              icon="key"
              placeholder={`Enter ${MPIN_LENGTH} new numbers`}
              value={newPin}
              onChangeText={(t) => setNewPin(t.replace(/\D/g, ''))}
            />
            <SecureField
              label="Confirm New MPIN"
              icon="key"
              placeholder={`Re-enter ${MPIN_LENGTH} numbers`}
              value={confirmPin}
              onChangeText={(t) => setConfirmPin(t.replace(/\D/g, ''))}
            />
            {message ? <Text style={styles.message}>{message}</Text> : null}
            <AppButton label="Change MPIN" icon="shield-checkmark" onPress={() => void onChangeMpin()} loading={saving} />
            <Text style={styles.hint}>
              Your MPIN is stored as a salted hash in this device’s secure keychain — it never leaves the phone.
            </Text>
          </Card>

          <Text style={styles.sectionTitle}>Data & Storage</Text>
          <Card>
            <View style={styles.storageRow}>
              <Text style={styles.storageLabel}>Records stored</Text>
              <Text style={styles.storageValue}>{Object.keys(students).length} students</Text>
            </View>
            <View style={styles.storageRow}>
              <Text style={styles.storageLabel}>Storage</Text>
              <Text style={styles.storageValue}>Offline (this device)</Text>
            </View>
            <View style={[styles.storageRow, { borderBottomWidth: 0 }]}>
              <Text style={styles.storageLabel}>Auto-backup folder</Text>
              <Text style={[styles.storageValue, { fontSize: 11, textAlign: 'right', flex: 1 }]} numberOfLines={3}>
                {autoBackupDirPath()}
              </Text>
            </View>
            <AppButton
              label="Open Reports & Backups"
              variant="secondary"
              icon="document-text"
              onPress={() => router.push('/reports')}
              style={{ marginTop: 6 }}
            />
          </Card>

          <Text style={styles.sectionTitle}>About</Text>
          <Card>
            <Text style={styles.aboutTitle}>TIS ClassTrack</Text>
            <Text style={styles.aboutText}>
              Smarter Class Records, Made Simple. Built for Tugbo Integrated School — student information,
              grades, attendance, BMI and reports, all kept private on your device.
            </Text>
            <Text style={styles.aboutText}>Version 1.0.0</Text>
          </Card>
          <View style={{ height: 24 }} />
        </ScrollView>
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 30 },
  sectionTitle: { fontFamily: fonts.bold, fontSize: 16, color: colors.navyDark, marginTop: 16, marginBottom: 10, marginLeft: 4 },
  message: { fontFamily: fonts.medium, fontSize: 13, color: colors.red, textAlign: 'center', marginBottom: 8 },
  hint: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textSoft, marginTop: 10, lineHeight: 17 },
  storageRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: colors.bg,
    gap: 12,
  },
  storageLabel: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft },
  storageValue: { fontFamily: fonts.semibold, fontSize: 13, color: colors.navyDark },
  logoRow: { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 14 },
  logoPreview: {
    width: 76,
    height: 76,
    borderRadius: 14,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.bg,
  },
  logoInfo: { flex: 1, gap: 4 },
  logoHint: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.blue },
  logoMessage: {
    fontFamily: fonts.medium,
    fontSize: 12.5,
    color: colors.green,
    textAlign: 'center',
    marginBottom: 8,
  },
  aboutTitle: { fontFamily: fonts.bold, fontSize: 15, color: colors.navyDark },
  aboutText: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft, marginTop: 6, lineHeight: 19 },
});
