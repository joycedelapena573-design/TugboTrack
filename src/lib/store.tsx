/**
 * App-wide state: loads persisted records on boot, owns every mutation, and
 * persists back to AsyncStorage after each change. Also owns MPIN lock state.
 */
import * as Crypto from 'expo-crypto';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { DEFAULT_WEIGHTS } from './grades';
import {
  createMpin,
  loadMpin,
  loadData,
  saveData,
  verifyMpin,
  type MpinRecord,
} from './storage';
import type {
  AppData,
  Assessment,
  AssessmentType,
  ClassRecord,
  GradingComponent,
  Student,
  Weights,
} from './types';
import { EMPTY_DATA } from './types';

export interface StoreValue {
  /** True once storage has been read, so routes can decide where to send the user. */
  ready: boolean;
  /** True when this device has an MPIN registered. */
  hasMpin: boolean;
  /** True after the correct MPIN has been entered this session. */
  unlocked: boolean;
  data: AppData;

  registerMpin: (pin: string, length: number) => Promise<void>;
  unlock: (pin: string) => Promise<boolean>;
  /** Digit count chosen at registration; 6 until an MPIN exists. */
  mpinLength: number;
  mpinError: string | null;
  clearMpinError: () => void;

  addClass: (input: {
    subject: string;
    section: string;
    gradeLevel: string;
    schoolYear: string;
    presetKey: string;
    weights: Weights;
  }) => void;
  importClasses: (rows: { subject: string; section: string; gradeLevel: string }[]) => number;
  updateClass: (
    id: string,
    patch: Partial<Pick<ClassRecord, 'subject' | 'section' | 'gradeLevel' | 'schoolYear' | 'presetKey' | 'weights'>>,
  ) => void;
  deleteClass: (id: string) => void;

  addStudent: (classId: string, name: string, section: string) => void;
  importStudents: (classId: string, rows: { name: string; section: string }[]) => number;
  updateStudent: (id: string, patch: Partial<Pick<Student, 'name' | 'section' | 'heightCm' | 'weightKg'>>) => void;
  deleteStudent: (id: string) => void;

  addAssessment: (
    classId: string,
    input: { title: string; type: AssessmentType; component: GradingComponent; maxScore: number; date: string },
  ) => void;
  updateAssessment: (id: string, patch: Partial<Assessment>) => void;
  deleteAssessment: (id: string) => void;
  setScore: (assessmentId: string, studentId: string, value: number | null) => void;

  studentsOf: (classId: string) => Student[];
  assessmentsOf: (classId: string) => Assessment[];
}

const StoreContext = createContext<StoreValue | null>(null);

const uid = () => Crypto.randomUUID();

