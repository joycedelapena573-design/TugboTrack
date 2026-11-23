/// Tiny CSV serializer/parser + student-list import mapping.
library;

/// Serialize rows (arrays of primitives) to CSV text (RFC-style quoting, CRLF).
String toCsv(List<List<Object?>> rows) =>
    rows.map((row) => row.map(_cell).join(',')).join('\r\n');

String _cell(Object? cell) {
  if (cell == null) return '';
  final s = _stringify(cell);
  final needsQuotes = s.contains(RegExp(r'[",\r\n]'));
  return needsQuotes ? '"${s.replaceAll('"', '""')}"' : s;
}

/// Matches JavaScript's `String(value)` for the types we store: whole numbers
/// print without a decimal part (18, not 18.0).
String _stringify(Object value) {
  if (value is double) {
    return value == value.roundToDouble() ? '${value.toInt()}' : '$value';
  }
  return value.toString();
}

/// Parse CSV text (handles quoted fields, embedded commas/newlines, BOM).
List<List<String>> parseCsv(String text) {
  final src = text.replaceFirst(RegExp(r'^\uFEFF'), '');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = '';
  var inQuotes = false;
  var i = 0;

  void pushField() {
    row.add(field);
    field = '';
  }

  void pushRow() {
    pushField();
    if (row.length > 1 || row.first != '') rows.add(row);
    row = <String>[];
  }

  while (i < src.length) {
    final ch = src[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < src.length && src[i + 1] == '"') {
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
    if (ch == '"') {
      inQuotes = true;
      i += 1;
      continue;
    }
    if (ch == ',') {
      pushField();
      i += 1;
      continue;
    }
    if (ch == '\r') {
      i += 1;
      continue;
    }
    if (ch == '\n') {
      pushRow();
      i += 1;
      continue;
    }
    field += ch;
    i += 1;
  }
  if (field.isNotEmpty || row.isNotEmpty) pushRow();
  return rows;
}

class StudentImportRow {
  StudentImportRow({
    required this.fullName,
    required this.lrn,
    required this.gender,
    required this.birthday,
    required this.guardianName,
    required this.guardianContact,
    required this.seatNumber,
  });

  final String fullName;
  final String lrn;
  final String gender;
  final String birthday;
  final String guardianName;
  final String guardianContact;
  final int? seatNumber;
}

class StudentImportResult {
  const StudentImportResult({required this.students, required this.errors});

  final List<StudentImportRow> students;
  final List<String> errors;
}

const Map<String, List<String>> _headerAliases = {
  'fullName': ['name', 'full name', 'student', 'student name', 'learner name'],
  'lrn': ['lrn', 'learner reference number', 'reference number'],
  'gender': ['gender', 'sex'],
  'birthday': ['birthday', 'birth date', 'date of birth', 'birthdate'],
  'guardianName': [
    'guardian',
    'guardian name',
    'parent',
    'parent name',
    'mother',
    'father',
  ],
  'guardianContact': [
    'contact',
    'guardian contact',
    'phone',
    'contact number',
    'guardian contact number',
  ],
};

String _normalizeHeader(String h) => h
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

///
/// Map raw CSV rows to student records. Accepts a header row with any of the
/// known columns (extra columns are ignored). Without a recognizable header,
/// each row is treated as: Name [, LRN] [, Gender] [, Birthday] [, Guardian]
/// [, Contact] [, Seat].
StudentImportResult mapStudentRows(List<List<String>> rows) {
  final errors = <String>[];
  if (rows.isEmpty) {
    return const StudentImportResult(students: [], errors: ['The file is empty.']);
  }

  final first = rows.first.map(_normalizeHeader).toList();
  final colMap = <String, int>{};
  var hasHeader = false;
  for (final field in _headerAliases.keys) {
    final idx = first.indexWhere((h) => _headerAliases[field]!.contains(h));
    if (idx >= 0) {
      colMap[field] = idx;
      hasHeader = true;
    }
  }
  final seatIdx =
      first.indexWhere((h) => h == 'seat' || h == 'seat number' || h == 'no' || h == 'seat no');
  if (seatIdx >= 0) colMap['seatNumber'] = seatIdx;

  final dataRows = hasHeader ? rows.skip(1).toList() : rows;
  final students = <StudentImportRow>[];

  for (var n = 0; n < dataRows.length; n += 1) {
    final r = dataRows[n];
    String get(String field) {
      final idx = colMap[field];
      if (idx == null || idx >= r.length) return '';
      return r[idx].trim();
    }

    final fullName = hasHeader ? get('fullName') : (r.isNotEmpty ? r[0].trim() : '');
    if (fullName.isEmpty) {
      errors.add('Row ${n + (hasHeader ? 2 : 1)}: missing name, skipped.');
      continue;
    }
    final seatRaw = get('seatNumber');
    final seatNumber =
        seatRaw.isNotEmpty && RegExp(r'^\d+$').hasMatch(seatRaw) ? int.tryParse(seatRaw) : null;
    students.add(StudentImportRow(
      fullName: fullName,
      lrn: get('lrn'),
      gender: get('gender'),
      birthday: get('birthday'),
      guardianName: get('guardianName'),
      guardianContact: get('guardianContact'),
      seatNumber: seatNumber,
    ));
  }

  if (students.isEmpty && errors.isEmpty) {
    errors.add('No student rows were found in the file.');
  }
  return StudentImportResult(students: students, errors: errors);
}

/* ----------------------------- BMI measurements ---------------------------- */

class MeasurementImportRow {
  const MeasurementImportRow({
    required this.fullName,
    required this.heightCm,
    required this.weightKg,
    required this.date,
  });

  final String fullName;
  final double heightCm;
  final double weightKg;

  /// ISO date, or '' when the file has no date column (today is used).
  final String date;
}

class MeasurementImportResult {
  const MeasurementImportResult({required this.rows, required this.errors});

  final List<MeasurementImportRow> rows;
  final List<String> errors;
}

const Map<String, List<String>> _measurementAliases = {
  'name': ['name', 'full name', 'student', 'student name', 'learner name'],
  'height': ['height', 'height cm', 'height in cm', 'height (cm)'],
  'weight': ['weight', 'weight kg', 'weight in kg', 'weight (kg)'],
  'date': ['date', 'measured', 'measurement date', 'date measured'],
};

/// Maps CSV rows to height/weight measurements for the BMI screen.
///
/// Accepts a header row with name/height/weight/date columns, or bare rows in
/// the order: Name, Height (cm), Weight (kg) [, Date].
MeasurementImportResult mapMeasurementRows(List<List<String>> rows) {
  final errors = <String>[];
  if (rows.isEmpty) {
    return const MeasurementImportResult(rows: [], errors: ['The file is empty.']);
  }

  final first = rows.first.map(_normalizeHeader).toList();
  final colMap = <String, int>{};
  var hasHeader = false;
  for (final field in _measurementAliases.keys) {
    final idx = first.indexWhere((h) => _measurementAliases[field]!.contains(h));
    if (idx >= 0) {
      colMap[field] = idx;
      hasHeader = true;
    }
  }

  final dataRows = hasHeader ? rows.skip(1).toList() : rows;
  final result = <MeasurementImportRow>[];

  double? parseNumber(String raw) =>
      double.tryParse(raw.trim().replaceAll(RegExp(r'[^0-9.]'), ''));

  for (var n = 0; n < dataRows.length; n += 1) {
    final row = dataRows[n];
    String get(String field, int fallbackIndex) {
      final idx = colMap[field] ?? (hasHeader ? -1 : fallbackIndex);
      if (idx < 0 || idx >= row.length) return '';
      return row[idx].trim();
    }

    final name = get('name', 0);
    final height = parseNumber(get('height', 1));
    final weight = parseNumber(get('weight', 2));
    if (name.isEmpty) {
      errors.add('Row ${n + (hasHeader ? 2 : 1)}: missing name, skipped.');
      continue;
    }
    if (height == null || weight == null || height <= 0 || weight <= 0) {
      errors.add(
        'Row ${n + (hasHeader ? 2 : 1)}: height/weight missing for $name, skipped.',
      );
      continue;
    }
    result.add(MeasurementImportRow(
      fullName: name,
      heightCm: height,
      weightKg: weight,
      date: get('date', 3),
    ));
  }

  if (result.isEmpty && errors.isEmpty) {
    errors.add('No height/weight rows were found in the file.');
  }
  return MeasurementImportResult(rows: result, errors: errors);
}
