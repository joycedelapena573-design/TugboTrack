/** Home dashboard: greeting, summary stats, search, and the teacher's classes. */
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
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

  // Instant search over grade level, section and school year.
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState('');
  const q = query.trim().toLowerCase();
  const visibleList = useMemo(() => {
    if (!q) return sectionList;
    return sectionList.filter(
      (s) =>
        s.gradeLevel.toLowerCase().includes(q) ||
        s.section.toLowerCase().includes(q) ||
        s.schoolYear.toLowerCase().includes(q),
    );
  }, [sectionList, q]);

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
          <View style={styles.headerActions}>
            <Pressable
              style={[styles.searchBtn, searchOpen && styles.searchBtnActive]}
              onPress={() => {
                setSearchOpen((o) => {
                  if (o) setQuery('');
                  return !o;
                });
              }}
            >
              <Ionicons
                name={searchOpen ? 'close' : 'search'}
                size={18}
                color={searchOpen ? colors.white : colors.navy}
              />
            </Pressable>
            <Pressable style={styles.addButton} onPress={() => router.push('/class/section-form')}>
              <Ionicons name="add" size={20} color={colors.white} />
              <Text style={styles.addLabel}>Add Class</Text>
            </Pressable>
          </View>
        </View>

        {searchOpen ? (
          <View style={styles.searchBox}>
            <Ionicons name="search" size={18} color={colors.textFaint} />
            <TextInput
              style={styles.searchInput}
              placeholder="Search grade, section or school year"
              placeholderTextColor={colors.textFaint}
              value={query}
              onChangeText={setQuery}
              autoFocus
              autoCorrect={false}
            />
            {query ? (
              <Pressable onPress={() => setQuery('')} hitSlop={8}>
                <Ionicons name="close-circle" size={18} color={colors.textFaint} />
              </Pressable>
            ) : null}
          </View>
        ) : null}

        {sectionList.length === 0 ? (
          <EmptyState
            icon="school-outline"
            title="No classes yet"
            subtitle="Create your first class (grade level + section) to start organizing student records."
            actionLabel="Create a class"
            onAction={() => router.push('/class/section-form')}
          />
        ) : visibleList.length === 0 ? (
          <EmptyState
            icon="search-outline"
            title="No matches"
            subtitle={`Nothing matches “${query.trim()}”. Try another grade level, section or school year.`}
          />
        ) : (
          visibleList.map((sec) => {
            const kids = Object.values(students).filter((st) => st.sectionId === sec.id);
            const subs = Object.values(subjects)
              .filter((s) => s.sectionId === sec.id)
              .sort((a, b) => a.createdAt - b.createdAt);
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
                  <Text style={styles.className} numberOfLines={2}>
                    {sec.gradeLevel} — {sec.section}
                  </Text>
                  <Text style={styles.classMeta}>
                    SY {sec.schoolYear} · {kids.length} student{kids.length === 1 ? '' : 's'}
                  </Text>
                  <Text style={styles.classSubjects} numberOfLines={1}>
                    {subs.length ? subs.map((s) => s.name).join(' · ') : 'No subjects yet'}
                  </Text>
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
  headerActions: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  searchBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: colors.ice,
    borderWidth: 1.5,
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  searchBtnActive: { backgroundColor: colors.navy, borderColor: colors.navy },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.blue,
    borderRadius: radius.md,
    paddingHorizontal: 12,
    minHeight: 46,
    marginBottom: 12,
  },
  searchInput: { flex: 1, fontFamily: fonts.medium, fontSize: 14.5, color: colors.text, paddingVertical: 8 },
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
  classSubjects: { fontFamily: fonts.medium, fontSize: 12, color: colors.blue, marginTop: 3 },
  todayWrap: { alignItems: 'center' },
  todayLabel: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textFaint },
  todayValue: { fontFamily: fonts.bold, fontSize: 13 },
});