export function StoreProvider({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  const [data, setData] = useState<AppData>(EMPTY_DATA);
  const [mpin, setMpin] = useState<MpinRecord | null>(null);
  const [unlocked, setUnlocked] = useState(false);
  const [mpinError, setMpinError] = useState<string | null>(null);

  // Initial load.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const [loaded, record] = await Promise.all([loadData(), loadMpin()]);
      if (cancelled) return;
      setData(loaded);
      setMpin(record);
      setReady(true);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // Persist whenever records change (skipped until the first read finishes).
  useEffect(() => {
    if (!ready) return;
    void saveData(data);
  }, [data, ready]);

  const registerMpin = useCallback(async (pin: string, length: number) => {
    const record = await createMpin(pin, length);
    setMpin(record);
    setUnlocked(true);
    setMpinError(null);
  }, []);

  const unlock = useCallback(
    async (pin: string) => {
      if (!mpin) return false;
      const ok = await verifyMpin(pin, mpin);
      if (ok) {
        setUnlocked(true);
        setMpinError(null);
      } else {
        setMpinError('Incorrect MPIN. Please try again.');
      }
      return ok;
    },
    [mpin],
  );

  const addClass: StoreValue['addClass'] = useCallback((input) => {
    setData((prev) => ({
      ...prev,
      classes: [
        {
          id: uid(),
          subject: input.subject.trim(),
          section: input.section.trim(),
          gradeLevel: input.gradeLevel.trim(),
          schoolYear: input.schoolYear.trim(),
          presetKey: input.presetKey,
          weights: input.weights,
          createdAt: Date.now(),
        },
        ...prev.classes,
      ],
    }));
  }, []);

  const importClasses: StoreValue['importClasses'] = useCallback((rows) => {
    let added = 0;
    setData((prev) => {
      const classes = [...prev.classes];
      for (const row of rows) {
        const subject = row.subject.trim();
        if (!subject) continue;
        const section = row.section.trim();
        const exists = classes.some(
          (c) => c.subject.toLowerCase() === subject.toLowerCase() && c.section.toLowerCase() === section.toLowerCase(),
        );
        if (exists) continue;
        classes.unshift({
          id: uid(),
          subject,
          section,
          gradeLevel: row.gradeLevel.trim(),
          schoolYear: '',
          presetKey: 'math_science',
          weights: DEFAULT_WEIGHTS,
          createdAt: Date.now(),
        });
        added += 1;
      }
      return { ...prev, classes };
    });
    return added;
  }, []);

  const updateClass: StoreValue['updateClass'] = useCallback((id, patch) => {
    setData((prev) => ({
      ...prev,
      classes: prev.classes.map((c) => (c.id === id ? { ...c, ...patch } : c)),
    }));
  }, []);

  const deleteClass: StoreValue['deleteClass'] = useCallback((id) => {
    setData((prev) => ({
      ...prev,
      classes: prev.classes.filter((c) => c.id !== id),
      students: prev.students.filter((s) => s.classId !== id),
      assessments: prev.assessments.filter((a) => a.classId !== id),
    }));
  }, []);

  const addStudent: StoreValue['addStudent'] = useCallback((classId, name, section) => {
    setData((prev) => ({
      ...prev,
      students: [
        ...prev.students,
        {
          id: uid(),
          classId,
          name: name.trim(),
          section: section.trim(),
          heightCm: null,
          weightKg: null,
          createdAt: Date.now(),
        },
      ],
    }));
  }, []);

  const importStudents: StoreValue['importStudents'] = useCallback((classId, rows) => {
    let added = 0;
    setData((prev) => {
      const existing = new Set(
        prev.students
          .filter((s) => s.classId === classId)
          .map((s) => `${s.name.trim().toLowerCase()}|${s.section.trim().toLowerCase()}`),
      );
      const students = [...prev.students];
      for (const row of rows) {
        const name = row.name.trim();
        if (!name) continue;
        const section = row.section.trim();
        const key = `${name.toLowerCase()}|${section.toLowerCase()}`;
        if (existing.has(key)) continue;
        existing.add(key);
        students.push({
          id: uid(),
          classId,
          name,
          section,
          heightCm: null,
          weightKg: null,
          createdAt: Date.now(),
        });
        added += 1;
      }
      return { ...prev, students };
    });
    return added;
  }, []);

  const updateStudent: StoreValue['updateStudent'] = useCallback((id, patch) => {
    setData((prev) => ({
      ...prev,
      students: prev.students.map((s) => (s.id === id ? { ...s, ...patch } : s)),
    }));
  }, []);

  const deleteStudent: StoreValue['deleteStudent'] = useCallback((id) => {
    setData((prev) => {
      const students = prev.students.filter((s) => s.id !== id);
      const assessments = prev.assessments.map((a) => {
        if (!(id in a.scores)) return a;
        const scores = { ...a.scores };
        delete scores[id];
        return { ...a, scores };
      });
      return { ...prev, students, assessments };
    });
  }, []);

  const addAssessment: StoreValue['addAssessment'] = useCallback((classId, input) => {
    setData((prev) => ({
      ...prev,
      assessments: [
        {
          id: uid(),
          classId,
          title: input.title.trim(),
          type: input.type,
          component: input.component,
          maxScore: input.maxScore,
          date: input.date,
          scores: {},
          createdAt: Date.now(),
        },
        ...prev.assessments,
      ],
    }));
  }, []);

  const updateAssessment: StoreValue['updateAssessment'] = useCallback((id, patch) => {
    setData((prev) => ({
      ...prev,
      assessments: prev.assessments.map((a) => (a.id === id ? { ...a, ...patch } : a)),
    }));
  }, []);

  const deleteAssessment: StoreValue['deleteAssessment'] = useCallback((id) => {
    setData((prev) => ({ ...prev, assessments: prev.assessments.filter((a) => a.id !== id) }));
  }, []);

  const setScore: StoreValue['setScore'] = useCallback((assessmentId, studentId, value) => {
    setData((prev) => ({
      ...prev,
      assessments: prev.assessments.map((a) => {
        if (a.id !== assessmentId) return a;
        const scores = { ...a.scores };
        if (value === null) delete scores[studentId];
        else scores[studentId] = value;
        return { ...a, scores };
      }),
    }));
  }, []);

  const studentsOf = useCallback(
    (classId: string) => data.students.filter((s) => s.classId === classId),
    [data.students],
  );

  const assessmentsOf = useCallback(
    (classId: string) => data.assessments.filter((a) => a.classId === classId),
    [data.assessments],
  );

  const mpinLength = mpin?.length ?? 6;

  const value = useMemo<StoreValue>(
    () => ({
      ready,
      hasMpin: mpin !== null,
      unlocked,
      data,
      registerMpin,
      unlock,
      mpinLength,
      mpinError,
      clearMpinError: () => setMpinError(null),
      addClass,
      importClasses,
      updateClass,
      deleteClass,
      addStudent,
      importStudents,
      updateStudent,
      deleteStudent,
      addAssessment,
      updateAssessment,
      deleteAssessment,
      setScore,
      studentsOf,
      assessmentsOf,
    }),
    [
      ready,
      mpin,
      unlocked,
      data,
      registerMpin,
      unlock,
      mpinLength,
      mpinError,
      addClass,
      importClasses,
      updateClass,
      deleteClass,
      addStudent,
      importStudents,
      updateStudent,
      deleteStudent,
      addAssessment,
      updateAssessment,
      deleteAssessment,
      setScore,
      studentsOf,
      assessmentsOf,
    ],
  );

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

export function useStore(): StoreValue {
  const value = useContext(StoreContext);
  if (!value) throw new Error('useStore must be used inside <StoreProvider>');
  return value;
}