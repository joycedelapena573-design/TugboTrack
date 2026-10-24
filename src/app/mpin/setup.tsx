/**
 * First-run screen: a brand-new user picks a 4 or 6 digit MPIN, confirms it,
 * and lands on the dashboard.
 */
import { Redirect } from 'expo-router';
import { useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { PinPad } from '@/components/PinPad';
import { Button, Card } from '@/components/ui';
import { useStore } from '@/lib/store';
import { isValidMpin } from '@/lib/storage';
import { colors, radius, spacing } from '@/theme';

export default function SetupMpin() {
  const { ready, hasMpin, registerMpin } = useStore();
  const [length, setLength] = useState(6);
  const [stage, setStage] = useState<'enter' | 'confirm'>('enter');
  const [first, setFirst] = useState('');
  const [second, setSecond] = useState('');
  const [error, setError] = useState<string | null>(null);
  // Ref, not state: it must be true synchronously before the redirect guard runs.
  const registered = useRef(false);

  if (ready && hasMpin) {
    return <Redirect href={registered.current ? '/dashboard' : '/mpin/unlock'} />;
  }

  const reset = (nextLength?: number) => {
    setFirst('');
    setSecond('');
    setStage('enter');
    setError(null);
    if (nextLength !== undefined) setLength(nextLength);
  };

  const onEnterComplete = (value: string) => {
    if (!isValidMpin(value)) {
      setError('Use only digits.');
      reset();
      return;
    }
    setFirst(value);
    setSecond('');
    setError(null);
    setStage('confirm');
  };

  const onConfirmComplete = async (value: string) => {
    if (value !== first) {
      setError('The MPINs did not match. Please start again.');
      reset();
      return;
    }
    registered.current = true;
    await registerMpin(value, length);
  };

  return (
    <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <View style={styles.hero}>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>CR</Text>
          </View>
          <Text style={styles.title}>Set up your MPIN</Text>
          <Text style={styles.subtitle}>
            You&apos;re new here. Create a {length}-digit MPIN to lock your class records on this
            device.
          </Text>
        </View>

        <Card>
          <View style={styles.lengthRow}>
            {[4, 6].map((option) => (
              <Button
                key={option}
                label={`${option} digits`}
                variant={length === option ? 'primary' : 'secondary'}
                onPress={() => reset(option)}
                style={styles.flex}
              />
            ))}
          </View>

          <Text style={styles.stageLabel}>
            {stage === 'enter' ? `Enter your new ${length}-digit MPIN` : 'Re-enter to confirm'}
          </Text>

          <PinPad
            key={`${stage}-${length}`}
            value={stage === 'enter' ? first : second}
            onChange={(next) => (stage === 'enter' ? setFirst(next) : setSecond(next))}
            onComplete={stage === 'enter' ? onEnterComplete : onConfirmComplete}
            length={length}
          />

          {error ? <Text style={styles.error}>{error}</Text> : null}
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
  title: { fontSize: 24, fontWeight: '800', color: colors.text, textAlign: 'center' },
  subtitle: {
    fontSize: 14,
    color: colors.textMuted,
    textAlign: 'center',
    lineHeight: 20,
    paddingHorizontal: spacing.md,
  },
  lengthRow: { flexDirection: 'row', gap: spacing.sm },
  flex: { flex: 1 },
  stageLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.primary,
    textAlign: 'center',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  error: { fontSize: 13, color: colors.danger, fontWeight: '700', textAlign: 'center' },
});