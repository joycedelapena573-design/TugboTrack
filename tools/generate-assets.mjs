/**
 * Generates the TIS ClassTrack brand assets:
 *  - assets/school-logo.png   (school seal, transparent)
 *  - assets/icon.png          (app icon)
 *  - assets/android-icon-*.png (adaptive icon layers + monochrome)
 *  - assets/splash-icon.png   (native splash mark)
 *  - assets/favicon.png
 *
 * The seal text is converted to vector glyph paths with opentype.js so no
 * system fonts are required to rasterize. Run: node tools/generate-assets.mjs
 */
import opentype from 'opentype.js';
import sharp from 'sharp';
import { mkdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const OUT = path.join(ROOT, 'assets');
mkdirSync(OUT, { recursive: true });

function loadFont(rel) {
  const buf = readFileSync(path.join(ROOT, rel));
  return opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
}

const poppinsBold = loadFont(
  'node_modules/@expo-google-fonts/poppins/700Bold/Poppins_700Bold.ttf',
);

const NAVY = '#0A3A8C';
const NAVY_DARK = '#082E6E';
const GOLD = '#F2B01E';
const GOLD_DARK = '#D08E0A';

/** Apply an affine matrix to an opentype Path, returning a new Path. */
function transformPath(path, m) {
  const out = new opentype.Path();
  const ap = (x, y) => [m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f];
  for (const c of path.commands) {
    if (c.type === 'M') {
      const [x, y] = ap(c.x, c.y);
      out.moveTo(x, y);
    } else if (c.type === 'L') {
      const [x, y] = ap(c.x, c.y);
      out.lineTo(x, y);
    } else if (c.type === 'C') {
      const [x1, y1] = ap(c.x1, c.y1);
      const [x2, y2] = ap(c.x2, c.y2);
      const [x, y] = ap(c.x, c.y);
      out.curveTo(x1, y1, x2, y2, x, y);
    } else if (c.type === 'Q') {
      const [x1, y1] = ap(c.x1, c.y1);
      const [x, y] = ap(c.x, c.y);
      out.quadraticCurveTo(x1, y1, x, y);
    } else if (c.type === 'Z') {
      out.closePath();
    }
  }
  return out;
}

/** Text laid along a circular arc, returned as SVG path data. */
function arcText(font, text, { cx, cy, r, size, center = 0, bottom = false, tracking = 0.1 }) {
  const chars = [...text];
  const em = font.unitsPerEm;
  const glyphs = chars.map((ch) => font.charToGlyph(ch));
  const advances = glyphs.map((g) => (g.advanceWidth / em) * size);
  const spacing = size * tracking;
  const total = advances.reduce((a, b) => a + b, 0) + spacing * (chars.length - 1);
  const deg = (px) => (px / r) * (180 / Math.PI);
  const totalAngle = deg(total);
  let angle = bottom ? center + totalAngle / 2 : center - totalAngle / 2;
  let d = '';
  for (let i = 0; i < glyphs.length; i++) {
    const advAngle = deg(advances[i]);
    const mid = bottom ? angle - advAngle / 2 : angle + advAngle / 2;
    const rad = (mid * Math.PI) / 180;
    const x = cx + r * Math.sin(rad);
    const y = cy - r * Math.cos(rad);
    const rot = bottom ? mid + 180 : mid;
    const p = glyphs[i].getPath(x, y, size);
    const a = (rot * Math.PI) / 180;
    const cos = Math.cos(a);
    const sin = Math.sin(a);
    const rotated = transformPath(p, {
      a: cos,
      b: sin,
      c: -sin,
      d: cos,
      e: x - cos * x + sin * y,
      f: y - sin * x - cos * y,
    });
    d += rotated.toPathData(2);
    angle += bottom ? -(advAngle + deg(spacing)) : advAngle + deg(spacing);
  }
  return d;
}

/** Horizontally centered straight text as path data. */
function centerText(font, text, { cx, y, size }) {
  const w = font.getAdvanceWidth(text, size);
  return font.getPath(text, cx - w / 2, y, size).toPathData(2);
}

/** Scalloped outer edge path for the seal. */
function scallop(cx, cy, r, bumps, bumpR) {
  const step = (Math.PI * 2) / bumps;
  let d = '';
  for (let i = 0; i <= bumps; i++) {
    const a = i * step;
    const x = cx + r * Math.cos(a);
    const y = cy + r * Math.sin(a);
    d += i === 0 ? `M ${x.toFixed(1)} ${y.toFixed(1)} ` : `A ${bumpR} ${bumpR} 0 0 1 ${x.toFixed(1)} ${y.toFixed(1)} `;
  }
  return d + 'Z';
}

/** Radial sunburst rays behind the torch. */
function sunburst(cx, cy, inner, outer, count) {
  let d = '';
  const step = 360 / count;
  for (let i = 0; i < count; i++) {
    const a0 = ((i * step - 1.1) * Math.PI) / 180;
    const a1 = ((i * step + 1.1) * Math.PI) / 180;
    const am = ((i * step) * Math.PI) / 180;
    const x0 = cx + inner * Math.cos(a0);
    const y0 = cy + inner * Math.sin(a0);
    const x1 = cx + outer * Math.cos(am);
    const y1 = cy + outer * Math.sin(am);
    const x2 = cx + inner * Math.cos(a1);
    const y2 = cy + inner * Math.sin(a1);
    d += `M${x0.toFixed(1)},${y0.toFixed(1)} L${x1.toFixed(1)},${y1.toFixed(1)} L${x2.toFixed(1)},${y2.toFixed(1)} Z `;
  }
  return d;
}

/** One laurel branch: stem polyline along an arc, tapering leaves on the outside. */
function laurel(cx, cy, r, fromDeg, toDeg, count, rotOffset) {
  let stem = '';
  const steps = 28;
  for (let i = 0; i <= steps; i++) {
    const aDeg = fromDeg + (toDeg - fromDeg) * (i / steps);
    const a = (aDeg * Math.PI) / 180;
    const x = cx + r * Math.cos(a);
    const y = cy + r * Math.sin(a);
    stem += `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)} `;
  }
  let leaves = '';
  for (let i = 0; i < count; i++) {
    const t = count === 1 ? 0.5 : i / (count - 1);
    const aDeg = fromDeg + (toDeg - fromDeg) * t;
    const a = (aDeg * Math.PI) / 180;
    const scale = 1 - 0.3 * t;
    const rr = r + 15;
    const x = cx + rr * Math.cos(a);
    const y = cy + rr * Math.sin(a);
    const rot = aDeg + rotOffset;
    leaves += `<ellipse cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" rx="${(30 * scale).toFixed(1)}" ry="${(13 * scale).toFixed(1)}" transform="rotate(${rot.toFixed(1)} ${x.toFixed(1)} ${y.toFixed(1)})" fill="#2E8B45"/>`;
  }
  return `<path d="${stem}" stroke="#256E38" stroke-width="9" fill="none" stroke-linecap="round"/>` + leaves;
}

function defsSVG(idSuffix) {
  return `
  <defs>
    <radialGradient id="glow${idSuffix}" cx="50%" cy="42%" r="60%">
      <stop offset="0%" stop-color="#FFF6E0"/>
      <stop offset="55%" stop-color="#FFE3A8"/>
      <stop offset="100%" stop-color="#FFCF8A"/>
    </radialGradient>
    <linearGradient id="gold${idSuffix}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFD75E"/>
      <stop offset="100%" stop-color="${GOLD_DARK}"/>
    </linearGradient>
    <linearGradient id="flame${idSuffix}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFC400"/>
      <stop offset="45%" stop-color="#FB6B00"/>
      <stop offset="100%" stop-color="#E23B24"/>
    </linearGradient>
    <clipPath id="field${idSuffix}"><circle cx="512" cy="512" r="378"/></clipPath>
  </defs>`;
}

/** Inner artwork (sunburst, laurels, torch, book, ribbon) around 512,512. */
function artSVG(idSuffix) {
  const cx = 512;
  const cy = 512;
  const yearText = centerText(poppinsBold, '1965', { cx, y: cy + 292, size: 46 });
  return `
  <g clip-path="url(#field${idSuffix})">
    <path d="${sunburst(cx, cy - 40, 120, 400, 40)}" fill="#FFD98F" opacity="0.75"/>

    <!-- laurel wreath -->
    ${laurel(cx, cy + 40, 296, 96, 208, 8, 72)}
    ${laurel(cx, cy + 40, 296, 84, -28, 8, -72)}

    <!-- open book -->
    <g>
      <path d="M ${cx - 170} ${cy + 120} C ${cx - 120} ${cy + 74} ${cx - 56} ${cy + 66} ${cx - 10} ${cy + 88} L ${cx - 10} ${cy + 186} C ${cx - 56} ${cy + 164} ${cx - 120} ${cy + 172} ${cx - 170} ${cy + 216} Z"
        fill="#FFFFFF" stroke="${NAVY}" stroke-width="11" stroke-linejoin="round"/>
      <path d="M ${cx + 170} ${cy + 120} C ${cx + 120} ${cy + 74} ${cx + 56} ${cy + 66} ${cx + 10} ${cy + 88} L ${cx + 10} ${cy + 186} C ${cx + 56} ${cy + 164} ${cx + 120} ${cy + 172} ${cx + 170} ${cy + 216} Z"
        fill="#FFFFFF" stroke="${NAVY}" stroke-width="11" stroke-linejoin="round"/>
      <line x1="${cx}" y1="${cy + 88}" x2="${cx}" y2="${cy + 188}" stroke="${NAVY}" stroke-width="9"/>
      <path d="M ${cx - 140} ${cy + 132} C ${cx - 104} ${cy + 104} ${cx - 60} ${cy + 100} ${cx - 34} ${cy + 112}" stroke="#9FB6DC" stroke-width="7" fill="none" stroke-linecap="round"/>
      <path d="M ${cx - 136} ${cy + 160} C ${cx - 102} ${cy + 134} ${cx - 62} ${cy + 130} ${cx - 36} ${cy + 140}" stroke="#9FB6DC" stroke-width="7" fill="none" stroke-linecap="round"/>
      <path d="M ${cx + 140} ${cy + 132} C ${cx + 104} ${cy + 104} ${cx + 60} ${cy + 100} ${cx + 34} ${cy + 112}" stroke="#9FB6DC" stroke-width="7" fill="none" stroke-linecap="round"/>
      <path d="M ${cx + 136} ${cy + 160} C ${cx + 102} ${cy + 134} ${cx + 62} ${cy + 130} ${cx + 36} ${cy + 140}" stroke="#9FB6DC" stroke-width="7" fill="none" stroke-linecap="round"/>
      <!-- book cover -->
      <path d="M ${cx - 178} ${cy + 214} C ${cx - 110} ${cy + 178} ${cx - 48} ${cy + 186} ${cx} ${cy + 206} C ${cx + 48} ${cy + 186} ${cx + 110} ${cy + 178} ${cx + 178} ${cy + 214} L ${cx + 172} ${cy + 236} C ${cx + 106} ${cy + 202} ${cx + 46} ${cy + 210} ${cx} ${cy + 228} C ${cx - 46} ${cy + 210} ${cx - 106} ${cy + 202} ${cx - 172} ${cy + 236} Z"
        fill="${NAVY}"/>
    </g>

    <!-- torch -->
    <g>
      <rect x="${cx - 17}" y="${cy - 60}" width="34" height="180" rx="14" fill="url(#gold${idSuffix})"/>
      <rect x="${cx - 26}" y="${cy - 76}" width="52" height="26" rx="10" fill="${GOLD_DARK}"/>
      <path d="M ${cx - 58} ${cy - 76} L ${cx + 58} ${cy - 76} L ${cx + 40} ${cy - 130} L ${cx - 40} ${cy - 130} Z" fill="url(#gold${idSuffix})" stroke="${GOLD_DARK}" stroke-width="5"/>
      <path d="M ${cx} ${cy - 290} C ${cx + 52} ${cy - 236} ${cx + 66} ${cy - 190} ${cx + 44} ${cy - 150} C ${cx + 30} ${cy - 124} ${cx + 12} ${cy - 120} ${cx} ${cy - 120} C ${cx - 12} ${cy - 120} ${cx - 30} ${cy - 124} ${cx - 44} ${cy - 150} C ${cx - 66} ${cy - 190} ${cx - 52} ${cy - 236} ${cx} ${cy - 290} Z" fill="url(#flame${idSuffix})"/>
      <path d="M ${cx} ${cy - 240} C ${cx + 26} ${cy - 208} ${cx + 30} ${cy - 180} ${cx + 16} ${cy - 158} C ${cx + 8} ${cy - 146} ${cx + 3} ${cy - 144} ${cx} ${cy - 144} C ${cx - 3} ${cy - 144} ${cx - 8} ${cy - 146} ${cx - 16} ${cy - 158} C ${cx - 30} ${cy - 180} ${cx - 26} ${cy - 208} ${cx} ${cy - 240} Z" fill="#FFD23F"/>
    </g>

    <!-- year ribbon -->
    <g>
      <path d="M ${cx - 118} ${cy + 244} L ${cx + 118} ${cy + 244} L ${cx + 102} ${cy + 298} L ${cx - 102} ${cy + 298} Z" fill="url(#gold${idSuffix})" stroke="${GOLD_DARK}" stroke-width="5"/>
      <path d="M ${cx - 150} ${cy + 252} L ${cx - 116} ${cy + 252} L ${cx - 116} ${cy + 290} L ${cx - 150} ${cy + 302} Z" fill="${GOLD_DARK}"/>
      <path d="M ${cx + 150} ${cy + 252} L ${cx + 116} ${cy + 252} L ${cx + 116} ${cy + 290} L ${cx + 150} ${cy + 302} Z" fill="${GOLD_DARK}"/>
      <path d="${yearText}" fill="${NAVY_DARK}"/>
    </g>
  </g>`;
}

function bandSVG(idSuffix) {
  const cx = 512;
  const cy = 512;
  const topText = arcText(poppinsBold, 'TUGBO INTEGRATED SCHOOL', {
    cx, cy, r: 414, size: 56, center: 0, tracking: 0.1,
  });
  const bottomText = arcText(poppinsBold, 'Tugbo, Mobo, Masbate', {
    cx, cy, r: 450, size: 42, center: 180, bottom: true, tracking: 0.09,
  });
  return `
  <path d="${topText}" fill="#FFFFFF"/>
  <path d="${bottomText}" fill="#FFFFFF"/>
  <circle cx="${cx - 434}" cy="${cy}" r="15" fill="#FFFFFF"/>
  <circle cx="${cx + 434}" cy="${cy}" r="15" fill="#FFFFFF"/>`;
}

function ringsSVG(idSuffix) {
  const cx = 512;
  const cy = 512;
  return `
  <path d="${scallop(cx, cy, 470, 44, 18)}" fill="${NAVY}"/>
  <circle cx="${cx}" cy="${cy}" r="456" fill="#FFFFFF"/>
  <circle cx="${cx}" cy="${cy}" r="450" fill="${NAVY}"/>
  <circle cx="${cx}" cy="${cy}" r="396" fill="#FFFFFF"/>
  <circle cx="${cx}" cy="${cy}" r="382" fill="url(#glow${idSuffix})"/>
  <circle cx="${cx}" cy="${cy}" r="382" fill="none" stroke="${NAVY}" stroke-width="14"/>
  <circle cx="${cx}" cy="${cy}" r="362" fill="none" stroke="${NAVY}" stroke-width="5"/>`;
}

/** The TIS school seal, drawn inside a 1024x1024 box (transparent outside). */
function sealSVG({ idSuffix = '' } = {}) {
  return `
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  ${defsSVG(idSuffix)}
  ${ringsSVG(idSuffix)}
  ${artSVG(idSuffix)}
  ${bandSVG(idSuffix)}
</svg>`;
}

async function render(svg, size, file) {
  await sharp(Buffer.from(svg), { density: 150 })
    .resize(size, size)
    .png()
    .toFile(path.join(OUT, file));
  console.log('wrote', file);
}

/** White silhouette of the seal for Android themed icons. */
function monochromeSVG() {
  const cx = 512;
  const cy = 512;
  return `
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <path d="${scallop(cx, cy, 470, 44, 18)}" fill="#FFFFFF"/>
  <circle cx="${cx}" cy="${cy}" r="440" fill="none" stroke="#EAF2FD" stroke-width="26"/>
  <circle cx="${cx}" cy="${cy}" r="382" fill="none" stroke="#FFFFFF" stroke-width="14"/>
  <path d="${sunburst(cx, cy - 40, 130, 340, 24)}" fill="#FFFFFF" opacity="0.55"/>
  <g fill="#FFFFFF">
    <rect x="${cx - 17}" y="${cy - 60}" width="34" height="180" rx="14"/>
    <path d="M ${cx - 58} ${cy - 76} L ${cx + 58} ${cy - 76} L ${cx + 40} ${cy - 130} L ${cx - 40} ${cy - 130} Z"/>
    <path d="M ${cx} ${cy - 290} C ${cx + 52} ${cy - 236} ${cx + 66} ${cy - 190} ${cx + 44} ${cy - 150} C ${cx + 30} ${cy - 124} ${cx + 12} ${cy - 120} ${cx} ${cy - 120} C ${cx - 12} ${cy - 120} ${cx - 30} ${cy - 124} ${cx - 44} ${cy - 150} C ${cx - 66} ${cy - 190} ${cx - 52} ${cy - 236} ${cx} ${cy - 290} Z"/>
    <path d="M ${cx - 170} ${cy + 120} C ${cx - 120} ${cy + 74} ${cx - 56} ${cy + 66} ${cx - 10} ${cy + 88} L ${cx - 10} ${cy + 186} C ${cx - 56} ${cy + 164} ${cx - 120} ${cy + 172} ${cx - 170} ${cy + 216} Z"/>
    <path d="M ${cx + 170} ${cy + 120} C ${cx + 120} ${cy + 74} ${cx + 56} ${cy + 66} ${cx + 10} ${cy + 88} L ${cx + 10} ${cy + 186} C ${cx + 56} ${cy + 164} ${cx + 120} ${cy + 172} ${cx + 170} ${cy + 216} Z"/>
    <path d="M ${cx - 118} ${cy + 244} L ${cx + 118} ${cy + 244} L ${cx + 102} ${cy + 298} L ${cx - 102} ${cy + 298} Z"/>
  </g>
</svg>`;
}

async function main() {
  const seal = sealSVG();

  // Transparent school seal for in-app use
  await render(seal, 1024, 'school-logo.png');

  // Native splash mark (seal on white circle-free background handled by config)
  await render(sealSVG({ idSuffix: 's' }), 512, 'splash-icon.png');

  // App icon: brand background + wave + seal
  const iconSVG = `
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  ${defsSVG('i')}
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F3F8FF"/>
      <stop offset="100%" stop-color="#D7E7FB"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <path d="M 0 780 C 220 700 380 850 620 810 C 800 780 920 720 1024 750 L 1024 1024 L 0 1024 Z" fill="${NAVY}" opacity="0.92"/>
  <path d="M 0 826 C 240 756 400 896 640 856 C 820 826 930 776 1024 800 L 1024 1024 L 0 1024 Z" fill="#FFFFFF" opacity="0.14"/>
  <g transform="translate(512 470) scale(0.60) translate(-512 -512)">
    ${ringsSVG('i')}
    ${artSVG('i')}
    ${bandSVG('i')}
  </g>
</svg>`;
  await render(iconSVG, 1024, 'icon.png');

  // Android adaptive icon: foreground = seal in safe zone, background = flat brand color
  const fgSVG = `
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  ${defsSVG('g')}
  <g transform="translate(512 512) scale(0.56) translate(-512 -512)">
    ${ringsSVG('g')}
    ${artSVG('g')}
    ${bandSVG('g')}
  </g>
</svg>`;
  await render(fgSVG, 1024, 'android-icon-foreground.png');

  await render(
    `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"><rect width="1024" height="1024" fill="#EAF2FD"/></svg>`,
    1024,
    'android-icon-background.png',
  );

  // Monochrome (Material You / themed icons): white silhouette
  await render(monochromeSVG(), 1024, 'android-icon-monochrome.png');

  // Favicon
  await render(sealSVG({ idSuffix: 'f' }), 128, 'favicon.png');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
