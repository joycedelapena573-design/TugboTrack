# TIS ClassTrack — Tugbo Integrated School

**Smarter Class Records, Made Simple.**

A user-friendly, offline-first class record mobile app for teachers, built with
Expo (React Native) so it runs on **both iOS and Android** from one codebase.
All student information, grades, attendance and BMI records are stored **locally
on the device** — no internet connection required — and protected by a
**6-digit MPIN**.

---

## Features

### 1. Student information management
- Add, edit, view and delete students (manual typing or bulk import).
- Records organized by **grade level, section, subject, school year and grading period**.
- Fully local **SQLite database** (`src/lib/db.ts`) for offline access — one
  table each for sections, students, subjects, score sheets, scores, attendance
  and BMI, written on every save and read back on launch.
- **Import CSV** from the device's file manager (Name, LRN, Gender, Birthday,
  Guardian, Contact, Seat columns — header aliases are auto-detected), or use
  **Quick Type** for one-line manual entry.
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
- **Print** directly or **save as PDF** (expo-print + share sheet).
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
  (iOS Keychain / Android Keystore via expo-secure-store) — never in plain text.

---

## Screens (matching the approved designs)

| Screen | File | Notes |
| --- | --- | --- |
| Splash / loading page | `src/app/index.tsx` | Recreated from mockup 1 — school seal, ClassTrack wordmark with grad cap, script tagline, loading pill + progress bar. Shown on **every** app open, then routes to MPIN setup or unlock. |
| MPIN setup | `src/app/mpin-setup.tsx` | Recreated from mockup 2, adapted to **6 digits** (per requirement 6). |
| MPIN unlock | `src/app/mpin-login.tsx` | Dot display + numeric keypad. |
| Home / classes | `src/app/(main)/index.tsx` | Greeting, stats, class cards. |
| Class detail | `src/app/class/[id].tsx` | Roster, subjects, import, quick actions. |
| Attendance | `src/app/(main)/attendance.tsx` | Seat board with P/L/A/E. |
| Grade book | `src/app/(main)/grades.tsx` | Items, score grid, computed grades. |
| BMI | `src/app/bmi.tsx` | Record + history with privacy toggle. |
| Reports | `src/app/reports.tsx` | Print / PDF / CSV / backups. |
| Settings | `src/app/settings.tsx` | Name, change MPIN, storage info. |

## Project structure

```
assets/                 # school seal + app icons (regenerate: node tools/generate-assets.mjs)
src/app/                # Expo Router screens (file-based navigation)
src/components/         # shared UI kit + brand SVG illustrations
src/lib/                # store, SQLite database, grading engine, CSV/backup, MPIN, BMI
tools/                  # asset generator (sharp + opentype.js)
```

## Getting started

```bash
npm install          # if node_modules is missing
npx expo start       # then press i / a, or scan the QR with Expo Go
```

Native modules used (secure store, SQLite, file system, print, document
picker) are part of Expo Go for development; for production builds use EAS:

```bash
bunx eas-cli@latest build --profile production   # iOS + Android in the cloud
bunx eas-cli@latest submit                       # App Store / Play Store
```

## Verification performed

- `npx tsc --noEmit` — passes
- `npx expo lint` — passes (0 errors, 0 warnings)
- `npx expo export --platform ios` — bundles cleanly (all routes + assets)
- `npx expo-doctor` — 20/20 checks passed

## Notes

- **MPIN length:** requirement 6 specifies a 6-digit MPIN, so the setup screen
  follows the mockup's design with 6-digit fields.
- **School logo:** `assets/school-logo.png` is a faithful vector recreation of
  the Tugbo Integrated School seal (torch, open book, laurel, 1965 ribbon).
  To use the official artwork instead, replace that file (1024×1024 PNG) and
  run `node tools/generate-assets.mjs` to refresh the app icons.
- Data never leaves the device unless the teacher explicitly shares an export.
- **Storage:** all records live in the on-device SQLite file `classtrack.db`.
  Data saved by an older build in AsyncStorage is imported into SQLite
  automatically on first launch (one transaction, retried until it succeeds),
  then removed so SQLite is the single source of truth.
