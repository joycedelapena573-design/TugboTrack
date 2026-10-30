# TIS ClassTrack — Tugbo Integrated School

**Smarter Class Records, Made Simple.**

A user-friendly, offline-first class record mobile app for teachers, built with
**Flutter (Dart)** so it runs on **both iOS and Android** from one codebase.
All student information, grades, attendance and BMI records are stored **locally
on the device** in SQLite — no internet connection required — and protected by a
**6-digit MPIN**.

---

## Features

### 1. Student information management
- Add, edit, view and delete students (manual typing or bulk import).
- Records organized by **grade level, section, subject, school year and grading period**.
- Fully local **SQLite database** (`lib/data/database.dart`) for offline access — one
  table each for sections, students, subjects, score sheets, scores, attendance
  and BMI, written on every save and read back on launch.
- **Import CSV** from the device's file manager (Name, LRN, Gender, Birthday,
  Guardian, Contact, Seat columns — header aliases are auto-detected), or type
  students one by one.
- **"Add Student Information"** button reveals birthday (age auto-computed),
  Learners Reference Number (LRN), guardian/parent name and contact number.
- **Learner profile**: tapping a student's name shows *everything* — personal
  info, guardian, attendance summary, per-subject grades and BMI history.

### 2. Grade recording & computation
- Record scores for **quizzes, assignments, activities, performance tasks and
  examinations** (per grading period Q1–Q4), with configurable highest scores.
- Automatic weighted grade computation per subject (weights editable, presets
  provided, must total 100%) with optional **DepEd transmutation** (DO 8, s. 2015).
- Live quarterly grades, class average, highest/lowest, honor remarks and
  achievement descriptors per subject.
- Saved locally after every change.

### 3. Attendance monitoring by seat
- The teacher taps each student's **assigned seat number** on a seat board.
- Four statuses: **Present (P), Late (L), Absent (A), Excused (E)** — pick a
  "brush" then tap seats; long-press to clear; "Mark all present/absent" shortcuts.
- Daily records with date navigation, live summary counts and attendance rate.
- Stored locally for offline access.

### 4. Class record management & reports
- Search students by name or LRN inside each class; view/update class records.
- Generate **class record reports** with scores, computed grades, class averages
  and remarks (formal A4 layout with signature lines).
- **Print** directly or **save/share as PDF** (`printing` package).
- **CSV export** for class records, rosters and full backups (opens in Excel/Sheets).
- **Automatic CSV backup after every save/change** (attendance, scores,
  student edits…) into the app's `auto-backups/` folder — rolling set of
  `students.csv`, `grades.csv`, `attendance.csv`, `bmi.csv`, `full-backup.csv`.
- Learner profiles (4.6) and the "Add Student Information" panel (4.7) as above.

### 5. BMI monitoring
- Record height (cm) and weight (kg) per student with date.
- Automatic BMI calculation with WHO interpretation:
  Underweight / Normal / Overweight / Obese — color-coded with guidance text.
- Stored locally; values stay **hidden until revealed** (privacy toggle) to
  maintain confidentiality of student information.

### 6. 6-digit MPIN security
- First-run **Set Up Your MPIN** screen (per the approved mockup) with teacher
  name + create/confirm 6-digit MPIN.
- MPIN required **every time the app opens** and whenever it returns from the
  background; wrong attempts are counted and lock out for 30 s after 5 failures.
- **Change MPIN** any time in Settings → Security.
- The MPIN is stored as a **salted SHA-256 hash in the device keychain**
  (iOS Keychain / Android Keystore via `flutter_secure_storage`) — never in plain text.

---

## Screens (matching the approved designs)

| Screen | File | Notes |
| --- | --- | --- |
| Splash / loading page | `lib/screens/splash.dart` | Recreated from mockup 1 — school seal, ClassTrack wordmark with grad cap, script tagline, loading pill + progress bar. Shown on **every** app open, then routes to MPIN setup or unlock. |
| MPIN setup | `lib/screens/mpin_setup.dart` | Recreated from mockup 2, adapted to **6 digits** (per requirement 6). |
| MPIN unlock | `lib/screens/mpin_login.dart` | Dot display + numeric keypad. |
| Main shell (tabs) | `lib/screens/main_shell.dart` | Home / Grades / More, re-locks when the app backgrounds. |
| Home / classes | `lib/screens/home.dart` | Greeting, stats, class cards. |
| Class detail | `lib/screens/class_detail.dart` | Roster, subjects, import, quick actions. |
| Attendance | `lib/screens/attendance.dart` | Seat board with P/L/A/E. |
| Grade book | `lib/screens/grades.dart` | Items, score grid, computed grades. |
| BMI | `lib/screens/bmi.dart` | Record + history with privacy toggle. |
| Reports | `lib/screens/reports.dart` | Print / PDF / CSV / backups. |
| Settings | `lib/screens/settings.dart` | Name, change MPIN, storage info. |

## Project structure

```
assets/                 # school seal, app icons and Poppins/Caveat fonts
android/, ios/          # Flutter platform projects (flutter create)
lib/main.dart           # providers, theme, splash entry point
lib/models/             # data model types (sections, students, grades, …)
lib/data/               # SQLite layer (sqflite) + legacy import
lib/state/              # app store (ChangeNotifier) and MPIN lock state
lib/services/           # grading engine, BMI, CSV, importer, backups, MPIN, PDF reports
lib/screens/            # one file per screen
lib/widgets/            # shared UI kit, seat board, pin pad, school logo, decorations
test/                   # pure-Dart tests for grading, BMI and CSV
```

## Getting started

```bash
flutter pub get
flutter run             # on a connected device or emulator
```

Build release binaries:

```bash
flutter build apk       # Android
flutter build ipa       # iOS (requires Xcode)
```

## Verification performed

- `flutter analyze` — no issues found
- `flutter test` — all tests pass (grade computation, weight redistribution,
  DepEd transmutation, BMI interpretation, CSV round-trip)

## Notes

- **MPIN length:** requirement 6 specifies a 6-digit MPIN, so the setup screen
  follows the mockup's design with 6-digit fields.
- **School logo:** `assets/school-logo.png` is a faithful vector recreation of
  the Tugbo Integrated School seal (torch, open book, laurel, 1965 ribbon).
  Teachers can replace it from Settings → School Logo and pick their own image.
- Data never leaves the device unless the teacher explicitly shares an export.
- **Storage:** all records live in the on-device SQLite file `classtrack.db`.
  Data saved by an older build in AsyncStorage is imported into SQLite
  automatically on first launch, then removed so SQLite is the single source
  of truth.
