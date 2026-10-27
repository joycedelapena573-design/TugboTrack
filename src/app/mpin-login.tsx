/**
 * MPIN unlock screen. Required every time the app is opened or brought back
 * from the background (requirement 6.2). The whole frame — keypad included —
 * fits on one screen with no scrolling.
 */
import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
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
      <View style={styles.content}>
        <View style={styles.header}>
          <BrandMark size={46} />
          <View style={{ marginLeft: 12 }}>
            <Text style={styles.brandTitle}>
              TIS <Text style={{ color: colors.blue }}>ClassTrack</Text>
            </Text>
            <Text style={styles.brandSub}>Tugbo Integrated School</Text>
          </View>
        </View>

        <View style={styles.artWrap}>
          <LockArt size={104} />
        </View>

        <Text style={styles.title}>Welcome Back{teacherName ? ',' : ''}</Text>
        {teacherName ? <Text style={styles.teacher}>{teacherName}</Text> : null}
        <Text style={styles.subtitle}>
          Enter your {MPIN_LENGTH}-digit MPIN to unlock{'\n'}your class records.
        </Text>

        {/* Flexible spacer keeps the keypad low on tall screens and collapses on short ones. */}
        <View style={{ flex: 1, minHeight: 4 }} />

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
            style={{ marginTop: 14, alignSelf: 'center', minWidth: 200 }}
          />
        ) : (
          <View style={styles.footer}>
            <Text style={styles.footerText}>Your Class Records, Organized.</Text>
            <View style={styles.footerDash} />
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  content: { flex: 1, paddingHorizontal: 22, paddingTop: 6, paddingBottom: 10 },
  header: { flexDirection: 'row', alignItems: 'center', marginTop: 4 },
  brandTitle: { fontFamily: fonts.extrabold, fontSize: 22, color: colors.navyDark },
  brandSub: { fontFamily: fonts.regular, fontSize: 13.5, color: colors.textSoft, marginTop: -2 },
  artWrap: { alignItems: 'center', marginTop: 6 },
  title: {
    fontFamily: fonts.extrabold,
    fontSize: 26,
    color: colors.navyDark,
    textAlign: 'center',
    marginTop: 2,
  },
  teacher: {
    fontFamily: fonts.semibold,
    fontSize: 15.5,
    color: colors.blue,
    textAlign: 'center',
    marginTop: 1,
  },
  subtitle: {
    fontFamily: fonts.regular,
    fontSize: 14.5,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 6,
    marginBottom: 2,
    lineHeight: 21,
  },
  error: {
    fontFamily: fonts.medium,
    fontSize: 13,
    color: colors.red,
    textAlign: 'center',
    marginBottom: 2,
  },
  footer: { alignItems: 'center', marginTop: 14 },
  footerText: { fontFamily: fonts.regular, fontSize: 13.5, color: colors.textSoft },
  footerDash: { width: 44, height: 3.5, borderRadius: 2, backgroundColor: colors.blue, marginTop: 7 },
});
