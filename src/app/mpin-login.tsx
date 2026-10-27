/**
 * MPIN unlock screen. Required every time the app is opened or brought back
 * from the background (requirement 6.2).
 */
import { useEffect, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

import { BrandMark, LockArt } from '../components/decor';
import { PinDots, PinPad } from '../components/PinPad';
import { AppButton } from '../components/ui';
import { useAppLock } from '../lib/appLock';
import { MPIN_LENGTH, lockoutRemainingMs, verifyMpin } from '../lib/mpin';
import { useStore } from '../lib/store';
import { colors, fonts } from '../lib/theme';

export default function MpinLogin() {
  const router = useRouter();
  const teacherName = useStore((s) => s.teacherName);
  const setLocked = useAppLock((s) => s.setLocked);

  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [lockRemaining, setLockRemaining] = useState(0);
  const [checking, setChecking] = useState(false);

  useEffect(() => {
    void lockoutRemainingMs().then(setLockRemaining);
  }, []);

  useEffect(() => {
    if (lockRemaining <= 0) return;
    const t = setInterval(() => {
      setLockRemaining((r) => {
        if (r <= 1000) {
          clearInterval(t);
          setError('');
          return 0;
        }
        return r - 1000;
      });
    }, 1000);
    return () => clearInterval(t);
  }, [lockRemaining]);

  const submit = async (value: string) => {
    setChecking(true);
    try {
      const result = await verifyMpin(value);
      if (result.ok) {
        setLocked(false);
        router.replace('/(main)');
        return;
      }
      setPin('');
      if (result.reason === 'locked') {
        setLockRemaining(result.retryInMs);
        setError('Too many attempts. Please wait before trying again.');
      } else if (result.reason === 'unset') {
        router.replace('/mpin-setup');
      } else {
        setError(`Incorrect MPIN. ${result.attemptsLeft} attempt${result.attemptsLeft === 1 ? '' : 's'} left.`);
      }
    } finally {
      setChecking(false);
    }
  };

  const onChange = (value: string) => {
    if (lockRemaining > 0 || checking) return;
    setPin(value);
    if (value.length === MPIN_LENGTH) void submit(value);
  };

  return (
    <SafeAreaView style={styles.root} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
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
          <LockArt size={170} />
        </View>

        <Text style={styles.title}>Welcome Back{teacherName ? ',' : ''}</Text>
        {teacherName ? <Text style={styles.teacher}>{teacherName}</Text> : null}
        <Text style={styles.subtitle}>
          Enter your {MPIN_LENGTH}-digit MPIN to unlock{'\n'}your class records.
        </Text>

        <PinDots value={pin} />
        {error ? (
          <Text style={styles.error}>
            {lockRemaining > 0 ? `${error} (${Math.ceil(lockRemaining / 1000)}s)` : error}
          </Text>
        ) : null}

        <PinPad value={pin} onChange={onChange} />

        {lockRemaining > 0 ? (
          <AppButton
            label={`Wait ${Math.ceil(lockRemaining / 1000)}s`}
            variant="secondary"
            onPress={() => {}}
            disabled
            style={{ marginTop: 20, alignSelf: 'center', minWidth: 200 }}
          />
        ) : null}

        <View style={styles.footer}>
          <Text style={styles.footerText}>Your Class Records, Organized.</Text>
          <View style={styles.footerDash} />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  scroll: { paddingHorizontal: 22, paddingBottom: 30 },
  header: { flexDirection: 'row', alignItems: 'center', marginTop: 12 },
  brandTitle: { fontFamily: fonts.extrabold, fontSize: 24, color: colors.navyDark },
  brandSub: { fontFamily: fonts.regular, fontSize: 14.5, color: colors.textSoft, marginTop: -2 },
  artWrap: { alignItems: 'center', marginTop: 10 },
  title: {
    fontFamily: fonts.extrabold,
    fontSize: 28,
    color: colors.navyDark,
    textAlign: 'center',
    marginTop: 4,
  },
  teacher: {
    fontFamily: fonts.semibold,
    fontSize: 16,
    color: colors.blue,
    textAlign: 'center',
    marginTop: 2,
  },
  subtitle: {
    fontFamily: fonts.regular,
    fontSize: 15,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 6,
    lineHeight: 22,
  },
  error: {
    fontFamily: fonts.medium,
    fontSize: 13.5,
    color: colors.red,
    textAlign: 'center',
    marginBottom: 4,
  },
  footer: { alignItems: 'center', marginTop: 26 },
  footerText: { fontFamily: fonts.regular, fontSize: 14, color: colors.textSoft },
  footerDash: { width: 44, height: 3.5, borderRadius: 2, backgroundColor: colors.blue, marginTop: 8 },
});
