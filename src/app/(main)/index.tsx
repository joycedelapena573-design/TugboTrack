/** Home dashboard: greeting, summary stats, and the teacher's classes. */
import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';

import { EmptyState, Card, Screen } from '../../components/ui';
import { todayISO } from '../../lib/format';
import { useStore } from '../../lib/store';
import { colors, fonts, radius, shadow } from '../../lib/theme';

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

export default function Home() {
  const router = useRouter();
  const teacherName = useStore((s) => s.teacherName);
  const sections = useStore((s) => s.sections);
  const students = useStore((s) => s.students);
  const subjects = useStore((s) => s.subjects);
  const attendance = useStore((s) => s.attendance);
  const setActiveSection = useStore((s) => s.setActiveSection);

  const sectionList = useMemo(
    () => Object.values(sections).sort((a, b) => a.createdAt - b.createdAt),
    [sections],
  );
  const totalStudents = Object.keys(students).length;
  const today = todayISO();

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <View style={styles.headerRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.greeting}>{greeting()},</Text>
            <Text style={styles.name} numberOfLines={1}>
              {teacherName || 'Teacher'}
            </Text>
            <Text style={styles.school}>Tugbo Integrated School</Text>
          </View>
          <Pressable style={styles.settingsBtn} onPress={() => router.push('/settings')}>
            <Ionicons name="settings-outline" size={22} color={colors.navy} />
          </Pressable>
        </View>

        <View style={styles.statsRow}>
          <Stat icon="school" value={sectionList.length} label="Classes" />
          <Stat icon="people" value={totalStudents} label="Students" />
          <Stat icon="book" value={Object.keys(subjects).length} label="Subjects" />
        </View>

        <View style={styles.sectionHeaderRow}>
          <Text style={styles.sectionTitle}>My Classes</Text>
          <Pressable style={styles.addButton} onPress={() => router.push('/class/section-form')}>
            <Ionicons name="add" size={20} color={colors.white} />
            <Text style={styles.addLabel}>Add Class</Text>
          </Pressable>
        </View>

        {sectionList.length === 0 ? (
          <EmptyState
            icon="school-outline"
            title="No classes yet"
            subtitle="Create your first class (grade level + section) to start organizing student records."
            actionLabel="Create a class"
            onAction={() => router.push('/class/section-form')}
          />
        ) : (
          sectionList.map((sec) => {
            const kids = Object.values(students).filter((st) => st.sectionId === sec.id);
            const subs = Object.values(subjects).filter((s) => s.sectionId === sec.id);
            const day = attendance[`${sec.id}::${today}`];
            const marked = day ? Object.keys(day.statuses).length : 0;
            return (
              <Pressable
                key={sec.id}
                onPress={() => {
                  setActiveSection(sec.id);
                  router.push({ pathname: '/class/[id]', params: { id: sec.id } });
                }}
                style={({ pressed }) => [styles.classCard, pressed && { transform: [{ scale: 0.99 }] }]}
              >
                <View style={styles.classBadge}>
                  <Text style={styles.classBadgeLabel} numberOfLines={2}>
                    {sec.gradeLevel.replace('Grade ', 'G')}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.className} numberOfLines={1}>
                    {sec.gradeLevel} — {sec.section}
                  </Text>
                  <Text style={styles.classMeta}>SY {sec.schoolYear}</Text>
                  <View style={styles.metaRow}>
                    <MetaChip icon="people-outline" label={`${kids.length} students`} />
                    <MetaChip icon="book-outline" label={`${subs.length} subject${subs.length === 1 ? '' : 's'}`} />
                  </View>
                </View>
                <View style={styles.todayWrap}>
                  <Text style={styles.todayLabel}>Today</Text>
                  <Text style={[styles.todayValue, { color: marked > 0 ? colors.green : colors.textFaint }]}>
                    {marked > 0 ? 'Done' : '—'}
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={20} color={colors.textFaint} />
              </Pressable>
            );
          })
        )}

        <View style={{ height: 24 }} />
      </ScrollView>
    </Screen>
  );
}

function Stat({
  icon,
  value,
  label,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  value: number;
  label: string;
}) {
  return (
    <Card style={styles.stat}>
      <View style={styles.statIcon}>
        <Ionicons name={icon} size={18} color={colors.navy} />
      </View>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </Card>
  );
}

function MetaChip({ icon, label }: { icon: keyof typeof Ionicons.glyphMap; label: string }) {
  return (
    <View style={styles.metaChip}>
      <Ionicons name={icon} size={13} color={colors.textSoft} />
      <Text style={styles.metaChipLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 32 },
  headerRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 18 },
  greeting: { fontFamily: fonts.regular, fontSize: 15, color: colors.textSoft },
  name: { fontFamily: fonts.extrabold, fontSize: 24, color: colors.navyDark },
  school: { fontFamily: fonts.medium, fontSize: 13, color: colors.blue, marginTop: 2 },
  settingsBtn: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statsRow: { flexDirection: 'row', gap: 10, marginBottom: 22 },
  stat: { flex: 1, alignItems: 'center', paddingVertical: 14, paddingHorizontal: 8 },
  statIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  statValue: { fontFamily: fonts.extrabold, fontSize: 20, color: colors.navyDark },
  statLabel: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textSoft },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  sectionTitle: { fontFamily: fonts.bold, fontSize: 18, color: colors.navyDark },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.navy,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radius.pill,
    gap: 4,
    ...shadow.soft,
  },
  addLabel: { fontFamily: fonts.semibold, fontSize: 13, color: colors.white },
  classCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.white,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: 14,
    marginBottom: 12,
    gap: 12,
    ...shadow.card,
  },
  classBadge: {
    width: 52,
    height: 52,
    borderRadius: 16,
    backgroundColor: colors.navy,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  classBadgeLabel: { fontFamily: fonts.bold, fontSize: 13, color: colors.white, textAlign: 'center' },
  className: { fontFamily: fonts.semibold, fontSize: 15.5, color: colors.navyDark },
  classMeta: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft, marginTop: 1 },
  metaRow: { flexDirection: 'row', gap: 8, marginTop: 6 },
  metaChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: colors.bg,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radius.pill,
  },
  metaChipLabel: { fontFamily: fonts.medium, fontSize: 11, color: colors.textSoft },
  todayWrap: { alignItems: 'center' },
  todayLabel: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textFaint },
  todayValue: { fontFamily: fonts.bold, fontSize: 13 },
});
