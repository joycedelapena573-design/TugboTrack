/**
 * First-run MPIN setup (mockup 2). Creates the teacher profile and the
 * 6-digit MPIN that protects every class record on this device.
 */
import { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

import { BrandMark, LockArt } from '../components/decor';
import { AppButton, Field, SecureField } from '../components/ui';
import { useAppLock } from '../lib/appLock';
import { MPIN_LENGTH, createMpin, isValidMpin } from '../lib/mpin';
import { useStore } from '../lib/store';
import { colors, fonts } from '../lib/theme';

export default function MpinSetup() {
  const router = useRouter();
  const setTeacherName = useStore((s) => s.setTeacherName);
  const setLocked = useAppLock((s) => s.setLocked);

  const [name, setName] = useState('');
  const [pin, setPin] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);

  const onSave = async () => {
    setError('');
    if (!name.trim()) {
      setError('Please enter your name.');
      return;
    }
    if (!isValidMpin(pin)) {
      setError(`Your MPIN must be exactly ${MPIN_LENGTH} numbers.`);
      return;
    }
    if (pin !== confirm) {
      setError('The MPINs you entered do not match.');
      return;
    }
    setSaving(true);
    try {
      await createMpin(pin);
      setTeacherName(name);
      setLocked(false);
      router.replace('/(main)');
    } catch {
      setError('Could not save your MPIN. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          contentContainerStyle={styles.scroll}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.header}>
            <BrandMark size={52} />
            <View style={{ marginLeft: 12 }}>
              <Text style={styles.brandTitle}>
                TIS <Text style={{ color: colors.blue }}>ClassTrack</Text>
              </Text>
              <Text style={styles.brandSub}>Tugbo Integrated School</Text>
            </View>
          </View>

          <View style={styles.artWrap}>
            <LockArt size={190} />
          </View>

          <Text style={styles.title}>Set Up Your MPIN</Text>
          <Text style={styles.subtitle}>
            Enter your name and create a {MPIN_LENGTH}-digit MPIN{'\n'}to securely access your class
            records.
          </Text>

          <Field
            label="Teacher Name"
            icon="person"
            placeholder="Enter your full name"
            value={name}
            onChangeText={setName}
            autoCapitalize="words"
          />
          <SecureField
            label={`Create ${MPIN_LENGTH}-digit MPIN`}
            icon="lock-closed"
            placeholder={`Enter ${MPIN_LENGTH} numbers`}
            value={pin}
            onChangeText={(t) => setPin(t.replace(/\D/g, ''))}
          />
          <SecureField
            label={`Confirm ${MPIN_LENGTH}-digit MPIN`}
            icon="lock-closed"
            placeholder={`Re-enter ${MPIN_LENGTH} numbers`}
            value={confirm}
            onChangeText={(t) => setConfirm(t.replace(/\D/g, ''))}
          />

          {error ? <Text style={styles.error}>{error}</Text> : null}

          <AppButton
            label="Save and Continue"
            icon="arrow-forward"
            onPress={() => void onSave()}
            loading={saving}
            style={{ marginTop: 6 }}
          />

          <View style={styles.footer}>
            <Text style={styles.footerText}>Your Class Records, Organized.</Text>
            <View style={styles.footerDash} />
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  scroll: { paddingHorizontal: 22, paddingBottom: 28 },
  header: { flexDirection: 'row', alignItems: 'center', marginTop: 12 },
  brandTitle: { fontFamily: fonts.extrabold, fontSize: 24, color: colors.navyDark },
  brandSub: { fontFamily: fonts.regular, fontSize: 14.5, color: colors.textSoft, marginTop: -2 },
  artWrap: { alignItems: 'center', marginTop: 14 },
  title: {
    fontFamily: fonts.extrabold,
    fontSize: 30,
    color: colors.navyDark,
    textAlign: 'center',
    marginTop: 6,
  },
  subtitle: {
    fontFamily: fonts.regular,
    fontSize: 15,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 22,
    lineHeight: 22,
  },
  error: {
    fontFamily: fonts.medium,
    fontSize: 13.5,
    color: colors.red,
    textAlign: 'center',
    marginBottom: 10,
  },
  footer: { alignItems: 'center', marginTop: 22 },
  footerText: { fontFamily: fonts.regular, fontSize: 14, color: colors.textSoft },
  footerDash: { width: 44, height: 3.5, borderRadius: 2, backgroundColor: colors.blue, marginTop: 8 },
});
