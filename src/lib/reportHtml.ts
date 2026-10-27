/** HTML class-record sheets for printing / PDF export (requirement 4.2–4.3). */
import { gradeRemarks } from './grading';
import type { BackupData } from './backup';
import { COMPONENTS, type Quarter, type Student, type Subject } from './types';

const esc = (s: string): string =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const fmt = (n: number | null, digits = 2): string =>
  n === null || Number.isNaN(n) ? '—' : n.toFixed(digits);

function pageCss(): string {
  return `
    @page { size: A4 portrait; margin: 14mm 12mm; }
    body { font-family: Helvetica, Arial, sans-serif; color: #0B2E6E; font-size: 11px; }
    h1 { font-size: 16px; text-align: center; margin: 0 0 2px; }
    h2 { font-size: 13px; text-align: center; margin: 0 0 10px; font-weight: normal; }
    .meta { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
    .meta td { padding: 3px 4px; font-size: 11px; vertical-align: top; }
    .label { color: #5A6E96; width: 90px; }
    table.grid { width: 100%; border-collapse: collapse; }
    table.grid th, table.grid td { border: 1px solid #9FB6DC; padding: 4px 3px; text-align: center; font-size: 10px; }
    table.grid th { background: #EAF2FD; color: #0A3A8C; }
    table.grid td.name { text-align: left; padding-left: 6px; font-size: 10.5px; }
    .total-row td { background: #F4F8FF; font-weight: bold; }
    .remarks { font-style: italic; font-size: 9px; }
    .summary { margin-top: 12px; width: 100%; border-collapse: collapse; }
    .summary td { border: 1px solid #9FB6DC; padding: 6px; text-align: center; font-size: 11px; }
    .signatures { margin-top: 44px; width: 100%; }
    .signatures td { text-align: center; font-size: 11px; padding-top: 34px; }
    .sign-line { border-top: 1px solid #0B2E6E; display: block; margin: 0 18px; padding-top: 4px; }
    .footer { margin-top: 18px; font-size: 9px; color: #5A6E96; text-align: center; }
  `;
}

