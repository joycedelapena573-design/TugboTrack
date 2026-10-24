/**
 * Shared frame for the four class screens: resolves the class from the route,
 * shows its header and the Students / Assessments / Grades / BMI tabs.
 */
import { Link, router, useLocalSearchParams } from 'expo-router';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Chip, EmptyState } from '@/components/ui';
import { useStore } from '@/lib/store';
import { colors, radius, spacing } from '@/theme';

export type ClassTab = 'students' | 'assessments' | 'grades' | 'bmi';

const TABS: { key: ClassTab; label: string; path: (id: string) => string }[] = [
  { key: 'students', label: 'Students', path: (id) => `/classes/${id}` },
  { key: 'assessments', label: 'Grading', path: (id) => `/classes/${id}/assessments` },
  { key: 'grades', label: 'Grades', path: (id) => `/classes/${id}/grades` },
  { key: 'bmi', label: 'BMI', path: (id) => `/classes/${id}/bmi` },
];

export function useClassId(): string {
  const params = useLocalSearchParams<{ id: string }>();
  return String(params.id ?? '');
}

export function ClassShell({
  id,
  active,
  children,
}: {
  id: string;
  active: ClassTab;
  children: ReactNode;
}) {
  const { data } = useStore();
  const cls = data.classes.find((c) => c.id === id);

  if (!cls) {
    return (
      <View style={styles.missing}>
        <EmptyState title="Class not found" body="It may have been removed from this device." />
        <Pressable onPress={() => router.replace('/dashboard')}>
          <Text style={styles.link}>Back to dashboard</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.wrap}>
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <Text style={styles.subject} numberOfLines={2}>
            {cls.subject}
          </Text>
          <Chip tone="primary">{cls.section || 'No section'}</Chip>
        </View>
        <Text style={styles.meta}>
          {[cls.gradeLevel, cls.schoolYear].filter(Boolean).join(' · ') || ' '}
        </Text>
      </View>

      <View style={styles.tabs}>
        {TABS.map((tab) => {
          const isActive = tab.key === active;
          return (
            <Link key={tab.key} href={tab.path(id)} asChild>
              <Pressable
                accessibilityRole="tab"
                accessibilityState={{ selected: isActive }}
                style={[styles.tab, isActive && styles.tabActive]}
              >
                <Text style={[styles.tabText, isActive && styles.tabTextActive]}>{tab.label}</Text>
              </Pressable>
            </Link>
          );
        })}
      </View>

      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flex: 1, backgroundColor: colors.bg },
  missing: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: spacing.md },
  link: { color: colors.primary, fontWeight: '700', fontSize: 15 },
  header: {
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    gap: 4,
  },
  headerTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.sm },
  subject: { fontSize: 20, fontWeight: '800', color: colors.text, flexShrink: 1 },
  meta: { fontSize: 13, color: colors.textMuted },
  tabs: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    paddingHorizontal: spacing.sm,
    paddingBottom: spacing.sm,
    gap: 4,
  },
  tab: {
    flex: 1,
    minHeight: 38,
    borderRadius: radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.xs,
  },
  tabActive: { backgroundColor: colors.primarySoft },
  tabText: { fontSize: 12, fontWeight: '700', color: colors.textMuted },
  tabTextActive: { color: colors.primary },
});