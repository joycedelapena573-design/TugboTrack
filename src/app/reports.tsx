/**
 * Reports & exports (requirements 4.1–4.4): search and review records,
 * generate class record reports, print/save as PDF, and export CSV backups.
 */
import { useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Print from 'expo-print';
import * as Sharing from 'expo-sharing';

import { AppButton, Badge, Card, ChipRow, PageHeader, Screen, Segmented } from '../components/ui';
import { autoBackupDirPath, exportCsvFile, exportFullBackupCsv } from '../lib/backup';
import { formatShortDate } from '../lib/format';
import { computeQuarterGrade } from '../lib/grading';
import {
  buildClassRecordCsv,
  buildClassRecordHtml,
  buildRosterHtml,
} from '../lib/reportHtml';
import { selectBackupData, useStore } from '../lib/store';
import { colors, fonts, radius } from '../lib/theme';
import { QUARTERS, type Quarter } from '../lib/types';

export default function Reports() {
  const router = useRouter();
  const params = useLocalSearchParams<{ sectionId?: string }>();
  const paramSection = typeof params.sectionId === 'string' ? params.sectionId : undefined;

  const state = useStore();
  const sections = Object.values(state.sections).sort((a, b) => a.createdAt - b.createdAt);
  const [sectionId, setSectionId] = useState(paramSection ?? sections[0]?.id ?? '');
  const section = state.sections[sectionId] ?? sections[0];

  const subjectList = Object.values(state.subjects)
    .filter((s) => s.sectionId === (section?.id ?? ''))
    .sort((a, b) => a.createdAt - b.createdAt);
  const [subjectId, setSubjectId] = useState(subjectList[0]?.id ?? '');
  const subject = subjectList.find((s) => s.id === subjectId) ?? subjectList[0];
  const [quarter, setQuarter] = useState<Quarter>(1);
  const [busy, setBusy] = useState('');

  const roster = Object.values(state.students)
    .filter((s) => s.sectionId === (section?.id ?? ''))
    .sort((a, b) => a.seatNumber - b.seatNumber);

  const summary = (() => {
    if (!subject) return null;
    const sheet = state.sheets[`${subject.id}::q${quarter}`];
    const finals = roster
      .map((st) => computeQuarterGrade(subject.weights, subject.transmute, sheet, state.scores, st.id).final)
      .filter((v): v is number => v !== null);
    if (finals.length === 0) return null;
    const avg = finals.reduce((a, b) => a + b, 0) / finals.length;
    return {
      avg,
      high: Math.max(...finals),
      low: Math.min(...finals),
      passed: finals.filter((f) => f >= 75).length,
      total: roster.length,
    };
  })();

  const withBusy = async (label: string, fn: () => Promise<void>) => {
    setBusy(label);
    try {
      await fn();
    } catch (err) {
      Alert.alert('Something went wrong', String(err));
    } finally {
      setBusy('');
    }
  };

  const shareOrWarn = async (uri: string, title: string) => {
    if (await Sharing.isAvailableAsync()) {
      await Sharing.shareAsync(uri, { dialogTitle: title, mimeType: 'text/csv' });
    } else {
      Alert.alert('Sharing unavailable', `Saved to:\n${uri}`);
    }
  };

  const onPrintClassRecord = () =>
    withBusy('print', async () => {
      if (!section || !subject) return;
      const html = buildClassRecordHtml(selectBackupData(state), section, subject, quarter);
      await Print.printAsync({ html });
    });

  const onSavePdf = () =>
    withBusy('pdf', async () => {
      if (!section || !subject) return;
      const html = buildClassRecordHtml(selectBackupData(state), section, subject, quarter);
      const { uri } = await Print.printToFileAsync({ html });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(uri, {
          dialogTitle: 'Save class record PDF',
          mimeType: 'application/pdf',
          UTI: 'com.adobe.pdf',
        });
      } else {
        Alert.alert('PDF created', uri);
      }
    });

  const onExportClassCsv = () =>
    withBusy('csv', async () => {
      if (!section || !subject) return;
      const csv = buildClassRecordCsv(selectBackupData(state), section, subject, quarter);
      const name = `class-record-${subject.name}-Q${quarter}`.replace(/\s+/g, '-');
      const uri = await exportCsvFile(name, csv);
      await shareOrWarn(uri, 'Export class record CSV');
    });

  const onExportRoster = () =>
    withBusy('roster', async () => {
      if (!section) return;
      const html = buildRosterHtml(selectBackupData(state), section.id, section);
      const { uri } = await Print.printToFileAsync({ html });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(uri, { dialogTitle: 'Save roster PDF', mimeType: 'application/pdf', UTI: 'com.adobe.pdf' });
      } else {
        Alert.alert('PDF created', uri);
      }
    });

  const onFullBackup = () =>
    withBusy('backup', async () => {
      const uri = await exportFullBackupCsv(selectBackupData(state));
      await shareOrWarn(uri, 'Full CSV backup');
    });

  const onBackupNow = () =>
    withBusy('auto', async () => {
      const { writeAutoBackups } = await import('../lib/backup');
      await writeAutoBackups(selectBackupData(state));
      Alert.alert('Backup written', `Latest CSV backups saved in:\n${autoBackupDirPath()}`);
    });

  return (
    <Screen edges={['top', 'bottom']}>
      <PageHeader title="Reports & Exports" subtitle="Class records, print, PDF and CSV backups" onBack={() => router.back()} />
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        {sections.length > 1 ? (
          <ChipRow>
            {sections.map((sec) => (
              <Pressable
                key={sec.id}
                onPress={() => setSectionId(sec.id)}
                style={[styles.chip, sec.id === section?.id && styles.chipActive]}
              >
                <Text style={[styles.chipLabel, sec.id === section?.id && { color: colors.white }]}>
                  {sec.gradeLevel.replace('Grade ', 'G')} — {sec.section}
                </Text>
              </Pressable>
            ))}
          </ChipRow>
        ) : null}

        {!section ? (
          <Card style={{ marginTop: 16 }}>
            <Text style={styles.emptyInline}>Create a class first to generate reports.</Text>
          </Card>
        ) : (
          <>
            {subjectList.length > 0 ? (
              <>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
                  {subjectList.map((sub) => (
                    <Pressable
                      key={sub.id}
                      onPress={() => setSubjectId(sub.id)}
                      style={[styles.chip, sub.id === subject?.id && styles.chipActive]}
                    >
                      <Text style={[styles.chipLabel, sub.id === subject?.id && { color: colors.white }]}>
                        {sub.name}
                      </Text>
                    </Pressable>
                  ))}
                </ScrollView>
                <View style={{ marginTop: 10, marginHorizontal: 16 }}>
                  <Segmented
                    options={QUARTERS.map((q) => ({ value: String(q), label: `Q${q}` }))}
                    value={String(quarter)}
                    onChange={(v) => setQuarter(Number(v) as Quarter)}
                  />
                </View>

                <Card style={{ marginTop: 14 }}>
                  <View style={styles.reportHead}>
                    <Text style={styles.reportTitle}>Class Record Preview</Text>
                    {subject.transmute ? <Badge label="Transmuted" color={colors.amber} bg="#FFF1D6" /> : null}
                  </View>
                  <Text style={styles.reportMeta}>
                    {section.gradeLevel} — {section.section} · {subject.name} · Q{quarter} · SY {section.schoolYear}
                  </Text>
                  <Text style={styles.reportMeta}>
                    {roster.length} students · teacher {subject.teacherName || state.teacherName || '—'}
                  </Text>

                  {summary ? (
                    <View style={styles.statsRow}>
                      <Stat label="Average" value={summary.avg.toFixed(1)} />
                      <Stat label="Highest" value={summary.high.toFixed(1)} />
                      <Stat label="Lowest" value={summary.low.toFixed(1)} />
                      <Stat label="Passed" value={`${summary.passed}/${summary.total}`} />
                    </View>
                  ) : (
                    <Text style={styles.emptyInline}>No computed grades yet for this selection.</Text>
                  )}
                </Card>

                <Text style={styles.sectionTitle}>Class Record Actions</Text>
                <View style={styles.actionGrid}>
                  <ActionTile
                    icon="print"
                    label="Print"
                    hint="Direct printer"
                    loading={busy === 'print'}
                    onPress={onPrintClassRecord}
                  />
                  <ActionTile
                    icon="document"
                    label="Save PDF"
                    hint="Share or store"
                    loading={busy === 'pdf'}
                    onPress={onSavePdf}
                  />
                  <ActionTile
                    icon="grid"
                    label="Roster PDF"
                    hint="Names + LRN"
                    loading={busy === 'roster'}
                    onPress={onExportRoster}
                  />
                  <ActionTile
                    icon="grid"
                    label="Class CSV"
                    hint="Grades for Excel"
                    loading={busy === 'csv'}
                    onPress={onExportClassCsv}
                  />
                </View>
              </>
            ) : (
              <Card style={{ marginTop: 16 }}>
                <Text style={styles.emptyInline}>Add a subject to generate a class record report.</Text>
              </Card>
            )}

            <Text style={styles.sectionTitle}>Data Backup</Text>
            <Card>
              <View style={styles.backupRow}>
                <View style={styles.backupIcon}>
                  <Ionicons name="cloud-done" size={20} color={colors.green} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.backupTitle}>Automatic CSV backup</Text>
                  <Text style={styles.backupSub}>
                    Runs after every save (attendance, scores, edits) — latest {formatShortDate(new Date().toISOString().slice(0, 10))}
                  </Text>
                </View>
              </View>
              <View style={styles.actionGrid}>
                <ActionTile
                  icon="refresh"
                  label="Back up now"
                  hint="Rewrite CSV files"
                  loading={busy === 'auto'}
                  onPress={onBackupNow}
                />
                <ActionTile
                  icon="cloud-upload"
                  label="Full backup"
                  hint="Share one CSV"
                  loading={busy === 'backup'}
                  onPress={onFullBackup}
                />
              </View>
              <Text style={styles.pathNote}>Backup folder: {autoBackupDirPath()}</Text>
            </Card>

            <Text style={styles.sectionTitle}>Search Records</Text>
            <Card>
              <Text style={styles.emptyInline}>
                Use the search box inside each class (Students tab) to find a learner by name or LRN, or tap any
                student to open their full profile.
              </Text>
              <AppButton
                label="Go to my classes"
                variant="secondary"
                icon="school"
                onPress={() => router.push('/(main)')}
                style={{ marginTop: 12 }}
              />
            </Card>
            <View style={{ height: 24 }} />
          </>
        )}
      </ScrollView>
    </Screen>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.stat}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

