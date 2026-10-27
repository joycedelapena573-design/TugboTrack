/** Import a student roster CSV from the device's file manager (requirement 4.5). */
import * as DocumentPicker from 'expo-document-picker';
import { File } from 'expo-file-system';

import { mapStudentRows, parseCsv, type StudentImportRow } from './csv';
import { normalizeBirthday } from './format';
import type { Student } from './types';

export interface ImportOutcome {
  status: 'ready' | 'canceled' | 'failed';
  rows?: StudentImportRow[];
  errors?: string[];
  fileName?: string;
}

/** Pick a CSV/TXT file and parse it into raw student rows. */
export async function pickStudentCsv(): Promise<ImportOutcome> {
  const result = await DocumentPicker.getDocumentAsync({
    type: ['text/csv', 'text/comma-separated-values', 'text/plain', 'application/octet-stream'],
    copyToCacheDirectory: true,
    multiple: false,
  });
  if (result.canceled || !result.assets?.length) return { status: 'canceled' };

  const asset = result.assets[0];
  try {
    const file = new File(asset.uri);
    const text = await file.text();
    const rows = parseCsv(text);
    const { students, errors } = mapStudentRows(rows);
    if (students.length === 0) return { status: 'failed', errors, fileName: asset.name };
    return { status: 'ready', rows: students, errors, fileName: asset.name };
  } catch (err) {
    return {
      status: 'failed',
      errors: [`Could not read ${asset.name ?? 'the file'}: ${String(err)}`],
      fileName: asset.name,
    };
  }
}

/** Convert parsed import rows into store-ready student fields. */
export function toStudentInput(
  row: StudentImportRow,
  sectionId: string,
  seatFallback: number,
): Omit<Student, 'id' | 'createdAt'> {
  return {
    sectionId,
    seatNumber: row.seatNumber ?? seatFallback,
    fullName: row.fullName,
    lrn: row.lrn,
    gender: /f/i.test(row.gender) ? 'Female' : /m/i.test(row.gender) ? 'Male' : '',
    birthday: normalizeBirthday(row.birthday) ?? '',
    guardianName: row.guardianName,
    guardianContact: row.guardianContact,
  };
}

/** A blank CSV template teachers can fill in and import. */
export const STUDENT_CSV_TEMPLATE =
  'Name,LRN,Gender,Birthday,Guardian,Contact,Seat\r\n' +
  'Juan Dela Cruz,123456789012,Male,2012-05-14,Maria Dela Cruz,09171234567,1\r\n';
