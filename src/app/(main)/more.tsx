/** More tab: quick access to BMI, reports, security and about. */
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';

import { Card, Screen } from '../../components/ui';
import { useAppLock } from '../../lib/appLock';
import { useStore } from '../../lib/store';
import { colors, fonts, radius } from '../../lib/theme';

const TILES: {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  hint: string;
  href: '/bmi' | '/reports' | '/settings';
}[] = [
  { icon: 'body', label: 'BMI Monitoring', hint: 'Height, weight & interpretation', href: '/bmi' },
  { icon: 'document-text', label: 'Reports & Exports', hint: 'Print, PDF and CSV backups', href: '/reports' },
  { icon: 'key', label: 'Security', hint: 'Change your MPIN', href: '/settings' },
];

export default function More() {
  const router = useRouter();
  const teacherName = useStore((s) => s.teacherName);
  const students = useStore((s) => s.students);
  const attendance = useStore((s) => s.attendance);
  const bmi = useStore((s) => s.bmi);
  const setLocked = useAppLock((s) => s.setLocked);

  const totalStudents = Object.keys(students).length;
  const totalDays = Object.keys(attendance).length;
  const totalBmi = Object.keys(bmi).length;

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <Card style={styles.profile}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>
              {(teacherName || 'T').trim().charAt(0).toUpperCase()}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.name} numberOfLines={1}>
              {teacherName || 'Teacher'}
            </Text>
            <Text style={styles.school}>Tugbo Integrated School</Text>
          </View>
        </Card>

        <View style={styles.statsRow}>
          <MiniStat value={totalStudents} label="Students" />
          <MiniStat value={totalDays} label="Attendance days" />
          <MiniStat value={totalBmi} label="BMI records" />
        </View>

        {TILES.map((tile) => (
          <Pressable key={tile.href} onPress={() => router.push(tile.href)}>
            <Card style={styles.tile}>
              <View style={styles.tileIcon}>
                <Ionicons name={tile.icon} size={20} color={colors.navy} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.tileLabel}>{tile.label}</Text>
                <Text style={styles.tileHint}>{tile.hint}</Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color={colors.textFaint} />
            </Card>
          </Pressable>
        ))}

        <Pressable onPress={() => setLocked(true)}>
          <Card style={styles.tile}>
            <View style={[styles.tileIcon, { backgroundColor: '#FFF1D6' }]}>
              <Ionicons name="lock-closed" size={20} color={colors.amber} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.tileLabel}>Lock Now</Text>
              <Text style={styles.tileHint}>Require MPIN to continue</Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textFaint} />
          </Card>
        </Pressable>

        <Text style={styles.footerNote}>
          All records are stored offline on this device and protected by your 6-digit MPIN.
        </Text>
        <View style={{ height: 20 }} />
      </ScrollView>
    </Screen>
  );
}

function MiniStat({ value, label }: { value: number; label: string }) {
  return (
    <View style={styles.miniStat}>
      <Text style={styles.miniValue}>{value}</Text>
      <Text style={styles.miniLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { padding: 16, paddingBottom: 32 },
  profile: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  avatar: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.navy,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: { fontFamily: fonts.bold, fontSize: 24, color: colors.white },
  name: { fontFamily: fonts.bold, fontSize: 18, color: colors.navyDark },
  school: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, marginTop: 1 },
  statsRow: { flexDirection: 'row', gap: 10, marginVertical: 14 },
  miniStat: {
    flex: 1,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingVertical: 12,
    alignItems: 'center',
  },
  miniValue: { fontFamily: fonts.extrabold, fontSize: 18, color: colors.navyDark },
  miniLabel: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textSoft, marginTop: 2, textAlign: 'center' },
  tile: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 10, padding: 14 },
  tileIcon: {
    width: 42,
    height: 42,
    borderRadius: 14,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tileLabel: { fontFamily: fonts.semibold, fontSize: 14.5, color: colors.navyDark },
  tileHint: { fontFamily: fonts.regular, fontSize: 12, color: colors.textSoft, marginTop: 1 },
  footerNote: {
    fontFamily: fonts.regular,
    fontSize: 11.5,
    color: colors.textFaint,
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 17,
  },
});
