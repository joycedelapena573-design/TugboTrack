/** Tiny CSV serializer/parser + student-list import mapping. */

/** Serialize rows (arrays of primitives) to CSV text (RFC-style quoting, CRLF). */
export function toCsv(rows: (string | number | null | undefined)[][]): string {
  return rows
    .map((row) =>
      row
        .map((cell) => {
          if (cell === null || cell === undefined) return '';
          const s = String(cell);
          return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
        })
        .join(','),
    )
    .join('\r\n');
}

/** Parse CSV text (handles quoted fields, embedded commas/newlines, BOM). */
export function parseCsv(text: string): string[][] {
  const src = text.replace(/^\uFEFF/, '');
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;
  let i = 0;
  const pushField = () => {
    row.push(field);
    field = '';
  };
  const pushRow = () => {
    pushField();
    if (row.length > 1 || row[0] !== '') rows.push(row);
    row = [];
  };
  while (i < src.length) {
    const ch = src[i];
    if (inQuotes) {
      if (ch === '"') {
        if (src[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      field += ch;
      i += 1;
      continue;
    }
    if (ch === '"') {
      inQuotes = true;
      i += 1;
      continue;
    }
    if (ch === ',') {
      pushField();
      i += 1;
      continue;
    }
    if (ch === '\r') {
      i += 1;
      continue;
    }
    if (ch === '\n') {
      pushRow();
      i += 1;
      continue;
    }
    field += ch;
    i += 1;
  }
  if (field !== '' || row.length > 0) pushRow();
  return rows;
}

export interface StudentImportRow {
  fullName: string;
  lrn: string;
  gender: string;
  birthday: string;
  guardianName: string;
  guardianContact: string;
  seatNumber: number | null;
}

const HEADER_ALIASES: Record<keyof Omit<StudentImportRow, 'seatNumber'>, string[]> = {
  fullName: ['name', 'full name', 'student', 'student name', 'learner name'],
  lrn: ['lrn', 'learner reference number', 'reference number'],
  gender: ['gender', 'sex'],
  birthday: ['birthday', 'birth date', 'date of birth', 'birthdate'],
  guardianName: ['guardian', 'guardian name', 'parent', 'parent name', 'mother', 'father'],
  guardianContact: ['contact', 'guardian contact', 'phone', 'contact number', 'guardian contact number'],
};

function normalizeHeader(h: string): string {
  return h
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Map raw CSV rows to student records. Accepts a header row with any of the
 * known columns (extra columns are ignored). Without a recognizable header,
 * each row is treated as: Name  [, LRN] [, Gender] [, Birthday] [, Guardian] [, Contact] [, Seat].
 */
export function mapStudentRows(rows: string[][]): { students: StudentImportRow[]; errors: string[] } {
  const errors: string[] = [];
  if (rows.length === 0) return { students: [], errors: ['The file is empty.'] };

  const first = rows[0].map(normalizeHeader);
  const colMap: Partial<Record<keyof StudentImportRow, number>> = {};
  let hasHeader = false;
  (Object.keys(HEADER_ALIASES) as (keyof typeof HEADER_ALIASES)[]).forEach((field) => {
    const idx = first.findIndex((h) => HEADER_ALIASES[field].includes(h));
    if (idx >= 0) {
      colMap[field] = idx;
      hasHeader = true;
    }
  });
  const seatIdx = first.findIndex((h) => h === 'seat' || h === 'seat number' || h === 'no' || h === 'seat no');
  if (seatIdx >= 0) colMap.seatNumber = seatIdx;

  const dataRows = hasHeader ? rows.slice(1) : rows;
  const students: StudentImportRow[] = [];
  dataRows.forEach((r, n) => {
    const get = (field: keyof StudentImportRow): string => {
      const idx = colMap[field];
      if (idx === undefined) return '';
      return (r[idx] ?? '').trim();
    };
    const fullName = hasHeader ? get('fullName') : (r[0] ?? '').trim();
    if (!fullName) {
      errors.push(`Row ${n + (hasHeader ? 2 : 1)}: missing name, skipped.`);
      return;
    }
    const seatRaw = get('seatNumber');
    const seatNumber = seatRaw && /^\d+$/.test(seatRaw) ? Number(seatRaw) : null;
    students.push({
      fullName,
      lrn: get('lrn'),
      gender: get('gender'),
      birthday: get('birthday'),
      guardianName: get('guardianName'),
      guardianContact: get('guardianContact'),
      seatNumber,
    });
  });

  if (students.length === 0 && errors.length === 0) {
    errors.push('No student rows were found in the file.');
  }
  return { students, errors };
}