function ActionTile({
  icon,
  label,
  hint,
  onPress,
  loading,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  hint: string;
  onPress: () => void;
  loading?: boolean;
}) {
  return (
    <Pressable style={styles.tile} onPress={onPress} disabled={loading}>
      <View style={styles.tileIcon}>
        {loading ? <ActivityIndicator color={colors.navy} /> : <Ionicons name={icon} size={20} color={colors.navy} />}
      </View>
      <Text style={styles.tileLabel}>{label}</Text>
      <Text style={styles.tileHint}>{hint}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingBottom: 30 },
  chipRow: { paddingHorizontal: 16, gap: 8, paddingVertical: 4 },
  chip: {
    paddingHorizontal: 13,
    paddingVertical: 8,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  chipActive: { backgroundColor: colors.navy, borderColor: colors.navy },
  chipLabel: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.text },
  sectionTitle: { fontFamily: fonts.bold, fontSize: 16, color: colors.navyDark, marginTop: 20, marginBottom: 10, marginLeft: 4 },
  reportHead: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  reportTitle: { fontFamily: fonts.bold, fontSize: 15.5, color: colors.navyDark },
  reportMeta: { fontFamily: fonts.regular, fontSize: 12.5, color: colors.textSoft, marginTop: 3 },
  statsRow: { flexDirection: 'row', marginTop: 14, gap: 8 },
  stat: {
    flex: 1,
    backgroundColor: colors.bg,
    borderRadius: radius.md,
    paddingVertical: 10,
    alignItems: 'center',
  },
  statValue: { fontFamily: fonts.extrabold, fontSize: 16, color: colors.navyDark },
  statLabel: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textSoft },
  actionGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  tile: {
    width: '47.5%',
    backgroundColor: colors.white,
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    padding: 14,
    alignItems: 'flex-start',
    gap: 6,
  },
  tileIcon: {
    width: 40,
    height: 40,
    borderRadius: 14,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tileLabel: { fontFamily: fonts.semibold, fontSize: 14, color: colors.navyDark },
  tileHint: { fontFamily: fonts.regular, fontSize: 11, color: colors.textSoft },
  backupRow: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 14 },
  backupIcon: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: '#DFF5E7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  backupTitle: { fontFamily: fonts.semibold, fontSize: 14, color: colors.navyDark },
  backupSub: { fontFamily: fonts.regular, fontSize: 11.5, color: colors.textSoft, marginTop: 1, lineHeight: 16 },
  pathNote: { fontFamily: fonts.regular, fontSize: 10.5, color: colors.textFaint, marginTop: 12 },
  emptyInline: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, lineHeight: 19, textAlign: 'center' },
});
