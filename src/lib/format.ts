/** Date / name / number formatting helpers (no external deps). */

/** "YYYY-MM-DD" for a Date (local time). */
export function toISODate(d: Date): string {
  const y = d.getFullYear();
  const m = `${d.getMonth() + 1}`.padStart(2, '0');
  const day = `${d.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function todayISO(): string {
  return toISODate(new Date());
}

/** Parse "YYYY-MM-DD" as a local date. Returns null when invalid. */
export function parseISODate(iso: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso ?? '');
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}

const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const MONTHS_SHORT = MONTHS.map((m) => m.slice(0, 3));

/** "October 26, 2026" */
export function formatLongDate(iso: string): string {
  const d = parseISODate(iso);
  if (!d) return iso ?? '';
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

/** "Oct 26, 2026" */
export function formatShortDate(iso: string): string {
  const d = parseISODate(iso);
  if (!d) return iso ?? '';
  return `${MONTHS_SHORT[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

/** "October 26" (no year) for the attendance date bar. */
export function formatDayLabel(iso: string): string {
  const d = parseISODate(iso);
  if (!d) return iso ?? '';
  return `${MONTHS[d.getMonth()]} ${d.getDate()}`;
}

export function addDays(iso: string, delta: number): string {
  const d = parseISODate(iso) ?? new Date();
  d.setDate(d.getDate() + delta);
  return toISODate(d);
}

/** Age in whole years from an ISO birthday to today. */
export function ageFromBirthday(birthdayISO: string): number | null {
  const b = parseISODate(birthdayISO);
  if (!b) return null;
  const now = new Date();
  let age = now.getFullYear() - b.getFullYear();
  const m = now.getMonth() - b.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < b.getDate())) age -= 1;
  return age >= 0 ? age : null;
}

/** Validate + normalize typed birthdays: accepts YYYY-MM-DD or MM/DD/YYYY. */
export function normalizeBirthday(input: string): string | null {
  const raw = (input ?? '').trim();
  if (!raw) return null;
  const slash = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(raw);
  let y: number;
  let m: number;
  let d: number;
  if (slash) {
    m = Number(slash[1]);
    d = Number(slash[2]);
    y = Number(slash[3]);
  } else {
    const iso = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(raw);
    if (!iso) return null;
    y = Number(iso[1]);
    m = Number(iso[2]);
    d = Number(iso[3]);
  }
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) return null;
  const date = new Date(y, m - 1, d);
  if (date.getMonth() !== m - 1 || date.getDate() !== d) return null;
  return toISODate(date);
}

/** "dela Cruz, Juan" -> "JC" style initials for avatars. */
export function initialsOf(fullName: string): string {
  const parts = (fullName ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  const last = parts[parts.length - 1][0] ?? '';
  const first = parts[0][0] ?? '';
  return (first + last).toUpperCase();
}

/** "Juan Dela Cruz" -> "Dela Cruz, Juan" for roster-style lists. */
export function toLastFirst(fullName: string): string {
  const parts = (fullName ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length < 2) return fullName ?? '';
  const last = parts[parts.length - 1];
  return `${last}, ${parts.slice(0, -1).join(' ')}`;
}

export function formatScore(n: number | null | undefined): string {
  if (n === null || n === undefined || Number.isNaN(n)) return '—';
  return Number.isInteger(n) ? `${n}` : n.toFixed(2);
}

export function formatPercent(n: number | null | undefined, digits = 2): string {
  if (n === null || n === undefined || Number.isNaN(n)) return '—';
  return n.toFixed(digits);
}
