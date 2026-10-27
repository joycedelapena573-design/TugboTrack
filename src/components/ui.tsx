/** Shared UI building blocks styled after the approved mockups. */
import type { ReactNode } from 'react';
import React, { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextInputProps,
  type ViewStyle,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView } from 'react-native-safe-area-context';

import { colors, fonts, radius, shadow } from '../lib/theme';

export function Screen({
  children,
  style,
  edges = ['top'],
}: {
  children: ReactNode;
  style?: ViewStyle;
  edges?: ('top' | 'bottom' | 'left' | 'right')[];
}) {
  return (
    <SafeAreaView style={[styles.screen, style]} edges={edges}>
      {children}
    </SafeAreaView>
  );
}

export function Card({ children, style }: { children: ReactNode; style?: ViewStyle }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

export function AppButton({
  label,
  onPress,
  variant = 'primary',
  icon,
  loading,
  disabled,
  style,
}: {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  icon?: keyof typeof Ionicons.glyphMap;
  loading?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
}) {
  const isDisabled = disabled || loading;
  const palette: Record<ButtonVariant, { bg: string; fg: string; border?: string }> = {
    primary: { bg: colors.navy, fg: colors.white },
    secondary: { bg: colors.ice, fg: colors.navy },
    ghost: { bg: 'transparent', fg: colors.navy, border: colors.border },
    danger: { bg: '#FDE4E1', fg: colors.red },
  };
  const p = palette[variant];
  return (
    <Pressable
      onPress={onPress}
      disabled={isDisabled}
      style={({ pressed }) => [
        styles.button,
        { backgroundColor: p.bg, borderColor: p.border ?? 'transparent', borderWidth: p.border ? 1.5 : 0 },
        variant === 'primary' && shadow.soft,
        isDisabled && { opacity: 0.5 },
        pressed && { transform: [{ scale: 0.985 }] },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={p.fg} />
      ) : (
        <View style={styles.buttonRow}>
          {icon ? <Ionicons name={icon} size={18} color={p.fg} style={{ marginRight: 8 }} /> : null}
          <Text style={[styles.buttonLabel, { color: p.fg }]}>{label}</Text>
        </View>
      )}
    </Pressable>
  );
}

export function Field({
  label,
  hint,
  icon,
  right,
  style,
  ...inputProps
}: TextInputProps & {
  label: string;
  hint?: string;
  icon?: keyof typeof Ionicons.glyphMap;
  right?: ReactNode;
  style?: ViewStyle;
}) {
  return (
    <View style={[styles.field, style]}>
      {label ? <Text style={styles.fieldLabel}>{label}</Text> : null}
      <View style={styles.fieldBox}>
        {icon ? (
          <View style={styles.fieldIcon}>
            <Ionicons name={icon} size={18} color={colors.navy} />
          </View>
        ) : null}
        <TextInput
          placeholderTextColor={colors.textFaint}
          style={styles.input}
          {...inputProps}
        />
        {right}
      </View>
      {hint ? <Text style={styles.fieldHint}>{hint}</Text> : null}
    </View>
  );
}

/** Password-style field with an eye toggle (matches the mockup's MPIN fields). */
export function SecureField({
  label,
  hint,
  icon,
  value,
  onChangeText,
  placeholder,
}: {
  label: string;
  hint?: string;
  icon?: keyof typeof Ionicons.glyphMap;
  value: string;
  onChangeText: (t: string) => void;
  placeholder?: string;
}) {
  const [hidden, setHidden] = useState(true);
  return (
    <Field
      label={label}
      hint={hint}
      icon={icon}
      value={value}
      onChangeText={onChangeText}
      placeholder={placeholder}
      secureTextEntry={hidden}
      keyboardType="number-pad"
      maxLength={6}
      right={
        <Pressable onPress={() => setHidden((h) => !h)} hitSlop={12} style={{ paddingHorizontal: 6 }}>
          <Ionicons name={hidden ? 'eye-off-outline' : 'eye-outline'} size={22} color={colors.textFaint} />
        </Pressable>
      }
    />
  );
}

export function Chip({
  label,
  active,
  onPress,
  color,
}: {
  label: string;
  active?: boolean;
  onPress?: () => void;
  color?: string;
}) {
  const tint = color ?? colors.navy;
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.chip,
        active ? { backgroundColor: tint, borderColor: tint } : { backgroundColor: colors.white, borderColor: colors.border },
      ]}
    >
      <Text style={[styles.chipLabel, { color: active ? colors.white : colors.text }]} numberOfLines={1}>
        {label}
      </Text>
    </Pressable>
  );
}

