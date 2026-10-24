/**
 * Returning-user screen: enter the registered MPIN to unlock the dashboard.
 */
import { Redirect } from 'expo-router';
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { PinPad } from '@/components/PinPad';
import { Button, Card } from '@/components/ui';
import { useStore } from '@/lib/store';
import { colors, radius, spacing } from '@/theme';

export default function UnlockMpin() {
  const { ready, hasMpin, unlocked, unlock, mpinError, clearMpinError, mpinLength } = useStore();
  const [pin, setPin] = useState('');
  const [busy, setBusy] = useState(false);

  if (ready && !hasMpin) return <Redirect href="/mpin/setup" />;
  if (unlocked) return <Redirect href="/dashboard" />;

  const submit = async (value: string) => {
    if (busy || value.length !== mpinLength) return;
    setBusy(true);
    // Success flips `unlocked`, which the Redirect below turns into /dashboard.
    const ok = await unlock(value);
    setBusy(false);
    if (!ok) setPin('');
  };

  return (
    <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.hero}>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>CR</Text>
          </View>
          <Text style={styles.title}>Welcome back</Text>
          <Text style={styles.subtitle}>Enter your {mpinLength}-digit MPIN to unlock your records.</Text>
        </View>

        <Card>
          <PinPad
            value={pin}
            onChange={(next) => {
              setPin(next);
              if (mpinError) clearMpinError();
            }}
            onComplete={submit}
            length={mpinLength}
          />

          {mpinError ? <Text style={styles.error}>{mpinError}</Text> : null}

          <Button
            label={busy ? 'Checking...' : 'Unlock'}
            onPress={() => submit(pin)}
            disabled={busy || pin.length !== mpinLength}
          />
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.bg },
  content: { padding: spacing.lg, gap: spacing.xl, paddingBottom: spacing.xxl },
  hero: { alignItems: 'center', gap: spacing.sm, marginTop: spacing.lg },
  badge: {
    width: 64,
    height: 64,
    borderRadius: radius.lg,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  badgeText: { color: '#FFFFFF', fontSize: 24, fontWeight: '800' },
  title: { fontSize: 24, fontWeight: '800', color: colors.text },
  subtitle: { fontSize: 14, color: colors.textMuted, textAlign: 'center', lineHeight: 20 },
  error: { fontSize: 13, color: colors.danger, fontWeight: '700', textAlign: 'center' },
});