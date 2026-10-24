/** Minimal CSV parsing: quoted fields, escaped quotes, CRLF, no external deps. */

/** Split raw CSV text into rows of trimmed cells. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;

  const pushField = () => {
    row.push(field.trim());
    field = '';
  };
  const pushRow = () => {
    pushField();
    if (row.some((cell) => cell.length > 0)) rows.push(row);
    row = [];
  };

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (inQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"' && field.trim().length === 0) {
      inQuotes = true;
    } else if (char === ',') {
      pushField();
    } else if (char === '\n') {
      pushRow();
    } else if (char !== '\r') {
      field += char;
    }
  }
  if (field.length > 0 || row.length > 0) pushRow();

  return rows;
}

export interface CsvTable {
  headers: string[];
  /** Normalised header -> raw row values. */
  records: Record<string, string>[];
}

const normalise = (value: string) => value.toLowerCase().replace(/[^a-z0-9]/g, '');

/** Turn parsed rows into header/value records, detecting the header line. */
export function toTable(rows: string[][]): CsvTable {
  if (rows.length === 0) return { headers: [], records: [] };

  let headers = rows[0].map(normalise);
  let start = 1;

  // If the first row has no recognisable header words, treat it as data.
  const known = ['name', 'student', 'section', 'subject', 'class', 'gradelevel'];
  const looksLikeHeader = headers.some((h) => known.includes(h));
  if (!looksLikeHeader) {
    headers = headers.map((_, i) => `col${i}`);
    start = 0;
  }

  const records = rows.slice(start).map((cells) => {
    const record: Record<string, string> = {};
    headers.forEach((header, index) => {
      record[header] = (cells[index] ?? '').trim();
    });
    return record;
  });

  return { headers, records };
}

/** Fetch the first present value among normalised candidate keys. */
export function pick(record: Record<string, string>, keys: string[]): string {
  for (const key of keys) {
    const value = record[key];
    if (value !== undefined && value.length > 0) return value;
  }
  return '';
}