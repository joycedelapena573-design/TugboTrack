/** Numeric MPIN keypad with dot display (6-digit). */
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';

import { colors, fonts, radius } from '../lib/theme';
import { MPIN_LENGTH } from '../lib/mpin';

export function PinDots({ value }: { value: string }) {
  return (
    <View style={styles.dots}>
      {Array.from({ length: MPIN_LENGTH }).map((_, i) => (
        <View
          key={i}
          style={[
            styles.dot,
            i < value.length ? styles.dotFilled : null,
            i === value.length ? styles.dotActive : null,
          ]}
        />
      ))}
    </View>
  );
}

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];

export function PinPad({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const press = (key: string) => {
    Haptics.selectionAsync().catch(() => {});
    if (key === 'del') {
      onChange(value.slice(0, -1));
      return;
    }
    if (!key) return;
    if (value.length >= MPIN_LENGTH) return;
    onChange(value + key);
  };

  return (
    <View style={styles.pad}>
      {KEYS.map((key, i) => (
        <Pressable
          key={`${key}-${i}`}
          disabled={key === ''}
          onPress={() => press(key)}
          style={({ pressed }) => [
            styles.key,
            key === '' && { backgroundColor: 'transparent', borderColor: 'transparent' },
            pressed && key !== '' && { backgroundColor: colors.iceDeep, transform: [{ scale: 0.97 }] },
          ]}
        >
          {key === 'del' ? (
            <Ionicons name="backspace-outline" size={24} color={colors.navy} />
          ) : (
            <Text style={styles.keyLabel}>{key}</Text>
          )}
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  dots: { flexDirection: 'row', justifyContent: 'center', gap: 12, marginVertical: 18 },
  dot: {
    width: 15,
    height: 15,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#B9CEF3',
    backgroundColor: 'transparent',
  },
  dotFilled: { backgroundColor: colors.navy, borderColor: colors.navy },
  dotActive: { borderColor: colors.navy },
  pad: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 10,
    paddingHorizontal: 24,
  },
  key: {
    width: 88,
    height: 62,
    borderRadius: radius.md,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  keyLabel: { fontFamily: fonts.semibold, fontSize: 24, color: colors.navyDark },
});
