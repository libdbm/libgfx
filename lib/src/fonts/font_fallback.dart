import '../paths/path.dart';
import '../text/text_utils.dart';
import '../text/text_types.dart' show TextMetrics;
import 'font.dart';
import 'ttf/ttf_font.dart';
import '../io/file_system.dart';
import '../limits.dart';
import '../result.dart';
import '../../io/font_fallback_loader_stub.dart'
    if (dart.library.io) '../../io/font_fallback_loader_io.dart';

/// Font fallback chain for handling missing glyphs
class FontFallbackChain {
  final List<Font> _fonts = [];
  final Map<int, Font?> _cache = {};

  /// Primary font (always used first)
  Font? get primary => _fonts.isNotEmpty ? _fonts.first : null;

  /// Add a font to the fallback chain
  void add(Font font) {
    _fonts.add(font);
    _cache.clear(); // Clear cache when fonts change
  }

  /// Add a font from file; the font is added only when loading succeeds
  Future<Result<TTFFont, ErrorDetails>> load(
    String path, {
    required GraphicsFileSystem filesystem,
    Limits limits = const Limits(),
  }) async {
    final result = await TTFFont.load(
      path,
      filesystem: filesystem,
      limits: limits,
    );
    if (result case Ok(:final value)) {
      add(value);
    }
    return result;
  }

  /// Remove a font from the chain
  void remove(Font font) {
    _fonts.remove(font);
    _cache.clear();
  }

  /// Clear all fonts
  void clear() {
    _fonts.clear();
    _cache.clear();
  }

  /// Get the font that can render a specific character
  Font? lookup(int codePoint) {
    // Check cache first
    if (_cache.containsKey(codePoint)) {
      return _cache[codePoint];
    }

    // Search through fonts
    for (final font in _fonts) {
      if (font.covers(codePoint)) {
        _cache[codePoint] = font;
        return font;
      }
    }

    // No font found
    _cache[codePoint] = null;
    return null;
  }

  /// Get the font that can render a string (checks first character)
  Font? find(String text) {
    if (text.isEmpty) return primary;
    return lookup(text.runes.first);
  }

  /// Check if any font in the chain has a glyph for the character
  bool covers(int codePoint) {
    return lookup(codePoint) != null;
  }

  /// Measure text using appropriate fonts
  TextMetrics measure(String text, final double size) {
    if (_fonts.isEmpty) {
      return TextMetrics(
        width: 0,
        height: 0,
        ascent: 0,
        descent: 0,
        lineHeight: size * 1.2,
      );
    }

    double width = 0;
    double height = 0;
    double ascent = 0;
    double descent = 0;

    // Process text in runs of characters that use the same font
    for (final run in runs(text)) {
      if (run.font != null) {
        final metrics = run.font!.measure(run.text, size);
        width += metrics.width;
        height = height > metrics.height ? height : metrics.height;
        ascent = ascent > metrics.ascent ? ascent : metrics.ascent;
        descent = descent > metrics.descent ? descent : metrics.descent;
      } else {
        // Estimate size for missing glyphs
        width += size * 0.5 * run.text.length; // Half em-width per missing char
        height = height > size ? height : size;
      }
    }

    return TextMetrics(
      width: width,
      height: height,
      ascent: ascent,
      descent: descent,
      lineHeight: height * 1.2,
    );
  }

  /// Get text path using appropriate fonts
  Path path(String text, double x, double y, final double size) {
    final builder = PathBuilder();

    if (_fonts.isEmpty) {
      return builder.build();
    }

    double cursor = x;
    for (final run in runs(text)) {
      if (run.font != null) {
        final outline = run.font!.path(run.text, cursor, y, size);
        // Merge the path
        for (final command in outline.commands) {
          if (command.type == PathCommandType.moveTo &&
              command.points.isNotEmpty) {
            builder.moveTo(command.points[0].x, command.points[0].y);
          } else if (command.type == PathCommandType.lineTo &&
              command.points.isNotEmpty) {
            builder.lineTo(command.points[0].x, command.points[0].y);
          } else if (command.type == PathCommandType.cubicCurveTo &&
              command.points.length >= 3) {
            builder.bezierCurveTo(
              command.points[0].x,
              command.points[0].y,
              command.points[1].x,
              command.points[1].y,
              command.points[2].x,
              command.points[2].y,
            );
          } else if (command.type == PathCommandType.close) {
            builder.closePath();
          }
        }

        // Update x position
        final metrics = run.font!.measure(run.text, size);
        cursor += metrics.width;
      } else {
        // Skip missing glyphs, advance by estimated width
        cursor += size * 0.5 * run.text.length;
      }
    }

    return builder.build();
  }

  /// Split text into runs where each run uses the same font
  List<FontRun> runs(String text) {
    final runs = <FontRun>[];

    if (text.isEmpty || _fonts.isEmpty) {
      return runs;
    }

    final StringBuffer buffer = StringBuffer();
    Font? font;
    Font? previous;

    for (final point in TextUtils.iterateCodePoints(text)) {
      font = lookup(point.codePoint);

      if (previous != null && font != previous) {
        // Font changed, save current run
        if (buffer.isNotEmpty) {
          runs.add(FontRun(buffer.toString(), previous));
          buffer.clear();
        }
      }

      // Add character to current run
      buffer.write(point.character);
      previous = font;
    }

    // Add final run
    if (buffer.isNotEmpty) {
      runs.add(FontRun(buffer.toString(), previous));
    }

    return runs;
  }
}

/// A run of text that uses the same font
class FontRun {
  final String text;
  final Font? font;

  FontRun(this.text, this.font);
}

/// System font manager for loading common system fonts
class SystemFontManager {
  /// Load system fonts into a fallback chain (IO-only helper).
  static Future<FontFallbackChain> load({
    List<String>? preferredFonts,
    int maxFonts = 5,
    GraphicsFileSystem? filesystem,
  }) {
    return loadSystemFontsImpl(
      preferredFonts: preferredFonts,
      maxFonts: maxFonts,
      filesystem: filesystem,
    );
  }
}
