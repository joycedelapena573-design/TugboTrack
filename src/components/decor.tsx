/** Brand illustrations recreated from the approved mockups (react-native-svg). */
import React from 'react';
import Svg, { Circle, Defs, G, LinearGradient, Line, Path, Polygon, Rect, Stop } from 'react-native-svg';

import { colors } from '../lib/theme';

const NAVY = '#0A3A8C';
const NAVY_DEEP = '#0B2A6B';
const BLUE = '#2E6BE6';
const BLUE_LIGHT = '#8FB6F5';
const BLUE_PALE = '#CFE0FA';
const GOLD = '#F2B01E';

/** Open book with a graduation cap — the "TIS ClassTrack" mark (mockup header). */
export function BrandMark({ size = 56 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      {/* open book */}
      <Path d="M12 58 C24 48 38 47 48 53 L48 82 C38 76 24 77 12 86 Z" fill={NAVY} />
      <Path d="M88 58 C76 48 62 47 52 53 L52 82 C62 76 76 77 88 86 Z" fill={BLUE} />
      <Path d="M48 53 L50 54 L52 53 L52 82 L50 84 L48 82 Z" fill={NAVY_DEEP} />
      {/* pages hint */}
      <Path d="M20 62 C28 57 37 57 43 60" stroke="#FFFFFF" strokeWidth="2.4" fill="none" strokeLinecap="round" opacity="0.85" />
      <Path d="M20 70 C28 65 37 65 43 68" stroke="#FFFFFF" strokeWidth="2.4" fill="none" strokeLinecap="round" opacity="0.85" />
      <Path d="M80 62 C72 57 63 57 57 60" stroke="#FFFFFF" strokeWidth="2.4" fill="none" strokeLinecap="round" opacity="0.85" />
      <Path d="M80 70 C72 65 63 65 57 68" stroke="#FFFFFF" strokeWidth="2.4" fill="none" strokeLinecap="round" opacity="0.85" />
      {/* graduation cap */}
      <Polygon points="50,10 86,26 50,42 14,26" fill={NAVY_DEEP} />
      <Path d="M32 34 L32 46 C32 51 42 55 50 55 C58 55 68 51 68 46 L68 34 L50 42 Z" fill={NAVY} />
      <Line x1="86" y1="26" x2="86" y2="44" stroke={GOLD} strokeWidth="3" strokeLinecap="round" />
      <Circle cx="86" cy="47" r="4" fill={GOLD} />
      <Polygon points="50,16 52.6,22.4 59.4,22.6 54.1,26.8 55.9,33.4 50,29.7 44.1,33.4 45.9,26.8 40.6,22.6 47.4,22.4" fill={GOLD} />
    </Svg>
  );
}

/** Padlock + shield illustration inside a soft blob (mockup MPIN screens). */
export function LockArt({ size = 210 }: { size?: number }) {
  return (
    <Svg width={size} height={size * 0.86} viewBox="0 0 240 206">
      <Defs>
        <LinearGradient id="lockGrad" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#1746B8" />
          <Stop offset="1" stopColor={NAVY_DEEP} />
        </LinearGradient>
        <LinearGradient id="shieldGrad" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#3C7BFF" />
          <Stop offset="1" stopColor="#2258D8" />
        </LinearGradient>
      </Defs>
      {/* soft blob background */}
      <Path
        d="M52 26 C104 -8 176 0 210 38 C244 76 236 134 196 166 C156 198 84 204 44 172 C4 140 0 60 52 26 Z"
        fill="#E4EDFD"
      />
      <Circle cx="66" cy="52" r="7" fill="#CFE0FA" />
      <Circle cx="196" cy="60" r="9" fill="#CFE0FA" />
      <Circle cx="206" cy="150" r="6" fill="#CFE0FA" />
      {/* leaves left */}
      <G>
        <Path d="M40 120 C22 108 18 84 26 66 C44 76 52 100 40 120 Z" fill={BLUE_LIGHT} />
        <Path d="M34 150 C18 140 12 118 18 100 C36 108 44 134 34 150 Z" fill={BLUE} />
      </G>
      {/* leaves right */}
      <G>
        <Path d="M204 122 C222 110 226 86 218 68 C200 78 192 102 204 122 Z" fill={BLUE_LIGHT} />
      </G>
      {/* padlock */}
      <Path
        d="M92 96 L92 74 C92 44 110 28 128 28 C146 28 164 44 164 74 L164 96"
        stroke="url(#lockGrad)"
        strokeWidth="17"
        fill="none"
        strokeLinecap="round"
      />
      <Rect x="76" y="92" width="104" height="84" rx="20" fill="url(#lockGrad)" />
      <Rect x="94" y="116" width="68" height="30" rx="12" fill="#FFFFFF" />
      <Circle cx="108" cy="131" r="5" fill={NAVY} />
      <Circle cx="128" cy="131" r="5" fill={NAVY} />
      <Circle cx="148" cy="131" r="5" fill={NAVY} />
      {/* shield with check */}
      <Path d="M186 96 L214 104 L214 130 C214 146 202 156 186 162 C170 156 158 146 158 130 L158 104 Z" fill="url(#shieldGrad)" />
      <Path d="M174 128 L183 137 L199 118" stroke="#FFFFFF" strokeWidth="6" fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </Svg>
  );
}

