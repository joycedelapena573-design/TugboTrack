/**
 * Custom numeric keypad plus dot indicator used for MPIN setup and unlocking.
 * A custom pad keeps the flow on-screen and avoids the system keyboard covering
 * the digits on small devices.
 */
import { StyleSheet, Text, View, Pressable } from 'react-native';

import { colors, radius, spacing } from '@/theme';

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];

interface Props {
  value: string;
  onChange: (next: string) => void;
  onComplete?: (value: string) => void;
  length?: number;
}

export function PinPad({ value, onChange, onComplete, length = 6 }: Props) {
  const press = (key: string) => {
    if (key === 'del') {
      onChange(value.slice(0, -1));
      return;
    }
    if (key === '' || value.length >= length) return;
    const next = value + key;
    onChange(next);
    if (next.length === length) onComplete?.(next);
  };

  return (
    <View style={styles.wrap}>
      <View style={styles.dots}>
        {Array.from({ length }).map((_, index) => (
          <View
            key={index}
            style={[styles.dot, index < value.length ? styles.dotFilled : null]}
          />
        ))}
      </View>

      <View style={styles.pad}>
        {KEYS.map((key, index) =>
          key === '' ? (
            <View key={`spacer-${index}`} style={styles.key} />
          ) : (
            <Pressable
              key={key}
              accessibilityRole="button"
              accessibilityLabel={key === 'del' ? 'Delete' : key}
              onPress={() => press(key)}
              style={({ pressed }) => [styles.key, pressed && styles.keyPressed]}
            >
              <Text style={styles.keyText}>{key === 'del' ? '\u232B' : key}</Text>
            </Pressable>
          ),
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: spacing.xl },
  dots: { flexDirection: 'row', justifyContent: 'center', gap: spacing.md },
  dot: {
    width: 14,
    height: 14,
    borderRadius: 7,
    borderWidth: 2,
    borderColor: colors.border,
    backgroundColor: 'transparent',
  },
  dotFilled: { backgroundColor: colors.primary, borderColor: colors.primary },
  pad: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: spacing.sm,
  },
  key: {
    width: 76,
    height: 62,
    borderRadius: radius.md,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  keyPressed: { backgroundColor: colors.surfaceAlt },
  keyText: { fontSize: 24, fontWeight: '600', color: colors.text },
});