export function ChipRow({ children }: { children: ReactNode }) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ paddingHorizontal: 16, gap: 8, paddingVertical: 2 }}
    >
      {children}
    </ScrollView>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { value: T; label: string; color?: string }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <View style={styles.segmented}>
      {options.map((opt) => {
        const active = opt.value === value;
        return (
          <Pressable
            key={opt.value}
            onPress={() => onChange(opt.value)}
            style={[
              styles.segment,
              active && { backgroundColor: opt.color ?? colors.navy, borderColor: opt.color ?? colors.navy },
            ]}
          >
            <Text
              numberOfLines={1}
              style={[styles.segmentLabel, { color: active ? colors.white : colors.text }]}
            >
              {opt.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function PageHeader({
  title,
  subtitle,
  onBack,
  right,
}: {
  title: string;
  subtitle?: string;
  onBack?: () => void;
  right?: ReactNode;
}) {
  return (
    <View style={styles.pageHeader}>
      <View style={{ flexDirection: 'row', alignItems: 'center', flex: 1 }}>
        {onBack ? (
          <Pressable onPress={onBack} hitSlop={10} style={styles.backButton}>
            <Ionicons name="chevron-back" size={24} color={colors.navy} />
          </Pressable>
        ) : null}
        <View style={{ flex: 1 }}>
          <Text style={styles.pageTitle} numberOfLines={1}>
            {title}
          </Text>
          {subtitle ? (
            <Text style={styles.pageSubtitle} numberOfLines={1}>
              {subtitle}
            </Text>
          ) : null}
        </View>
      </View>
      {right}
    </View>
  );
}

export function EmptyState({
  icon,
  title,
  subtitle,
  actionLabel,
  onAction,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <View style={styles.empty}>
      <View style={styles.emptyIcon}>
        <Ionicons name={icon} size={34} color={colors.navy} />
      </View>
      <Text style={styles.emptyTitle}>{title}</Text>
      <Text style={styles.emptySubtitle}>{subtitle}</Text>
      {actionLabel && onAction ? (
        <AppButton label={actionLabel} onPress={onAction} style={{ marginTop: 16, alignSelf: 'stretch' }} />
      ) : null}
    </View>
  );
}

export function Badge({ label, color, bg }: { label: string; color: string; bg: string }) {
  return (
    <View style={[styles.badge, { backgroundColor: bg }]}>
      <Text style={[styles.badgeLabel, { color }]}>{label}</Text>
    </View>
  );
}

export function Row({ children, style }: { children: ReactNode; style?: ViewStyle }) {
  return <View style={[{ flexDirection: 'row', alignItems: 'center' }, style]}>{children}</View>;
}

export function TintText({
  children,
  style,
}: {
  children: ReactNode;
  style?: import('react-native').TextStyle;
}) {
  return <Text style={[{ color: colors.text }, style]}>{children}</Text>;
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg },
  card: {
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: 16,
    ...shadow.card,
  },
  button: {
    minHeight: 52,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
    paddingVertical: 12,
  },
  buttonRow: { flexDirection: 'row', alignItems: 'center' },
  buttonLabel: { fontFamily: fonts.semibold, fontSize: 15.5 },
  field: { marginBottom: 14 },
  fieldLabel: {
    fontFamily: fonts.semibold,
    fontSize: 14.5,
    color: colors.text,
    marginBottom: 6,
    marginLeft: 4,
  },
  fieldBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.white,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.border,
    paddingHorizontal: 12,
    minHeight: 56,
  },
  fieldIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  input: {
    flex: 1,
    fontFamily: fonts.medium,
    fontSize: 15.5,
    color: colors.text,
    paddingVertical: 12,
  },
  fieldHint: { fontFamily: fonts.regular, fontSize: 12, color: colors.textFaint, marginTop: 4, marginLeft: 4 },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    minHeight: 40,
    justifyContent: 'center',
  },
  chipLabel: { fontFamily: fonts.semibold, fontSize: 13.5 },
  segmented: {
    flexDirection: 'row',
    backgroundColor: colors.ice,
    borderRadius: radius.pill,
    padding: 4,
    gap: 4,
  },
  segment: {
    flex: 1,
    paddingVertical: 9,
    borderRadius: radius.pill,
    alignItems: 'center',
    borderWidth: 1.5,
    borderColor: 'transparent',
  },
  segmentLabel: { fontFamily: fonts.semibold, fontSize: 13 },
  pageHeader: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  backButton: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  pageTitle: { fontFamily: fonts.bold, fontSize: 20, color: colors.navyDark },
  pageSubtitle: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, marginTop: 2 },
  empty: { alignItems: 'center', padding: 28, paddingTop: 40 },
  emptyIcon: {
    width: 78,
    height: 78,
    borderRadius: 39,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 14,
  },
  emptyTitle: { fontFamily: fonts.bold, fontSize: 17, color: colors.navyDark, textAlign: 'center' },
  emptySubtitle: {
    fontFamily: fonts.regular,
    fontSize: 13.5,
    color: colors.textSoft,
    textAlign: 'center',
    marginTop: 6,
    lineHeight: 20,
  },
  badge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.pill },
  badgeLabel: { fontFamily: fonts.semibold, fontSize: 12 },
});