/** Decorative open-book outline (top-right of the splash screen). */
export function BookDoodle({ size = 120 }: { size?: number }) {
  return (
    <Svg width={size} height={size * 0.8} viewBox="0 0 120 96">
      <Path d="M10 30 C26 18 46 18 58 26 L58 70 C46 62 26 62 10 74 Z" stroke={BLUE_PALE} strokeWidth="5" fill="none" strokeLinejoin="round" />
      <Path d="M110 30 C94 18 74 18 62 26 L62 70 C74 62 94 62 110 74 Z" stroke={BLUE_PALE} strokeWidth="5" fill="none" strokeLinejoin="round" />
      <Line x1="60" y1="26" x2="60" y2="72" stroke={BLUE_PALE} strokeWidth="5" strokeLinecap="round" />
      <Path d="M108 8 C112 14 114 16 120 18" stroke={BLUE_PALE} strokeWidth="4" fill="none" strokeLinecap="round" />
      <Path d="M96 2 L98 10" stroke={BLUE_PALE} strokeWidth="4" fill="none" strokeLinecap="round" />
    </Svg>
  );
}

/** Stack of books (bottom-left of the splash screen). */
export function BookStack({ width = 250 }: { width?: number }) {
  const height = width * 0.62;
  return (
    <Svg width={width} height={height} viewBox="0 0 250 155">
      {/* bottom book (blue) */}
      <G>
        <Rect x="22" y="96" width="212" height="34" rx="7" fill={BLUE} />
        <Rect x="22" y="96" width="212" height="12" rx="6" fill="#FFFFFF" />
        <Rect x="22" y="122" width="212" height="8" rx="4" fill={NAVY_DEEP} opacity="0.35" />
      </G>
      {/* middle book (gold) */}
      <G>
        <Rect x="10" y="62" width="204" height="32" rx="7" fill={GOLD} />
        <Rect x="10" y="62" width="204" height="11" rx="5" fill="#FFFFFF" />
        <Rect x="10" y="87" width="204" height="7" rx="3.5" fill="#B57E06" opacity="0.5" />
      </G>
      {/* top book (navy) */}
      <G>
        <Rect x="34" y="26" width="196" height="34" rx="7" fill={NAVY_DEEP} />
        <Rect x="34" y="26" width="196" height="12" rx="6" fill="#FFFFFF" />
        <Rect x="34" y="52" width="196" height="8" rx="4" fill="#061F52" opacity="0.5" />
      </G>
      {/* small leaf */}
      <Path d="M4 128 C0 116 6 104 18 100 C22 114 16 126 4 128 Z" fill="#2E8B45" opacity="0.9" />
    </Svg>
  );
}

