/**
 * Grade book (requirement 2): record scores for quizzes, assignments,
 * activities, performance tasks and examinations; grades compute instantly
 * with the subject's weights (and optional DepEd transmutation).
 */
import { useMemo, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';

import { AppButton, Badge, Card, PageHeader, Screen, Segmented } from '../../components/ui';
import {
  achievementLabel,
  computeQuarterGrade,
  gradeRemarks,
} from '../../lib/grading';
import { useStore } from '../../lib/store';
import { colors, fonts, radius, shadow } from '../../lib/theme';
import { COMPONENTS, QUARTERS, type ComponentKey, type Quarter } from '../../lib/types';

export default function Grades() {
  const router = useRouter();
  const params = useLocalSearchParams<{ sectionId?: string; subjectId?: string }>();
  const paramSection = typeof params.sectionId === 'string' ? params.sectionId : undefined;
  const paramSubject = typeof params.subjectId === 'string' ? params.subjectId : undefined;

  const sections = useStore((s) => s.sections);
  const subjects = useStore((s) => s.subjects);
  const students = useStore((s) => s.students);
  const sheets = useStore((s) => s.sheets);
  const scores = useStore((s) => s.scores);
  const addItem = useStore((s) => s.addItem);
  const updateItem = useStore((s) => s.updateItem);
  const deleteItem = useStore((s) => s.deleteItem);
  const setScore = useStore((s) => s.setScore);
  const activeSectionId = useStore((s) => s.activeSectionId);
  const setActiveSection = useStore((s) => s.setActiveSection);

  const sectionList = useMemo(() => Object.values(sections).sort((a, b) => a.createdAt - b.createdAt), [sections]);
  const [sectionId, setSectionId] = useState(paramSection ?? activeSectionId ?? sectionList[0]?.id ?? '');
  const section = sections[sectionId] ?? sectionList[0];

  const subjectList = useMemo(
    () =>
      Object.values(subjects)
        .filter((s) => s.sectionId === (section?.id ?? ''))
        .sort((a, b) => a.createdAt - b.createdAt),
    [subjects, section],
  );
  const [subjectId, setSubjectId] = useState(paramSubject ?? subjectList[0]?.id ?? '');
  const subject = subjectList.find((s) => s.id === subjectId) ?? subjectList[0];

  const [quarter, setQuarter] = useState<Quarter>(1);
  const [component, setComponent] = useState<ComponentKey>('quizzes');
  const [activeItemId, setActiveItemId] = useState<string | null>(null);

  const [itemModal, setItemModal] = useState<null | { itemId?: string; title: string; max: string }>(null);
  const [scoreModal, setScoreModal] = useState<null | { studentId: string; itemId: string; value: string }>(null);

  const roster = useMemo(
    () =>
      Object.values(students)
        .filter((s) => s.sectionId === (section?.id ?? ''))
        .sort((a, b) => a.seatNumber - b.seatNumber),
    [students, section],
  );

  const sheet = subject ? sheets[`${subject.id}::q${quarter}`] : undefined;
  const items = sheet?.items?.[component] ?? [];
  const activeItem = items.find((it) => it.id === activeItemId) ?? items[0];

  const grades = useMemo(() => {
    if (!subject) return [];
    return roster.map((st) => ({
      student: st,
      result: computeQuarterGrade(subject.weights, subject.transmute, sheet, scores, st.id),
    }));
  }, [roster, subject, sheet, scores]);

  const classAverage = useMemo(() => {
    const finals = grades.map((g) => g.result.final).filter((v): v is number => v !== null);
    if (finals.length === 0) return null;
    return finals.reduce((a, b) => a + b, 0) / finals.length;
  }, [grades]);

  if (!section) {
    return (
      <Screen>
        <PageHeader title="Grade Book" subtitle="Create a class first" />
        <View style={styles.emptyWrap}>
          <Ionicons name="stats-chart-outline" size={44} color={colors.textFaint} />
          <AppButton
            label="Create a class"
            onPress={() => router.push('/class/section-form')}
            style={{ marginTop: 12, alignSelf: 'center', minWidth: 220 }}
          />
        </View>
      </Screen>
    );
  }

  const openItemModal = (itemId?: string) => {
    const item = itemId ? items.find((it) => it.id === itemId) : undefined;
    setItemModal({ itemId, title: item?.title ?? '', max: item ? String(item.max) : '' });
  };

  const saveItem = () => {
    if (!itemModal || !subject) return;
    const title = itemModal.title.trim();
    const max = Number(itemModal.max);
    if (!title || !(max > 0)) return;
    if (itemModal.itemId) {
      updateItem(subject.id, quarter, component, itemModal.itemId, { title, max });
    } else {
      addItem(subject.id, quarter, component, title, max);
    }
    setItemModal(null);
  };

  const removeItem = (itemId: string, title: string) => {
    if (!subject) return;
    deleteItem(subject.id, quarter, component, itemId);
    if (activeItemId === itemId) setActiveItemId(null);
    void title;
  };

  const saveScore = () => {
    if (!scoreModal || !sheet) return;
    const raw = scoreModal.value.trim();
    const value = raw === '' ? null : Number(raw);
    if (value !== null && Number.isNaN(value)) return;
    setScore(sheet.id, scoreModal.studentId, scoreModal.itemId, value);
    setScoreModal(null);
  };

  return (
    <Screen>
      <PageHeader title="Grade Book" subtitle={`${section.gradeLevel} — ${section.section} · SY ${section.schoolYear}`} />

      {sectionList.length > 1 ? (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
          {sectionList.map((sec) => (
            <Pressable
              key={sec.id}
              onPress={() => {
                setSectionId(sec.id);
                setActiveSection(sec.id);
                setSubjectId('');
              }}
              style={[styles.chip, sec.id === section?.id && styles.chipActive]}
            >
              <Text style={[styles.chipLabel, sec.id === section?.id && { color: colors.white }]}>
                {sec.gradeLevel.replace('Grade ', 'G')} — {sec.section}
              </Text>
            </Pressable>
          ))}
        </ScrollView>
      ) : null}

      {subjectList.length === 0 ? (
        <View style={styles.emptyWrap}>
          <Ionicons name="book-outline" size={44} color={colors.textFaint} />
          <Text style={styles.emptyText}>
            Add the subjects you teach for this class to start recording grades.
          </Text>
          <AppButton
            label="Add Subject"
            icon="add"
            onPress={() => router.push({ pathname: '/subject/form', params: { sectionId: section.id } })}
            style={{ alignSelf: 'center', minWidth: 220 }}
          />
        </View>
      ) : (
        <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false} keyboardShouldPersistTaps="handled">
          {/* Subject picker */}
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
            {subjectList.map((sub) => (
              <Pressable
                key={sub.id}
                onPress={() => {
                  setSubjectId(sub.id);
                  setActiveItemId(null);
                }}
                style={[styles.chip, sub.id === subject?.id && styles.chipActive]}
              >
                <Text style={[styles.chipLabel, sub.id === subject?.id && { color: colors.white }]}>{sub.name}</Text>
              </Pressable>
            ))}
            <Pressable
              style={styles.chipAdd}
              onPress={() => router.push({ pathname: '/subject/form', params: { sectionId: section.id } })}
            >
              <Ionicons name="add" size={16} color={colors.navy} />
            </Pressable>
          </ScrollView>

          {subject ? (
            <>
              <View style={{ marginTop: 12 }}>
                <Segmented
                  options={QUARTERS.map((q) => ({ value: String(q), label: `Q${q}` }))}
                  value={String(quarter)}
                  onChange={(v) => {
                    setQuarter(Number(v) as Quarter);
                    setActiveItemId(null);
                  }}
                />
              </View>

              <Pressable
                style={styles.weightsNote}
                onPress={() => router.push({ pathname: '/subject/form', params: { subjectId: subject.id } })}
              >
                <Ionicons name="options-outline" size={15} color={colors.textSoft} />
                <Text style={styles.weightsNoteText}>
                  Weights: Quiz {subject.weights.quizzes}% · Assign {subject.weights.assignments}% · Act{' '}
                  {subject.weights.activities}% · PT {subject.weights.performanceTasks}% · Exam{' '}
                  {subject.weights.examinations}%{subject.transmute ? ' · transmuted' : ''} — tap to edit
                </Text>
              </Pressable>

              {/* Component tabs */}
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
                {COMPONENTS.map((c) => (
                  <Pressable
                    key={c.key}
                    onPress={() => {
                      setComponent(c.key);
                      setActiveItemId(null);
                    }}
                    style={[styles.chip, c.key === component && styles.chipActive]}
                  >
                    <Text style={[styles.chipLabel, c.key === component && { color: colors.white }]}>{c.short}</Text>
                  </Pressable>
                ))}
              </ScrollView>

              {/* Items */}
              <View style={styles.itemsRow}>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
                  {items.map((item) => (
                    <Pressable
                      key={item.id}
                      onPress={() => setActiveItemId(item.id)}
                      onLongPress={() => openItemModal(item.id)}
                      style={[styles.itemChip, item.id === activeItem?.id && styles.itemChipActive]}
                    >
                      <Text style={[styles.itemChipLabel, item.id === activeItem?.id && { color: colors.white }]}>
                        {item.title} · {item.max}
                      </Text>
                    </Pressable>
                  ))}
                  <Pressable style={styles.itemAdd} onPress={() => openItemModal()}>
                    <Ionicons name="add" size={15} color={colors.navy} />
                    <Text style={styles.itemAddLabel}>Add {COMPONENTS.find((c) => c.key === component)?.short}</Text>
                  </Pressable>
                </ScrollView>
              </View>

              {/* Score entry */}
              {items.length === 0 ? (
                <Card style={{ marginTop: 12 }}>
                  <Text style={styles.emptyInline}>
                    No {COMPONENTS.find((c) => c.key === component)?.label.toLowerCase()} added for Q{quarter} yet.
                    Tap “Add” to create the first item (e.g. “Quiz 1” out of 20).
                  </Text>
                </Card>
              ) : (
                <Card style={{ marginTop: 12, padding: 0, overflow: 'hidden' }}>
                  <View style={styles.tableHead}>
                    <Text style={[styles.thName]}>Student</Text>
                    {items.slice(0, 4).map((it) => (
                      <Text key={it.id} style={styles.thItem} numberOfLines={2}>
                        {it.title.replace(/\s+/g, '')}
                        {'\n'}/{it.max}
                      </Text>
                    ))}
                    <Text style={styles.thTotal}>%</Text>
                  </View>
                  {roster.map((st) => {
                    const comp = (sheet
                      ? computeQuarterGrade(subject.weights, subject.transmute, sheet, scores, st.id).components[component]
                      : null) ?? null;
                    return (
                      <Pressable
                        key={st.id}
                        style={styles.tr}
                        onPress={() =>
                          activeItem &&
                          setScoreModal({
                            studentId: st.id,
                            itemId: activeItem.id,
                            value:
                              typeof scores[`${sheet?.id}|${st.id}|${activeItem.id}`] === 'number'
                                ? String(scores[`${sheet?.id}|${st.id}|${activeItem.id}`])
                                : '',
                          })
                        }
                      >
                        <View style={{ flexShrink: 1, width: 108 }}>
                          <Text style={styles.tdName} numberOfLines={1}>
                            {st.seatNumber}. {st.fullName.split(' ').slice(-1)[0]}
                          </Text>
                          <Text style={styles.tdSub} numberOfLines={1}>
                            {st.fullName}
                          </Text>
                        </View>
                        {items.slice(0, 4).map((it) => {
                          const v = scores[`${sheet?.id}|${st.id}|${it.id}`];
                          const isActive = activeItem?.id === it.id;
                          return (
                            <View key={it.id} style={styles.tdItemWrap}>
                              <Text style={[styles.tdItem, isActive && { color: colors.blue, textDecorationLine: 'underline' }]}>
                                {typeof v === 'number' ? v : '–'}
                              </Text>
                            </View>
                          );
                        })}
                        <Text style={styles.tdTotal}>
                          {comp?.percentage !== null && comp?.percentage !== undefined
                            ? comp.percentage.toFixed(0)
                            : '–'}
                        </Text>
                      </Pressable>
                    );
                  })}
                  <Text style={styles.tableHint}>
                    Tap a row to score the highlighted item{items.length > 4 ? ' (showing first 4 items)' : ''}.
                  </Text>
                </Card>
              )}

              {/* Computed grades */}
              <View style={styles.sectionRow}>
                <Text style={styles.sectionTitle}>Quarterly Grades — Q{quarter}</Text>
                {classAverage !== null ? (
                  <Badge label={`Avg ${classAverage.toFixed(1)}`} color={colors.navy} bg={colors.ice} />
                ) : null}
              </View>
              <Card style={{ padding: 0, overflow: 'hidden' }}>
                <View style={styles.tableHead}>
                  <Text style={styles.thName}>Student</Text>
                  <Text style={[styles.thItem, { flex: 0, width: 54 }]}>WW</Text>
                  <Text style={[styles.thItem, { flex: 0, width: 44 }]}>PT</Text>
                  <Text style={[styles.thItem, { flex: 0, width: 46 }]}>QA</Text>
                  <Text style={styles.thTotal}>Grade</Text>
                </View>
                {grades.map(({ student: st, result }) => {
                  const ww =
                    [result.components.quizzes, result.components.assignments, result.components.activities]
                      .map((c) => c.percentage)
                      .filter((v): v is number => v !== null);
                  const wwPct = ww.length ? ww.reduce((a, b) => a + b, 0) / ww.length : null;
                  const ptPct = result.components.performanceTasks.percentage;
                  const qaPct = result.components.examinations.percentage;
                  const remarks = gradeRemarks(result.final);
                  return (
                    <Pressable
                      key={st.id}
                      style={styles.tr}
                      onPress={() => router.push({ pathname: '/student/[id]', params: { id: st.id } })}
                    >
                      <View style={{ flexShrink: 1, width: 108 }}>
                        <Text style={styles.tdName} numberOfLines={1}>
                          {st.seatNumber}. {st.fullName.split(' ').slice(-1)[0]}
                        </Text>
                        {remarks ? (
                          <Text style={styles.tdRemarks} numberOfLines={1}>
                            {remarks}
                          </Text>
                        ) : (
                          <Text style={styles.tdSub} numberOfLines={1}>
                            {achievementLabel(result.final)}
                          </Text>
                        )}
                      </View>
                      <Text style={[styles.tdItem, { flex: 0, width: 54 }]}>{wwPct !== null ? wwPct.toFixed(0) : '–'}</Text>
                      <Text style={[styles.tdItem, { flex: 0, width: 44 }]}>{ptPct !== null ? ptPct.toFixed(0) : '–'}</Text>
                      <Text style={[styles.tdItem, { flex: 0, width: 46 }]}>{qaPct !== null ? qaPct.toFixed(0) : '–'}</Text>
                      <Text style={[styles.tdTotal, { color: result.final !== null && result.final < 75 ? colors.red : colors.navyDark }]}>
                        {result.final !== null ? result.final.toFixed(1) : '–'}
                      </Text>
                    </Pressable>
                  );
                })}
                {grades.length === 0 ? (
                  <Text style={styles.emptyInline}>Add students to this class to see grades.</Text>
                ) : null}
              </Card>
              <Text style={styles.autoNote}>
                Grades are computed automatically from recorded scores and saved on this device.
              </Text>
              <View style={{ height: 24 }} />
            </>
          ) : null}
        </ScrollView>
      )}

      {/* Item editor modal */}
      <Modal visible={itemModal !== null} transparent animationType="fade" onRequestClose={() => setItemModal(null)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>{itemModal?.itemId ? 'Edit Item' : `New ${COMPONENTS.find((c) => c.key === component)?.label.replace(/s$/, '')}`}</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="Title (e.g. Quiz 1)"
              placeholderTextColor={colors.textFaint}
              value={itemModal?.title ?? ''}
              onChangeText={(t) => setItemModal((m) => (m ? { ...m, title: t } : m))}
            />
            <TextInput
              style={styles.modalInput}
              placeholder="Highest score (e.g. 20)"
              placeholderTextColor={colors.textFaint}
              keyboardType="numeric"
              value={itemModal?.max ?? ''}
              onChangeText={(t) => setItemModal((m) => (m ? { ...m, max: t.replace(/\D/g, '') } : m))}
            />
            <View style={{ flexDirection: 'row', gap: 10 }}>
              {itemModal?.itemId ? (
                <AppButton
                  label="Delete"
                  variant="danger"
                  onPress={() => {
                    if (itemModal.itemId) removeItem(itemModal.itemId, itemModal.title);
                    setItemModal(null);
                  }}
                  style={{ flex: 1 }}
                />
              ) : null}
              <AppButton label="Cancel" variant="ghost" onPress={() => setItemModal(null)} style={{ flex: 1 }} />
              <AppButton label="Save" onPress={saveItem} style={{ flex: 1 }} />
            </View>
          </View>
        </View>
      </Modal>

      {/* Score modal */}
      <Modal visible={scoreModal !== null} transparent animationType="fade" onRequestClose={() => setScoreModal(null)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            {(() => {
              const st = roster.find((s) => s.id === scoreModal?.studentId);
              const it = items.find((i) => i.id === scoreModal?.itemId);
              return (
                <>
                  <Text style={styles.modalTitle}>{st?.fullName}</Text>
                  <Text style={styles.modalSub}>
                    {it?.title} — highest score {it?.max}
                  </Text>
                  <TextInput
                    style={[styles.modalInput, { textAlign: 'center', fontSize: 24, fontFamily: fonts.bold }]}
                    placeholder="0"
                    placeholderTextColor={colors.textFaint}
                    keyboardType="numeric"
                    value={scoreModal?.value ?? ''}
                    onChangeText={(t) => setScoreModal((m) => (m ? { ...m, value: t.replace(/[^0-9.]/g, '') } : m))}
                    autoFocus
                  />
                  <View style={{ flexDirection: 'row', gap: 10 }}>
                    <AppButton
                      label="Clear"
                      variant="ghost"
                      onPress={() => {
                        if (scoreModal && sheet) setScore(sheet.id, scoreModal.studentId, scoreModal.itemId, null);
                        setScoreModal(null);
                      }}
                      style={{ flex: 1 }}
                    />
                    <AppButton
                      label="Save Score"
                      onPress={() => {
                        Haptics.selectionAsync().catch(() => {});
                        saveScore();
                      }}
                      style={{ flex: 1 }}
                    />
                  </View>
                </>
              );
            })()}
          </View>
        </View>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingBottom: 24 },
  emptyWrap: { alignItems: 'center', padding: 32, gap: 10 },
  emptyText: {
    fontFamily: fonts.medium,
    fontSize: 14,
    color: colors.textSoft,
    textAlign: 'center',
    lineHeight: 21,
    paddingHorizontal: 12,
  },
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
  chipAdd: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: colors.ice,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1.5,
    borderColor: colors.border,
  },
  weightsNote: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginHorizontal: 16,
    marginTop: 10,
    backgroundColor: colors.ice,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  weightsNoteText: { fontFamily: fonts.medium, fontSize: 11, color: colors.textSoft, flex: 1 },
  itemsRow: { marginTop: 12, paddingLeft: 16 },
  itemChip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.border,
    backgroundColor: colors.white,
  },
  itemChipActive: { backgroundColor: colors.blue, borderColor: colors.blue },
  itemChipLabel: { fontFamily: fonts.semibold, fontSize: 12, color: colors.text },
  itemAdd: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: colors.blue,
    backgroundColor: colors.ice,
  },
  itemAddLabel: { fontFamily: fonts.semibold, fontSize: 12, color: colors.navy },
  tableHead: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.ice,
    paddingVertical: 9,
    paddingHorizontal: 12,
    gap: 6,
  },
  thName: { flex: 1, fontFamily: fonts.bold, fontSize: 11.5, color: colors.navyDark, width: 108 },
  thItem: {
    flex: 0,
    width: 44,
    fontFamily: fonts.bold,
    fontSize: 10,
    color: colors.navyDark,
    textAlign: 'center',
  },
  thTotal: { flex: 0, width: 44, fontFamily: fonts.bold, fontSize: 11.5, color: colors.navyDark, textAlign: 'center' },
  tr: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 9,
    paddingHorizontal: 12,
    borderBottomWidth: 1,
    borderBottomColor: colors.bg,
    gap: 6,
  },
  tdName: { fontFamily: fonts.semibold, fontSize: 12.5, color: colors.navyDark },
  tdSub: { fontFamily: fonts.regular, fontSize: 10, color: colors.textFaint },
  tdRemarks: { fontFamily: fonts.semibold, fontSize: 9.5, color: colors.green },
  tdItemWrap: { flex: 0, width: 40, alignItems: 'center' },
  tdItem: { fontFamily: fonts.medium, fontSize: 12.5, color: colors.text, textAlign: 'center' },
  tdTotal: { flex: 0, width: 44, fontFamily: fonts.bold, fontSize: 13, color: colors.navyDark, textAlign: 'center' },
  tableHint: {
    fontFamily: fonts.regular,
    fontSize: 10.5,
    color: colors.textFaint,
    textAlign: 'center',
    paddingVertical: 8,
  },
  sectionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 18,
    marginBottom: 10,
    marginHorizontal: 16,
  },
  sectionTitle: { fontFamily: fonts.bold, fontSize: 15.5, color: colors.navyDark },
  autoNote: {
    fontFamily: fonts.regular,
    fontSize: 11,
    color: colors.textFaint,
    textAlign: 'center',
    marginTop: 10,
    marginHorizontal: 16,
  },
  emptyInline: {
    fontFamily: fonts.regular,
    fontSize: 12.5,
    color: colors.textSoft,
    lineHeight: 18,
    padding: 14,
    textAlign: 'center',
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(8, 30, 74, 0.45)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  modalCard: {
    width: '100%',
    maxWidth: 400,
    backgroundColor: colors.white,
    borderRadius: radius.lg,
    padding: 18,
    gap: 10,
    ...shadow.card,
  },
  modalTitle: { fontFamily: fonts.bold, fontSize: 17, color: colors.navyDark },
  modalSub: { fontFamily: fonts.regular, fontSize: 13, color: colors.textSoft, marginBottom: 4 },
  modalInput: {
    borderWidth: 1.5,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontFamily: fonts.medium,
    fontSize: 15,
    color: colors.text,
  },
});
