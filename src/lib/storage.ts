/**
 * On-device persistence: app records and the salted MPIN hash.
 * Everything lives in AsyncStorage so records stay private to the device.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Crypto from 'expo-crypto';

import { EMPTY_DATA, type AppData } from './types';

const DATA_KEY = '@classrecords/data/v1';
const MPIN_KEY = '@classrecords/mpin/v1';

export const MPIN_LENGTH = 6;

export interface MpinRecord {
  salt: string;
  hash: string;
  /** 4 or 6, chosen when the MPIN was first registered. */
  length: number;
  createdAt: number;
}

/** MPINs are 4-6 digits, like a mobile banking PIN. */
export function isValidMpin(pin: string): boolean {
  return /^[0-9]{4,6}$/.test(pin);
}

async function hash(pin: string, salt: string): Promise<string> {
  return Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    `${salt}::classrecords::${pin}`,
  );
}

export async function loadData(): Promise<AppData> {
  try {
    const raw = await AsyncStorage.getItem(DATA_KEY);
    if (!raw) return { ...EMPTY_DATA };
    const parsed = JSON.parse(raw) as AppData;
    return {
      version: parsed.version ?? 1,
      classes: Array.isArray(parsed.classes) ? parsed.classes : [],
      students: Array.isArray(parsed.students) ? parsed.students : [],
      assessments: Array.isArray(parsed.assessments) ? parsed.assessments : [],
    };
  } catch {
    return { ...EMPTY_DATA };
  }
}

export async function saveData(data: AppData): Promise<void> {
  try {
    await AsyncStorage.setItem(DATA_KEY, JSON.stringify(data));
  } catch {
    // A failed write should never crash the UI; the in-memory copy stays correct.
  }
}

export async function loadMpin(): Promise<MpinRecord | null> {
  try {
    const raw = await AsyncStorage.getItem(MPIN_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as MpinRecord;
    if (!parsed?.salt || !parsed?.hash) return null;
    return { ...parsed, length: parsed.length === 4 ? 4 : 6 };
  } catch {
    return null;
  }
}

/** First run: create a salt and store only the hash of the new MPIN. */
export async function createMpin(pin: string, length: number): Promise<MpinRecord> {
  const salt = Crypto.randomUUID();
  const record: MpinRecord = {
    salt,
    hash: await hash(pin, salt),
    length,
    createdAt: Date.now(),
  };
  await AsyncStorage.setItem(MPIN_KEY, JSON.stringify(record));
  return record;
}

export async function verifyMpin(pin: string, record: MpinRecord): Promise<boolean> {
  const candidate = await hash(pin, record.salt);
  return candidate === record.hash;
}