/** Bottom wave for the splash screen (navy, with a lighter crest). */
export function BottomWave({ width = 400, height = 190 }: { width?: number; height?: number }) {
  return (
    <Svg width={width} height={height} viewBox="0 0 400 190" preserveAspectRatio="none">
      <Path d="M0 78 C90 34 168 92 250 70 C318 52 366 22 400 30 L400 190 L0 190 Z" fill="#4E86E8" />
      <Path d="M0 96 C96 52 170 110 256 88 C322 71 368 44 400 50 L400 190 L0 190 Z" fill={NAVY} />
      <Path d="M0 78 C90 34 168 92 250 70 C318 52 366 22 400 30" stroke={GOLD} strokeWidth="3" fill="none" opacity="0.85" />
    </Svg>
  );
}

/** Top-left corner curve for the splash screen (navy + gold arc). */
export function TopCornerCurve({ width = 220, height = 150 }: { width?: number; height?: number }) {
  return (
    <Svg width={width} height={height} viewBox="0 0 220 150">
      <Path d="M0 0 L120 0 C70 30 30 74 0 142 Z" fill={NAVY} />
      <Path d="M120 0 C70 30 30 74 0 142" stroke={GOLD} strokeWidth="4" fill="none" />
      <Path d="M0 128 C40 60 84 24 150 0 L128 0 C74 28 36 74 8 146 Z" fill="#1E58C8" opacity="0.55" />
    </Svg>
  );
}

/** Small leaf accent used around the splash screen. */
export function Leaf({ size = 60, color = BLUE_LIGHT }: { size?: number; color?: string }) {
  return (
    <Svg width={size} height={size * 1.2} viewBox="0 0 60 72">
      <Path d="M30 4 C52 22 56 48 40 68 C18 60 8 34 30 4 Z" fill={color} opacity="0.55" />
      <Path d="M34 14 C40 30 40 48 36 60" stroke="#FFFFFF" strokeWidth="3" fill="none" strokeLinecap="round" opacity="0.7" />
    </Svg>
  );
}

/** Clipboard-check tile used in the splash loading pill. */
export function ClipboardCheckIcon({ size = 34 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 40 40">
      <Rect x="7" y="6" width="26" height="30" rx="6" fill={BLUE} />
      <Rect x="14" y="3" width="12" height="7" rx="3.5" fill={NAVY_DEEP} />
      <Circle cx="28.5" cy="29.5" r="8.5" fill={NAVY_DEEP} stroke="#FFFFFF" strokeWidth="2.5" />
      <Path d="M24.8 29.6 L27.4 32.2 L32.4 26.8" stroke="#FFFFFF" strokeWidth="2.6" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      <Line x1="13" y1="17" x2="22" y2="17" stroke="#FFFFFF" strokeWidth="2.6" strokeLinecap="round" />
      <Line x1="13" y1="23" x2="19" y2="23" stroke="#FFFFFF" strokeWidth="2.6" strokeLinecap="round" />
    </Svg>
  );
}

/** Underline swoosh under the splash tagline. */
export function Swoosh({ width = 170 }: { width?: number }) {
  return (
    <Svg width={width} height={14} viewBox="0 0 170 14">
      <Path d="M6 9 C46 2 124 2 164 8" stroke={BLUE_LIGHT} strokeWidth="5" fill="none" strokeLinecap="round" />
    </Svg>
  );
}

/** Graduation cap that sits on top of the "ClassTrack" wordmark. */
export function CapIcon({ size = 44 }: { size?: number }) {
  return (
    <Svg width={size} height={size * 0.72} viewBox="0 0 64 46">
      <Polygon points="32,3 61,15 32,27 3,15" fill={NAVY_DEEP} />
      <Path d="M14 20 L14 31 C14 36 22 40 32 40 C42 40 50 36 50 31 L50 20 L32 27 Z" fill={NAVY} />
      <Line x1="61" y1="15" x2="61" y2="30" stroke={GOLD} strokeWidth="2.6" strokeLinecap="round" />
      <Circle cx="61" cy="32.5" r="3.2" fill={GOLD} />
    </Svg>
  );
}

/** Soft decorative circle behind the MPIN screen header art. */
export function SoftBlob({ size = 320 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 320 320">
      <Circle cx="160" cy="160" r="150" fill="#EFF5FE" />
    </Svg>
  );
}

export const decorColors = { colors };
