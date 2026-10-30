/// Brand illustrations recreated from the approved mockups.
///
/// The path data is the same vector art the earlier build drew with
/// react-native-svg, so the artwork is pixel-identical — it is rendered here
/// with flutter_svg from the same markup.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _navy = '#0A3A8C';
const String _navyDeep = '#0B2A6B';
const String _blue = '#2E6BE6';
const String _blueLight = '#8FB6F5';
const String _bluePale = '#CFE0FA';
const String _gold = '#F2B01E';

/// Open book with a graduation cap — the "TIS ClassTrack" mark.
Widget brandMark({double size = 56}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M12 58 C24 48 38 47 48 53 L48 82 C38 76 24 77 12 86 Z" fill="$_navy"/>
  <path d="M88 58 C76 48 62 47 52 53 L52 82 C62 76 76 77 88 86 Z" fill="$_blue"/>
  <path d="M48 53 L50 54 L52 53 L52 82 L50 84 L48 82 Z" fill="$_navyDeep"/>
  <path d="M20 62 C28 57 37 57 43 60" stroke="#FFFFFF" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.85"/>
  <path d="M20 70 C28 65 37 65 43 68" stroke="#FFFFFF" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.85"/>
  <path d="M80 62 C72 57 63 57 57 60" stroke="#FFFFFF" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.85"/>
  <path d="M80 70 C72 65 63 65 57 68" stroke="#FFFFFF" stroke-width="2.4" fill="none" stroke-linecap="round" opacity="0.85"/>
  <polygon points="50,10 86,26 50,42 14,26" fill="$_navyDeep"/>
  <path d="M32 34 L32 46 C32 51 42 55 50 55 C58 55 68 51 68 46 L68 34 L50 42 Z" fill="$_navy"/>
  <line x1="86" y1="26" x2="86" y2="44" stroke="$_gold" stroke-width="3" stroke-linecap="round"/>
  <circle cx="86" cy="47" r="4" fill="$_gold"/>
  <polygon points="50,16 52.6,22.4 59.4,22.6 54.1,26.8 55.9,33.4 50,29.7 44.1,33.4 45.9,26.8 40.6,22.6 47.4,22.4" fill="$_gold"/>
</svg>''',
      width: size,
      height: size,
    );

/// Padlock + shield illustration inside a soft blob (MPIN screens).
Widget lockArt({double size = 210}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 206">
  <defs>
    <linearGradient id="lockGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1746B8"/>
      <stop offset="1" stop-color="$_navyDeep"/>
    </linearGradient>
    <linearGradient id="shieldGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3C7BFF"/>
      <stop offset="1" stop-color="#2258D8"/>
    </linearGradient>
  </defs>
  <path d="M52 26 C104 -8 176 0 210 38 C244 76 236 134 196 166 C156 198 84 204 44 172 C4 140 0 60 52 26 Z" fill="#E4EDFD"/>
  <circle cx="66" cy="52" r="7" fill="$_bluePale"/>
  <circle cx="196" cy="60" r="9" fill="$_bluePale"/>
  <circle cx="206" cy="150" r="6" fill="$_bluePale"/>
  <path d="M40 120 C22 108 18 84 26 66 C44 76 52 100 40 120 Z" fill="$_blueLight"/>
  <path d="M34 150 C18 140 12 118 18 100 C36 108 44 134 34 150 Z" fill="$_blue"/>
  <path d="M204 122 C222 110 226 86 218 68 C200 78 192 102 204 122 Z" fill="$_blueLight"/>
  <path d="M92 96 L92 74 C92 44 110 28 128 28 C146 28 164 44 164 74 L164 96" stroke="url(#lockGrad)" stroke-width="17" fill="none" stroke-linecap="round"/>
  <rect x="76" y="92" width="104" height="84" rx="20" fill="url(#lockGrad)"/>
  <rect x="94" y="116" width="68" height="30" rx="12" fill="#FFFFFF"/>
  <circle cx="108" cy="131" r="5" fill="$_navy"/>
  <circle cx="128" cy="131" r="5" fill="$_navy"/>
  <circle cx="148" cy="131" r="5" fill="$_navy"/>
  <path d="M186 96 L214 104 L214 130 C214 146 202 156 186 162 C170 156 158 146 158 130 L158 104 Z" fill="url(#shieldGrad)"/>
  <path d="M174 128 L183 137 L199 118" stroke="#FFFFFF" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''',
      width: size,
      height: size * 0.86,
    );

