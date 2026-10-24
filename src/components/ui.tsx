/**
 * Small shared UI primitives so every screen looks the same without pulling in
 * a component library.
 */
import type { ReactNode } from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type StyleProp,
  type TextInputProps,
  type ViewStyle,
} from 'react-native';

import { colors, radius, spacing, toneColors, type Tone } from '@/theme';

export function Card({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function SectionTitle({ children, right }: { children: ReactNode; right?: ReactNode }) {
  return (
    <View style={styles.sectionRow}>
      <Text style={styles.sectionTitle}>{children}</Text>
      {right}
    </View>
  );
}export function Chip({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  const palette = toneColors[tone];
  return (
    <View style={[styles.chip, { backgroundColor: palette.bg }]}> 
      <Text style={[styles.chipText, { color: palette.fg }]}>{children}</Text>
    </View>
  );
}

/** Selectable pill used for preset pickers. */
export function ChoiceChip({
  selected,
  onPress,
  children,
}: {
  selected: boolean;
  onPress: () => void;
  children: ReactNode;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      onPress={onPress}
      style={({ pressed }) => [
        styles.chip,
        selected ? styles.choiceOn : styles.choiceOff,
        pressed && { opacity: 0.7 },
      ]}
    >
      <Text style={[styles.chipText, selected ? styles.choiceTextOn : styles.choiceTextOff]}>
        {children}
      </Text>
    </Pressable>
  );
}

interface ButtonProps {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function Button({ label, onPress, variant = 'primary', disabled, style }: ButtonProps) {
  const isPrimary = variant === 'primary';
  const isDanger = variant === 'danger';
  const isGhost = variant === 'ghost';

  const background = isPrimary
    ? colors.primary
    : isDanger
      ? colors.dangerSoft
      : isGhost
        ? 'transparent'
        : colors.surfaceAlt;

  const foreground = isPrimary
    ? '#FFFFFF'
    : isDanger
      ? colors.danger
      : isGhost
        ? colors.primary
        : colors.text;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: disabled ?? false }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        { backgroundColor: background, opacity: disabled ? 0.45 : pressed ? 0.75 : 1 },
        style,
      ]}
    >
      <Text style={[styles.buttonText, { color: foreground }]}>{label}</Text>
    </Pressable>
  );
}

interface FieldProps extends TextInputProps {
  label: string;
  hint?: string;
  error?: string | null;
}

export function Field({ label, hint, error, style, ...rest }: FieldProps) {
  return (
    <View style={styles.field}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        placeholderTextColor={colors.textMuted}
        style={[styles.input, error ? styles.inputError : null, style]}
        {...rest}
      />
      {error ? (
        <Text style={styles.fieldError}>{error}</Text>
      ) : hint ? (
        <Text style={styles.fieldHint}>{hint}</Text>
      ) : null}
    </View>
  );
}

export function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <View style={styles.empty}>
      <Text style={styles.emptyTitle}>{title}</Text>
      <Text style={styles.emptyBody}>{body}</Text>
    </View>
  );
}

export function Row({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.row, style]}>{children}</View>;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.lg,
    gap: spacing.md,
  },
  sectionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: colors.textMuted, letterSpacing: 0.6 },
  chip: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    borderRadius: radius.pill,
    alignSelf: 'flex-start',
  },
  chipText: { fontSize: 11, fontWeight: '700' },
  choiceOn: { backgroundColor: colors.primary, borderColor: colors.primary, borderWidth: 1 },
  choiceOff: { backgroundColor: colors.surfaceAlt, borderColor: colors.border, borderWidth: 1 },
  choiceTextOn: { color: '#FFFFFF' },
  choiceTextOff: { color: colors.text },
  button: {
    minHeight: 48,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  buttonText: { fontSize: 15, fontWeight: '700' },
  field: { gap: 6, marginBottom: spacing.md },
  fieldLabel: { fontSize: 13, fontWeight: '600', color: colors.textMuted },
  input: {
    minHeight: 48,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    fontSize: 16,
    color: colors.text,
    backgroundColor: colors.surface,
  },
  inputError: { borderColor: colors.danger },
  fieldHint: { fontSize: 12, color: colors.textMuted },
  fieldError: { fontSize: 12, color: colors.danger, fontWeight: '600' },
  empty: { alignItems: 'center', paddingVertical: spacing.xl, gap: spacing.sm },
  emptyTitle: { fontSize: 15, fontWeight: '700', color: colors.text },
  emptyBody: { fontSize: 13, color: colors.textMuted, textAlign: 'center', lineHeight: 19 },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
});