/** Formal class record for one subject + quarter. */
export function buildClassRecordHtml(
  data: BackupData,
  section: { gradeLevel: string; section: string; schoolYear: string },
  subject: Subject,
  quarter: Quarter,
): string {
  const students = Object.values(data.students)
    .filter((s) => s.sectionId === subject.sectionId)
    .sort((a, b) => a.seatNumber - b.seatNumber);

  const sheet = data.sheets[`${subject.id}::q${quarter}`];
  const weights = subject.weights;

  const compCols = COMPONENTS.map((c) => ({ key: c.key, label: c.short }));
  const items = sheet
    ? compCols.map((c) => ({
        label: c.label,
        items: sheet.items[c.key] ?? [],
      }))
    : [];

  const headerCells: string[] = ['No.', 'Name of Student'];
  for (const group of items) {
    for (const it of group.items) headerCells.push(`${esc(group.label)}<br>${esc(it.title)}<br>/${it.max}`);
    headerCells.push(`${esc(group.label)}<br>%`);
  }
  headerCells.push('WW<br>%', 'PT<br>%', 'QA<br>%', 'FINAL<br>GRADE', 'REMARKS');

  const colCount = headerCells.length;

  const rows = students.map((st: Student, idx: number) => {
    const cells: string[] = [`<td>${idx + 1}</td>`, `<td class="name">${esc(st.fullName)}</td>`];
    let wwSum = 0;
    let wwCount = 0;
    let ptPct: number | null = null;
    let qaPct: number | null = null;
    for (const group of items) {
      let earned = 0;
      let max = 0;
      for (const it of group.items) {
        const v = data.scores[`${sheet?.id}|${st.id}|${it.id}`];
        const shown = typeof v === 'number' ? v : null;
        cells.push(`<td>${shown === null ? '—' : shown}</td>`);
        if (shown !== null) {
          earned += shown;
          max += it.max;
        }
      }
      const pct = max > 0 ? (earned / max) * 100 : null;
      cells.push(`<td>${pct === null ? '—' : pct.toFixed(1)}</td>`);
      if (group.label === 'PERF') ptPct = pct;
      else if (group.label === 'EXAM') qaPct = pct;
      else if (pct !== null) {
        wwSum += pct;
        wwCount += 1;
      }
    }
    const wwPct = wwCount > 0 ? wwSum / wwCount : null;
    // Weighted final grade (weights redistributed over available components).
    const parts: { pct: number | null; w: number }[] = [
      { pct: wwPct, w: weights.quizzes + weights.assignments + weights.activities },
      { pct: ptPct, w: weights.performanceTasks },
      { pct: qaPct, w: weights.examinations },
    ];
    const usable = parts.filter((p) => p.pct !== null);
    const wSum = usable.reduce((a, b) => a + b.w, 0);
    let final: number | null = null;
    if (wSum > 0) {
      final = usable.reduce((a, b) => a + ((b.pct ?? 0) * b.w) / 100, 0) / (wSum / 100);
      if (subject.transmute) final = transmuteOnSheet(final);
    }
    const remarks = gradeRemarks(final);
    cells.push(
      `<td>${wwPct === null ? '—' : wwPct.toFixed(1)}</td>`,
      `<td>${ptPct === null ? '—' : ptPct.toFixed(1)}</td>`,
      `<td>${qaPct === null ? '—' : qaPct.toFixed(1)}</td>`,
      `<td><b>${final === null ? '—' : final.toFixed(1)}</b></td>`,
      `<td class="remarks">${esc(remarks)}</td>`,
    );
    return `<tr>${cells.join('')}</tr>`;
  });

  // Class averages per column
  const avgCells: string[] = ['', '<td class="name">CLASS AVERAGE</td>'];
  if (sheet) {
    for (const group of items) {
      for (const it of group.items) {
        const vals = students
          .map((st) => data.scores[`${sheet.id}|${st.id}|${it.id}`])
          .filter((v): v is number => typeof v === 'number');
        avgCells.push(`<td>${vals.length ? (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1) : '—'}</td>`);
      }
      const pcts = students.map((st) => {
        let earned = 0;
        let max = 0;
        for (const it of group.items) {
          const v = data.scores[`${sheet.id}|${st.id}|${it.id}`];
          if (typeof v === 'number') {
            earned += v;
            max += it.max;
          }
        }
        return max > 0 ? (earned / max) * 100 : null;
      }).filter((v): v is number => v !== null);
      avgCells.push(`<td>${pcts.length ? (pcts.reduce((a, b) => a + b, 0) / pcts.length).toFixed(1) : '—'}</td>`);
    }
  }
  avgCells.push('', '', '', '', '');
  const avgRow = `<tr class="total-row">${avgCells.join('')}</tr>`;

  const finals = students
    .map((st) => {
      const sheetLocal = sheet;
      if (!sheetLocal) return null;
      // reuse simple weighted calc
      let acc = 0;
      let wSum = 0;
      for (const c of COMPONENTS) {
        const itemsC = sheetLocal.items[c.key] ?? [];
        let earned = 0;
        let max = 0;
        for (const it of itemsC) {
          const v = data.scores[`${sheetLocal.id}|${st.id}|${it.id}`];
          if (typeof v === 'number') {
            earned += v;
            max += it.max;
          }
        }
        if (max > 0) {
          acc += ((earned / max) * 100 * weights[c.key]) / 100;
          wSum += weights[c.key];
        }
      }
      return wSum > 0 ? acc / (wSum / 100) : null;
    })
    .filter((v): v is number => v !== null);

  const classAvg = finals.length ? finals.reduce((a, b) => a + b, 0) / finals.length : null;
  const highest = finals.length ? Math.max(...finals) : null;
  const lowest = finals.length ? Math.min(...finals) : null;
  const passed = finals.filter((f) => f >= 75).length;

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>${pageCss()}</style></head>
<body>
  <h1>CLASS RECORD</h1>
  <h2>Tugbo Integrated School — ${esc(section.gradeLevel)}, ${esc(section.section)}</h2>
  <table class="meta">
    <tr><td class="label">Subject</td><td><b>${esc(subject.name)}</b></td>
        <td class="label">Quarter</td><td><b>Q${quarter}</b></td></tr>
    <tr><td class="label">School Year</td><td>${esc(section.schoolYear)}</td>
        <td class="label">Teacher</td><td>${esc(subject.teacherName || data.teacherName || '—')}</td></tr>
    <tr><td class="label">Weights</td><td colspan="3">
      Quiz ${weights.quizzes}% · Assign ${weights.assignments}% · Act ${weights.activities}% ·
      PT ${weights.performanceTasks}% · Exam ${weights.examinations}%
      ${subject.transmute ? ' · transmuted (DO 8, s. 2015)' : ''}
    </td></tr>
  </table>

  <table class="grid">
    <thead><tr>${headerCells.map((h) => `<th>${h}</th>`).join('')}</tr></thead>
    <tbody>
      ${rows.join('') || '<tr><td colspan="' + colCount + '">No students in this class.</td></tr>'}
      ${avgRow}
    </tbody>
  </table>

  <table class="summary">
    <tr>
      <td>Class Average<br><b>${fmt(classAvg, 2)}</b></td>
      <td>Highest<br><b>${fmt(highest, 2)}</b></td>
      <td>Lowest<br><b>${fmt(lowest, 2)}</b></td>
      <td>Passed (≥75)<br><b>${passed} / ${students.length}</b></td>
    </tr>
  </table>

  <table class="signatures">
    <tr>
      <td><span class="sign-line">Teacher's Signature</span></td>
      <td><span class="sign-line">Head of School</span></td>
    </tr>
  </table>

  <div class="footer">Generated by TIS ClassTrack · ${new Date().toLocaleDateString()} · Records are stored on the teacher's device.</div>
</body>
</html>`;
}

/** Roster-only report (names, LRN, guardian, seat). */
export function buildRosterHtml(
  data: BackupData,
  sectionId: string,
  section: { gradeLevel: string; section: string; schoolYear: string },
): string {
  const students = Object.values(data.students)
    .filter((s) => s.sectionId === sectionId)
    .sort((a, b) => a.seatNumber - b.seatNumber);

  const rows = students.map(
    (st, i) => `<tr>
      <td>${st.seatNumber}</td>
      <td class="name">${esc(st.fullName)}</td>
      <td>${esc(st.lrn || '—')}</td>
      <td>${esc(st.gender || '—')}</td>
      <td>${esc(st.birthday || '—')}</td>
      <td>${esc(st.guardianName || '—')}</td>
      <td>${esc(st.guardianContact || '—')}</td>
    </tr>`,
  );

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>${pageCss()}</style></head>
<body>
  <h1>CLASS ROSTER</h1>
  <h2>Tugbo Integrated School — ${esc(section.gradeLevel)}, ${esc(section.section)} · SY ${esc(section.schoolYear)}</h2>
  <table class="grid">
    <thead><tr>
      <th>Seat</th><th>Name</th><th>LRN</th><th>Gender</th><th>Birthday</th><th>Guardian</th><th>Contact</th>
    </tr></thead>
    <tbody>${rows.join('') || '<tr><td colspan="7">No students.</td></tr>'}</tbody>
  </table>
  <div class="footer">Generated by TIS ClassTrack · ${new Date().toLocaleDateString()}</div>
</body>
</html>`;
}

