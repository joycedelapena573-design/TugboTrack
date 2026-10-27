/** 6-digit MPIN security: salted SHA-256 stored in the device keychain. */
import * as Crypto from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';

const KEY = 'tis-mpin-credential';
const MAX_ATTEMPTS = 5;
const LOCK_MS = 30_000;

export const MPIN_LENGTH = 6;

interface Credential {
  hash: string;
  salt: string;
  attempts: number;
  lockedUntil: number;
}

export function isValidMpin(pin: string): boolean {
  return /^\d{6}$/.test(pin ?? '');
}

async function randomSalt(): Promise<string> {
  const bytes = await Crypto.getRandomBytesAsync(16);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function hashPin(pin: string, salt: string): Promise<string> {
  return Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, `${salt}:${pin}`);
}

async function readCredential(): Promise<Credential | null> {
  const raw = await SecureStore.getItemAsync(KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<Credential>;
    if (typeof parsed.hash === 'string' && typeof parsed.salt === 'string') {
      return {
        ...parsed,
        hash: parsed.hash,
        salt: parsed.salt,
        attempts: typeof parsed.attempts === 'number' ? parsed.attempts : 0,
        lockedUntil: typeof parsed.lockedUntil === 'number' ? parsed.lockedUntil : 0,
      };
    }
  } catch {
    // corrupted credential — treat as unset
  }
  return null;
}

async function writeCredential(cred: Credential): Promise<void> {
  await SecureStore.setItemAsync(KEY, JSON.stringify(cred));
}

export async function hasMpin(): Promise<boolean> {
  return (await readCredential()) !== null;
}

/** Create (or replace) the stored MPIN. */
export async function createMpin(pin: string): Promise<void> {
  const salt = await randomSalt();
  const hash = await hashPin(pin, salt);
  await writeCredential({ hash, salt, attempts: 0, lockedUntil: 0 });
}

/** Remaining lockout time after too many wrong attempts (0 when not locked). */
export async function lockoutRemainingMs(): Promise<number> {
  const cred = await readCredential();
  if (!cred) return 0;
  return Math.max(0, cred.lockedUntil - Date.now());
}

export type VerifyResult =
  | { ok: true }
  | { ok: false; reason: 'wrong'; attemptsLeft: number }
  | { ok: false; reason: 'locked'; retryInMs: number }
  | { ok: false; reason: 'unset' };

export async function verifyMpin(pin: string): Promise<VerifyResult> {
  const cred = await readCredential();
  if (!cred) return { ok: false, reason: 'unset' };
  const lockedFor = cred.lockedUntil - Date.now();
  if (lockedFor > 0) return { ok: false, reason: 'locked', retryInMs: lockedFor };

  const hash = await hashPin(pin, cred.salt);
  if (hash === cred.hash) {
    if (cred.attempts !== 0 || cred.lockedUntil !== 0) {
      await writeCredential({ ...cred, attempts: 0, lockedUntil: 0 });
    }
    return { ok: true };
  }

  const attempts = cred.attempts + 1;
  const lockedUntil = attempts >= MAX_ATTEMPTS ? Date.now() + LOCK_MS : 0;
  await writeCredential({ ...cred, attempts: lockedUntil ? 0 : attempts, lockedUntil });
  return lockedUntil
    ? { ok: false, reason: 'locked', retryInMs: LOCK_MS }
    : { ok: false, reason: 'wrong', attemptsLeft: MAX_ATTEMPTS - attempts };
}

/** Verify the old MPIN, then replace it with a new one. */
export async function changeMpin(oldPin: string, newPin: string): Promise<VerifyResult> {
  const result = await verifyMpin(oldPin);
  if (!result.ok) return result;
  await createMpin(newPin);
  return { ok: true };
}
