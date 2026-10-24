/**
 * Entry route: decides whether this device is new (set an MPIN), locked
 * (enter the registered MPIN) or ready (go to the dashboard).
 */
import { Redirect } from 'expo-router';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { useStore } from '@/lib/store';
import { colors, spacing } from '@/theme';

export default function Index() {
  const { ready, hasMpin, unlocked } = useStore();

  if (!ready) {
    return (
      <View style={styles.splash}>
        <Text style={styles.title}>Class Records</Text>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (!hasMpin) return <Redirect href="/mpin/setup" />;
  if (!unlocked) return <Redirect href="/mpin/unlock" />;
  return <Redirect href="/dashboard" />;
}

const styles = StyleSheet.create({
  splash: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.lg,
    backgroundColor: colors.bg,
  },
  title: { fontSize: 24, fontWeight: '800', color: colors.text, letterSpacing: -0.5 },
});