function transmuteOnSheet(raw: number): number {
  const anchors: [number, number][] = [
    [60, 75], [65, 79], [70, 83], [75, 87], [80, 91], [85, 95], [90, 99], [100, 100],
  ];
  if (raw < 60) return raw;
  if (raw >= 100) return 100;
  for (let i = 0; i < anchors.length - 1; i++) {
    const [x0, y0] = anchors[i];
    const [x1, y1] = anchors[i + 1];
    if (raw >= x0 && raw <= x1) return y0 + ((raw - x0) / (x1 - x0)) * (y1 - y0);
  }
  return raw;
}

/** Wide CSV of computed grades for a subject + quarter (spreadsheet-ready). */
export function buildClassRecordCsv(
  data: BackupData,
  section: { gradeLevel: string; section: string; schoolYear: string },
  subject: Subject,
  quarter: Quarter,
): string {
  const students = Object.values(data.students)
    .filter((s) => s.sectionId === subject.sectionId)
    .sort((a, b) => a.seatNumber - b.seatNumber);
  const sheet = data.sheets[`${subject.id}::q${quarter}`];
  const header = [
    'Seat', 'Student', 'LRN', 'Birthday', 'Guardian', 'Contact',
    ...COMPONENTS.map((c) => `${c.short} %`),
    'Final Grade', 'Remarks',
  ];
  const lines: string[] = [header.join(',')];
  const q = (v: string | number) => {
    const s = String(v ?? '');
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const pctOf = (st: Student, c: (typeof COMPONENTS)[number]): number | null => {
    const items = sheet?.items[c.key] ?? [];
    let earned = 0;
    let max = 0;
    for (const it of items) {
      const v = data.scores[`${sheet?.id}|${st.id}|${it.id}`];
      if (typeof v === 'number') {
        earned += v;
        max += it.max;
      }
    }
    return max > 0 ? (earned / max) * 100 : null;
  };
  const finalOf = (st: Student): number | null => {
    let acc = 0;
    let wSum = 0;
    for (const c of COMPONENTS) {
      const pct = pctOf(st, c);
      if (pct !== null) {
        acc += (pct * subject.weights[c.key]) / 100;
        wSum += subject.weights[c.key];
      }
    }
    return wSum > 0 ? acc / (wSum / 100) : null;
  };
  for (const st of students) {
    const pcts = COMPONENTS.map((c) => pctOf(st, c));
    const final = finalOf(st);
    lines.push(
      [
        st.seatNumber,
        st.fullName,
        st.lrn,
        st.birthday,
        st.guardianName,
        st.guardianContact,
        ...pcts.map((p) => (p === null ? '' : p.toFixed(1))),
        final === null ? '' : final.toFixed(2),
        gradeRemarks(final),
      ]
        .map(q)
        .join(','),
    );
  }
  const finals = students.map(finalOf).filter((v): v is number => v !== null);
  const classAvg = finals.length ? finals.reduce((a, b) => a + b, 0) / finals.length : null;
  lines.push('');
  lines.push(
    [
      'CLASS AVERAGE',
      '',
      '',
      '',
      '',
      '',
      ...COMPONENTS.map(() => ''),
      classAvg === null ? '' : classAvg.toFixed(2),
      '',
    ]
      .map(q)
      .join(','),
  );
  return lines.join('\r\n');
}