/// Decorative open-book outline (top-right of the splash screen).
Widget bookDoodle({double size = 120}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 96">
  <path d="M10 30 C26 18 46 18 58 26 L58 70 C46 62 26 62 10 74 Z" stroke="$_bluePale" stroke-width="5" fill="none" stroke-linejoin="round"/>
  <path d="M110 30 C94 18 74 18 62 26 L62 70 C74 62 94 62 110 74 Z" stroke="$_bluePale" stroke-width="5" fill="none" stroke-linejoin="round"/>
  <line x1="60" y1="26" x2="60" y2="72" stroke="$_bluePale" stroke-width="5" stroke-linecap="round"/>
  <path d="M108 8 C112 14 114 16 120 18" stroke="$_bluePale" stroke-width="4" fill="none" stroke-linecap="round"/>
  <path d="M96 2 L98 10" stroke="$_bluePale" stroke-width="4" fill="none" stroke-linecap="round"/>
</svg>''',
      width: size,
      height: size * 0.8,
    );

/// Stack of books (bottom-left of the splash screen).
Widget bookStack({double width = 250}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 250 155">
  <rect x="22" y="96" width="212" height="34" rx="7" fill="$_blue"/>
  <rect x="22" y="96" width="212" height="12" rx="6" fill="#FFFFFF"/>
  <rect x="22" y="122" width="212" height="8" rx="4" fill="$_navyDeep" opacity="0.35"/>
  <rect x="10" y="62" width="204" height="32" rx="7" fill="$_gold"/>
  <rect x="10" y="62" width="204" height="11" rx="5" fill="#FFFFFF"/>
  <rect x="10" y="87" width="204" height="7" rx="3.5" fill="#B57E06" opacity="0.5"/>
  <rect x="34" y="26" width="196" height="34" rx="7" fill="$_navyDeep"/>
  <rect x="34" y="26" width="196" height="12" rx="6" fill="#FFFFFF"/>
  <rect x="34" y="52" width="196" height="8" rx="4" fill="#061F52" opacity="0.5"/>
  <path d="M4 128 C0 116 6 104 18 100 C22 114 16 126 4 128 Z" fill="#2E8B45" opacity="0.9"/>
</svg>''',
      width: width,
      height: width * 0.62,
    );

/// Bottom wave for the splash screen (navy, with a lighter crest).
Widget bottomWave({double width = 400, double height = 190}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 190" preserveAspectRatio="none">
  <path d="M0 78 C90 34 168 92 250 70 C318 52 366 22 400 30 L400 190 L0 190 Z" fill="#4E86E8"/>
  <path d="M0 96 C96 52 170 110 256 88 C322 71 368 44 400 50 L400 190 L0 190 Z" fill="$_navy"/>
  <path d="M0 78 C90 34 168 92 250 70 C318 52 366 22 400 30" stroke="$_gold" stroke-width="3" fill="none" opacity="0.85"/>
</svg>''',
      width: width,
      height: height,
      fit: BoxFit.fill,
    );

/// Top-left corner curve for the splash screen (navy + gold arc).
Widget topCornerCurve({double width = 220, double height = 150}) =>
    SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 150">
  <path d="M0 0 L120 0 C70 30 30 74 0 142 Z" fill="$_navy"/>
  <path d="M120 0 C70 30 30 74 0 142" stroke="$_gold" stroke-width="4" fill="none"/>
  <path d="M0 128 C40 60 84 24 150 0 L128 0 C74 28 36 74 8 146 Z" fill="#1E58C8" opacity="0.55"/>
</svg>''',
      width: width,
      height: height,
    );

/// Small leaf accent used around the splash screen.
Widget leaf({double size = 60, String color = _blueLight}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 72">
  <path d="M30 4 C52 22 56 48 40 68 C18 60 8 34 30 4 Z" fill="$color" opacity="0.55"/>
  <path d="M34 14 C40 30 40 48 36 60" stroke="#FFFFFF" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.7"/>
</svg>''',
      width: size,
      height: size * 1.2,
    );

/// Clipboard-check tile used in the splash loading pill.
Widget clipboardCheckIcon({double size = 34}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40">
  <rect x="7" y="6" width="26" height="30" rx="6" fill="$_blue"/>
  <rect x="14" y="3" width="12" height="7" rx="3.5" fill="$_navyDeep"/>
  <circle cx="28.5" cy="29.5" r="8.5" fill="$_navyDeep" stroke="#FFFFFF" stroke-width="2.5"/>
  <path d="M24.8 29.6 L27.4 32.2 L32.4 26.8" stroke="#FFFFFF" stroke-width="2.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
  <line x1="13" y1="17" x2="22" y2="17" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round"/>
  <line x1="13" y1="23" x2="19" y2="23" stroke="#FFFFFF" stroke-width="2.6" stroke-linecap="round"/>
</svg>''',
      width: size,
      height: size,
    );

/// Underline swoosh under the splash tagline.
Widget swoosh({double width = 170}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 170 14">
  <path d="M6 9 C46 2 124 2 164 8" stroke="$_blueLight" stroke-width="5" fill="none" stroke-linecap="round"/>
</svg>''',
      width: width,
      height: 14,
    );

/// Graduation cap that sits on top of the "ClassTrack" wordmark.
Widget capIcon({double size = 44}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 46">
  <polygon points="32,3 61,15 32,27 3,15" fill="$_navyDeep"/>
  <path d="M14 20 L14 31 C14 36 22 40 32 40 C42 40 50 36 50 31 L50 20 L32 27 Z" fill="$_navy"/>
  <line x1="61" y1="15" x2="61" y2="30" stroke="$_gold" stroke-width="2.6" stroke-linecap="round"/>
  <circle cx="61" cy="32.5" r="3.2" fill="$_gold"/>
</svg>''',
      width: size,
      height: size * 0.72,
    );

/// Soft decorative circle behind the MPIN screen header art.
Widget softBlob({double size = 320}) => SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320">
  <circle cx="160" cy="160" r="150" fill="#EFF5FE"/>
</svg>''',
      width: size,
      height: size,
    );
