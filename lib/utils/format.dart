/// Date / name / number formatting helpers (no external deps).
library;

const List<String> _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "YYYY-MM-DD" for a date (local time).
String toIsoDate(DateTime date) {
  final m = '${date.month}'.padLeft(2, '0');
  final d = '${date.day}'.padLeft(2, '0');
  return '${date.year}-$m-$d';
}

String todayIso() => toIsoDate(DateTime.now());

/// Parse "YYYY-MM-DD" as a local date. Returns null when invalid.
DateTime? parseIsoDate(String iso) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso.trim());
  if (match == null) return null;
  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) return null;
  return date;
}

/// "October 26, 2026"
String formatLongDate(String iso) {
  final d = parseIsoDate(iso);
  if (d == null) return iso;
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// "Oct 26, 2026"
String formatShortDate(String iso) {
  final d = parseIsoDate(iso);
  if (d == null) return iso;
  return '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';
}

/// "October 26" (no year) for the attendance date bar.
String formatDayLabel(String iso) {
  final d = parseIsoDate(iso);
  if (d == null) return iso;
  return '${_months[d.month - 1]} ${d.day}';
}

String addDays(String iso, int delta) {
  final d = parseIsoDate(iso) ?? DateTime.now();
  return toIsoDate(d.add(Duration(days: delta)));
}

/// Age in whole years from an ISO birthday to today.
int? ageFromBirthday(String birthdayIso, [DateTime? now]) {
  final b = parseIsoDate(birthdayIso);
  if (b == null) return null;
  final today = now ?? DateTime.now();
  int age = today.year - b.year;
  if (today.month < b.month ||
      (today.month == b.month && today.day < b.day)) {
    age -= 1;
  }
  return age >= 0 ? age : null;
}

/// Validate + normalize typed birthdays: accepts YYYY-MM-DD or MM/DD/YYYY.
String? normalizeBirthday(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;

  int y, m, d;
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
  if (slash != null) {
    m = int.parse(slash.group(1)!);
    d = int.parse(slash.group(2)!);
    y = int.parse(slash.group(3)!);
  } else {
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(raw);
    if (iso == null) return null;
    y = int.parse(iso.group(1)!);
    m = int.parse(iso.group(2)!);
    d = int.parse(iso.group(3)!);
  }
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) return null;
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) return null;
  return toIsoDate(date);
}

List<String> _words(String name) =>
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// "dela Cruz, Juan" -> "JC" style initials for avatars.
String initialsOf(String fullName) {
  final parts = _words(fullName);
  if (parts.isEmpty) return '?';
  final last = parts.last.isEmpty ? '' : parts.last.substring(0, 1);
  final first = parts.first.isEmpty ? '' : parts.first.substring(0, 1);
  return (first + last).toUpperCase();
}

/// "Juan Dela Cruz" -> "Dela Cruz, Juan" for roster-style lists.
String toLastFirst(String fullName) {
  final parts = _words(fullName);
  if (parts.length < 2) return fullName;
  final last = parts.last;
  final rest = parts.sublist(0, parts.length - 1).join(' ');
  return '$last, $rest';
}

/// "18" for whole numbers, "18.50" otherwise, "—" when missing.
String formatScore(double? value) {
  if (value == null || value.isNaN) return '—';
  return value == value.roundToDouble() ? '${value.toInt()}' : value.toStringAsFixed(2);
}

/// Fixed-precision percentage, "—" when missing.
String formatPercent(double? value, [int digits = 2]) {
  if (value == null || value.isNaN) return '—';
  return value.toStringAsFixed(digits);
}
