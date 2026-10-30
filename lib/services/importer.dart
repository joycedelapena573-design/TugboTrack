/// Import a student roster CSV from the device's file manager (requirement 4.5).
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../models/models.dart';
import '../utils/format.dart';
import 'csv.dart';

enum ImportStatus { ready, canceled, failed }

class ImportOutcome {
  const ImportOutcome(this.status, {this.rows, this.errors, this.fileName});

  final ImportStatus status;
  final List<StudentImportRow>? rows;
  final List<String>? errors;
  final String? fileName;
}

/// Pick a CSV/TXT file and parse it into raw student rows.
Future<ImportOutcome> pickStudentCsv() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'txt'],
  );
  if (file == null) return const ImportOutcome(ImportStatus.canceled);

  final name = file.name;
  try {
    final path = file.path;
    final text = path != null
        ? await File(path).readAsString()
        : utf8.decode(await file.xFile.readAsBytes(), allowMalformed: true);
    final parsed = mapStudentRows(parseCsv(text));
    if (parsed.students.isEmpty) {
      return ImportOutcome(ImportStatus.failed, errors: parsed.errors, fileName: name);
    }
    return ImportOutcome(
      ImportStatus.ready,
      rows: parsed.students,
      errors: parsed.errors,
      fileName: name,
    );
  } catch (err) {
    return ImportOutcome(
      ImportStatus.failed,
      errors: ['Could not read $name: $err'],
      fileName: name,
    );
  }
}

/// Convert a parsed import row into store-ready student fields.
///
/// The returned student has no id yet — [AppState.addStudent] assigns one when
/// it is saved.
Student toStudentInput(StudentImportRow row, String sectionId, int seatFallback) {
  final gender = row.gender.toLowerCase();
  return Student(
    id: '',
    sectionId: sectionId,
    seatNumber: row.seatNumber ?? seatFallback,
    fullName: row.fullName,
    lrn: row.lrn,
    gender: gender.contains('f')
        ? 'Female'
        : gender.contains('m')
            ? 'Male'
            : '',
    birthday: normalizeBirthday(row.birthday) ?? '',
    guardianName: row.guardianName,
    guardianContact: row.guardianContact,
    createdAt: 0,
  );
}

/// A blank CSV template teachers can fill in and import.
const String studentCsvTemplate =
    'Name,LRN,Gender,Birthday,Guardian,Contact,Seat\r\n'
    'Juan Dela Cruz,123456789012,Male,2012-05-14,Maria Dela Cruz,09171234567,1\r\n';
