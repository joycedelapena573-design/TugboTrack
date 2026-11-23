/// Bundled Unicode fonts for the PDF reports.
///
/// The built-in Helvetica font in the `pdf` package cannot draw characters
/// such as ñ, é or the em dash, which appear in Filipino learner names. The
/// Poppins faces shipped with the app cover those glyphs, so every report uses
/// them when they can be loaded and falls back to the built-in fonts otherwise
/// (for example when assets are unavailable in a unit test).
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static bool _tried = false;

  /// Loads the bundled fonts once. Safe to call repeatedly.
  static Future<void> ensureLoaded() async {
    if (_tried) return;
    _tried = true;
    try {
      _regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
      );
      _bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'),
      );
    } catch (_) {
      // Assets unavailable (plain Dart test) — keep the built-in fonts.
      _regular = null;
      _bold = null;
    }
  }

  /// Theme for a `pw.MultiPage`: bundled Poppins when loaded, otherwise the
  /// package default.
  static Future<pw.ThemeData> theme() async {
    await ensureLoaded();
    final base = _regular;
    if (base == null) return pw.ThemeData.base();
    final bold = _bold ?? base;
    return pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: base,
      boldItalic: bold,
    );
  }
}
