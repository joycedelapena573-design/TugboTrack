# TugboTrack — Tugbo Integrated School

**Mobile-Based Offline Class Record System.**

A teacher-friendly, fully offline class record app built with **Flutter (Dart)**
and **SQLite** (`sqflite`), targeting **Android**. Student information, class
records, assessments, grades, attendance and BMI all live in one local database
on the device — no internet, no accounts, no cloud.

---

## Features

### Dashboard
- Total classes and learners, active school year and current term at a glance.
- School-year selector and Term 1 / 2 / 3 switcher.
- Today's attendance status and quick access to class records.
- Archived classes stay archived with their records and can be restored.

### Classes
- Create, view, edit and **archive** classes (grade level + section + school
  year + curriculum). Archiving preserves every learner, score and grade.
- Organized by grade level, section, subject, school year and term.
- Multiple classes and subjects per teacher.

### Learners
- Add, edit, view, search (name or LRN), archive and delete learners.
- Learner profile: personal details, guardian, attendance summary, per-subject
  term grades and BMI history.
- **CSV import** from the device's file manager, or one-by-one entry.
- Historical records are preserved; nothing is silently discarded.

### Three-term academic calendar
- DepEd **Term 1–3** for SY 2026–2027 (and later years), each with its own
  assessment and grade records.
- Subjects may run for **one term, two terms or the whole year**; electives are
  supported without disturbing other subjects.
- Switching terms or school years **never** deletes or replaces subjects.

### Assessments and grading
- Assessment categories: **Written Works (WW)**, **Performance Tasks (PT)** and
  **Term Examination (TE)**, per subject and term.
- Create assessments with titles and maximum scores, then enter scores in a
  mobile-friendly grid.
- Configurable weights per subject (DepEd presets for the Existing SHS and the
  Strengthened SHS curricula: 25/50/25 academic, 20/60/20 TVL/Arts & Sports),
  validated to total 100%.
- Automatic computation: category percentages → **initial grade** → **term
  grade** (DepEd Order 8, s. 2015 transmutation when enabled) → **final grade**
  (average of the subject's term grades).
- Grades are rounded half-up with no floating-point drift, and a failing grade
  is never rounded into a passing one.

### Attendance
- Seat-based board with **Present / Late / Absent / Excused**.
- Day navigation, edits per learner, per-day clearing, and summaries
  (days recorded, totals, attendance rate).

### Reports
- Class record (PDF + CSV), term grade report, final grade report, learner
  roster, attendance summary, and a full CSV backup.
- Print or share PDFs from the device.

### BMI monitoring
- Height/weight entry per learner with BMI history.
- Interpreted against the **WHO 2007 BMI-for-age** reference for learners aged
  5–19 using the record date, birthday and sex (falling back to adult cut-offs
  when those are unknown) — not adult categories applied universally.

### Security and backups
- **6-digit MPIN**: set up on first launch, required on every open and when the
  app returns from the background, changeable in Settings. Stored only as a
  salted SHA-256 hash in the device keychain.
- **Automatic CSV backup** after every save, plus on-demand full CSV export.
- **Database backup and restore** (copy of the SQLite file), with confirmation
  before anything destructive.

---

## Database (schema v2)

One SQLite file (`tugbotrack.db`) with foreign keys, indexes, transactions and
migrations:

`teachers`, `school_years`, `academic_terms`, `classes`, `subjects`, `students`,
`class_students`, `assessments`, `student_scores`, `attendance`, `term_grades`,
`final_grades`, `bmi_records`, `grading_configurations`, `grading_components`,
plus `kv` for app settings.

- The database is created automatically on first launch and seeded with the
  current school year, its three terms and the DepEd grading presets.
- Upgrading from the earlier quarterly build migrates every row (Q1–Q3 → Terms
  1–3, the five old components → WW/PT/TE, weights preserved per subject) inside
  a single transaction; the old tables are dropped only after the copy succeeds.
- Deleting a class or learner is a confirmed action and cascades to the records
  that belong to it.

---

## Screens

| Screen | File |
| --- | --- |
| Splash | `lib/screens/splash.dart` |
| MPIN setup / unlock | `lib/screens/mpin_setup.dart`, `mpin_login.dart` |
| Main shell (tabs, re-locks on background) | `lib/screens/main_shell.dart` |
| Dashboard | `lib/screens/home.dart` |
| Class detail (roster, attendance, archive) | `lib/screens/class_detail.dart` |
| Grade book (assessments + term grades) | `lib/screens/grades.dart` |
| Attendance (seat board) | `lib/screens/attendance.dart` |
| BMI monitoring | `lib/screens/bmi.dart` |
| Reports | `lib/screens/reports.dart` |
| Settings (calendar, backups, MPIN, logo) | `lib/screens/settings.dart` |
| Class / subject / learner forms | `section_form.dart`, `subject_form.dart`, `student_form.dart` |

## Project structure

```
assets/                 # school seal, app icons, Poppins/Caveat fonts
android/, ios/          # Flutter platform projects
lib/main.dart           # providers, theme, splash entry point
lib/models/             # domain types and DepEd grading presets
lib/data/               # SQLite schema, migrations, backup/restore
lib/state/              # app store (ChangeNotifier) and MPIN lock
lib/services/           # grading, BMI, CSV, importer, backups, MPIN, PDFs
lib/screens/            # one file per screen
lib/widgets/            # shared UI kit, seat board, pin pad, school logo
test/                   # grading, calendar, migration, BMI and CSV tests
```

## Getting started

```bash
flutter pub get
flutter run             # on a connected Android device or emulator
flutter build apk       # Android release build
```

## Verification

- `flutter analyze` — no issues found.
- `flutter test` — 19 tests covering weighted term grades, weight
  redistribution, DO 8 transmutation bands, rounding, final-grade averaging,
  three-term subject spans, attendance counts, WHO BMI-for-age, CSV export, and
  a real SQLite migration from the quarterly database plus fresh-install
  seeding (via `sqflite_common_ffi`).

## Notes

- Data never leaves the device unless the teacher explicitly shares an export.
- Recorded data can be recovered either from the CSV snapshots or from a
  database backup file created in Settings.
