import 'dart:io';

import '../errors.dart';
import '../logging.dart';
import '../paths/path.dart';
import '../text/text_utils.dart';
import 'font_error_messages.dart';
import '../text/text_types.dart' show TextMetrics;
import 'font.dart';
import 'ttf/ttf_font.dart';

/// Font fallback chain for handling missing glyphs
class FontFallbackChain {
  final List<Font> _fonts = [];
  final Map<int, Font?> _glyphCache = {};

  /// Primary font (always used first)
  Font? get primaryFont => _fonts.isNotEmpty ? _fonts.first : null;

  /// Add a font to the fallback chain
  void addFont(Font font) {
    _fonts.add(font);
    _glyphCache.clear(); // Clear cache when fonts change
  }

  /// Add a font from file
  Future<void> addFontFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FontException('${FontErrorMessages.fontFileNotFound}$path');
    }

    final bytes = await file.readAsBytes();
    final font = TTFFont.fromBytes(bytes);
    addFont(font);
  }

  /// Remove a font from the chain
  void removeFont(Font font) {
    _fonts.remove(font);
    _glyphCache.clear();
  }

  /// Clear all fonts
  void clear() {
    _fonts.clear();
    _glyphCache.clear();
  }

  /// Get the font that can render a specific character
  Font? getFontForCharacter(int codePoint) {
    // Check cache first
    if (_glyphCache.containsKey(codePoint)) {
      return _glyphCache[codePoint];
    }

    // Search through fonts
    for (final font in _fonts) {
      if (font.hasGlyph(codePoint)) {
        _glyphCache[codePoint] = font;
        return font;
      }
    }

    // No font found
    _glyphCache[codePoint] = null;
    return null;
  }

  /// Get the font that can render a string (checks first character)
  Font? getFontForString(String text) {
    if (text.isEmpty) return primaryFont;
    return getFontForCharacter(text.codeUnitAt(0));
  }

  /// Check if any font in the chain has a glyph for the character
  bool hasGlyph(int codePoint) {
    return getFontForCharacter(codePoint) != null;
  }

  /// Measure text using appropriate fonts
  TextMetrics measureText(String text, double fontSize) {
    if (_fonts.isEmpty) {
      return TextMetrics(
        width: 0,
        height: 0,
        ascent: 0,
        descent: 0,
        lineHeight: fontSize * 1.2,
      );
    }

    double totalWidth = 0;
    double maxHeight = 0;
    double maxAscent = 0;
    double maxDescent = 0;

    // Process text in runs of characters that use the same font
    final runs = splitIntoFontRuns(text);

    for (final run in runs) {
      if (run.font != null) {
        final metrics = run.font!.measureText(run.text, fontSize);
        totalWidth += metrics.width;
        maxHeight = maxHeight > metrics.height ? maxHeight : metrics.height;
        maxAscent = maxAscent > metrics.ascent ? maxAscent : metrics.ascent;
        maxDescent = maxDescent > metrics.descent
            ? maxDescent
            : metrics.descent;
      } else {
        // Estimate size for missing glyphs
        totalWidth +=
            fontSize * 0.5 * run.text.length; // Half em-width per missing char
        maxHeight = maxHeight > fontSize ? maxHeight : fontSize;
      }
    }

    return TextMetrics(
      width: totalWidth,
      height: maxHeight,
      ascent: maxAscent,
      descent: maxDescent,
      lineHeight: maxHeight * 1.2,
    );
  }

  /// Get text path using appropriate fonts
  Path getTextPath(String text, double x, double y, double fontSize) {
    final builder = PathBuilder();

    if (_fonts.isEmpty) {
      return builder.build();
    }

    double currentX = x;
    final runs = splitIntoFontRuns(text);

    for (final run in runs) {
      if (run.font != null) {
        final runPath = run.font!.getTextPath(run.text, currentX, y, fontSize);
        // Merge the path
        for (final command in runPath.commands) {
          if (command.type == PathCommandType.moveTo &&
              command.points.isNotEmpty) {
            builder.moveTo(command.points[0].x, command.points[0].y);
          } else if (command.type == PathCommandType.lineTo &&
              command.points.isNotEmpty) {
            builder.lineTo(command.points[0].x, command.points[0].y);
          } else if (command.type == PathCommandType.cubicCurveTo &&
              command.points.length >= 3) {
            builder.cubicCurveTo(
              command.points[0].x,
              command.points[0].y,
              command.points[1].x,
              command.points[1].y,
              command.points[2].x,
              command.points[2].y,
            );
          } else if (command.type == PathCommandType.close) {
            builder.close();
          }
        }

        // Update x position
        final metrics = run.font!.measureText(run.text, fontSize);
        currentX += metrics.width;
      } else {
        // Skip missing glyphs, advance by estimated width
        currentX += fontSize * 0.5 * run.text.length;
      }
    }

    return builder.build();
  }

  /// Split text into runs where each run uses the same font
  List<FontRun> splitIntoFontRuns(String text) {
    final runs = <FontRun>[];

    if (text.isEmpty || _fonts.isEmpty) {
      return runs;
    }

    final StringBuffer currentRun = StringBuffer();
    Font? currentFont;
    Font? lastFont;

    for (final textPoint in TextUtils.iterateCodePoints(text)) {
      currentFont = getFontForCharacter(textPoint.codePoint);

      if (lastFont != null && currentFont != lastFont) {
        // Font changed, save current run
        if (currentRun.isNotEmpty) {
          runs.add(FontRun(currentRun.toString(), lastFont));
          currentRun.clear();
        }
      }

      // Add character to current run
      currentRun.write(textPoint.character);
      lastFont = currentFont;
    }

    // Add final run
    if (currentRun.isNotEmpty) {
      runs.add(FontRun(currentRun.toString(), lastFont));
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
  static final Map<String, List<String>> _systemFontPaths = {
    'darwin': [
      // macOS
      '/System/Library/Fonts/',
      '/Library/Fonts/',
      '~/Library/Fonts/',
    ],
    'linux': [
      '/usr/share/fonts/',
      '/usr/local/share/fonts/',
      '~/.fonts/',
      '~/.local/share/fonts/',
    ],
    'windows': ['C:\\Windows\\Fonts\\'],
  };

  /// Common font names to look for
  static final List<String> _commonFonts = [
    'Arial',
    'Helvetica',
    'Times',
    'Courier',
    'Verdana',
    'Georgia',
    'NotoSans',
    'NotoSerif',
    'DejaVu',
    'Liberation',
    'Roboto',
  ];

  /// Load system fonts into a fallback chain
  static Future<FontFallbackChain> loadSystemFonts({
    List<String>? preferredFonts,
    int maxFonts = 5,
  }) async {
    final chain = FontFallbackChain();
    final platform = Platform.operatingSystem;
    final searchPaths = _systemFontPaths[platform] ?? [];

    final fontsToLoad = preferredFonts ?? _commonFonts;
    int loaded = 0;

    for (final fontName in fontsToLoad) {
      if (loaded >= maxFonts) break;

      for (final basePath in searchPaths) {
        final expandedPath = basePath.replaceFirst(
          '~',
          Platform.environment['HOME'] ?? '',
        );

        // Try common extensions
        for (final ext in ['.ttf', '.otf', '.TTF', '.OTF']) {
          final fontPath = '$expandedPath$fontName$ext';
          final file = File(fontPath);

          if (await file.exists()) {
            try {
              await chain.addFontFromFile(fontPath);
              loaded++;
              logger.info('Loaded system font: $fontPath');
              break;
            } catch (e) {
              // Continue searching
            }
          }
        }

        if (loaded >= maxFonts) break;
      }
    }

    if (loaded == 0) {
      logger.warning('No system fonts could be loaded');
    }

    return chain;
  }
}
