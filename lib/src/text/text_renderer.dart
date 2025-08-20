import '../errors.dart' show FontException;
import '../fonts/font.dart';
import '../fonts/font_error_messages.dart';
import '../fonts/font_fallback.dart';
import '../paths/path.dart';
import 'text_types.dart'
    show
        TextAlign,
        TextBaseline,
        TextMetrics,
        TextPosition,
        TextDirection,
        ScriptType;
import 'text_shaper.dart';

/// Unicode categories for text processing
enum UnicodeCategory {
  letter,
  mark,
  number,
  punctuation,
  symbol,
  separator,
  other,
}

/// Combines basic text rendering with advanced Unicode features
class TextRenderer {
  // Basic text rendering properties
  final Font? font;
  final double fontSize;
  final TextAlign textAlign;
  final TextBaseline textBaseline;

  // Unicode text rendering properties
  final FontFallbackChain? _fontChain;
  final TextShaper? _shaper;
  final Map<String, ShapedText> _shapedTextCache = {};

  /// Maximum cache size before clearing
  static const int maxCacheSize = 100;

  /// Create a text renderer with basic or Unicode support
  TextRenderer({
    this.font,
    required this.fontSize,
    this.textAlign = TextAlign.left,
    this.textBaseline = TextBaseline.alphabetic,
    FontFallbackChain? fontChain,
    TextShaper? shaper,
  }) : _fontChain = fontChain,
       _shaper = shaper ?? (fontChain != null ? BasicTextShaper() : null);

  /// Create a Unicode-aware text renderer
  factory TextRenderer.unicode({
    FontFallbackChain? fontChain,
    TextShaper? shaper,
    double fontSize = 12.0,
    TextAlign textAlign = TextAlign.left,
    TextBaseline textBaseline = TextBaseline.alphabetic,
  }) {
    return TextRenderer(
      font: null,
      fontSize: fontSize,
      textAlign: textAlign,
      textBaseline: textBaseline,
      fontChain: fontChain ?? FontFallbackChain(),
      shaper: shaper ?? BasicTextShaper(),
    );
  }

  /// Add a font to the renderer (Unicode mode)
  void addFont(Font font) {
    if (_fontChain != null) {
      _fontChain.addFont(font);
      _clearCache();
    }
  }

  /// Clear the shaped text cache
  void _clearCache() {
    _shapedTextCache.clear();
  }

  /// Get the primary font for rendering
  Font? get primaryFont {
    if (font != null) return font;
    return _fontChain?.primaryFont;
  }

  /// Get text path for rendering
  Path getTextPath(String text, double x, double y) {
    // Use Unicode rendering if font chain is available
    if (_fontChain != null && _shaper != null) {
      return renderUnicodeText(
        text,
        x,
        y,
        fontSize,
        direction: TextDirection.auto,
      );
    }

    // Use basic rendering
    final position = _calculatePosition(text, x, y);
    if (font == null) {
      throw FontException(FontErrorMessages.noFontSetGeneric);
    }
    return font!.getTextPath(text, position.x, position.y, fontSize);
  }

  /// Render text with Unicode support
  Path renderUnicodeText(
    String text,
    double x,
    double y,
    double fontSize, {
    TextDirection direction = TextDirection.auto,
    ScriptType? script,
    String? language,
    List<String>? features,
    bool useCache = true,
  }) {
    if (text.isEmpty || (_fontChain?.primaryFont == null && font == null)) {
      return PathBuilder().build();
    }

    // Normalize text (NFC normalization)
    final normalizedText = _normalizeText(text);

    // Check cache
    final cacheKey =
        '$normalizedText-$fontSize-$direction-$script-$language-${features?.join(',')}';
    ShapedText? shaped;

    if (useCache && _shapedTextCache.containsKey(cacheKey)) {
      shaped = _shapedTextCache[cacheKey];
    } else {
      // Process text for complex scripts
      final processedText = _processComplexText(
        normalizedText,
        script ?? ScriptType.auto,
      );

      // Shape text
      shaped = _shapeTextWithFallback(
        processedText,
        fontSize,
        direction: direction,
        script: script ?? ScriptType.auto,
        language: language,
        features: features,
      );

      // Add to cache
      if (useCache) {
        if (_shapedTextCache.length >= maxCacheSize) {
          _clearCache();
        }
        _shapedTextCache[cacheKey] = shaped;
      }
    }

    // Apply text alignment and baseline
    final position = _calculatePosition(text, x, y);

    // Convert shaped text to path
    return _shapedToPath(shaped!, position.x, position.y, fontSize);
  }

  /// Calculate adjusted position based on alignment and baseline
  TextPosition _calculatePosition(String text, double x, double y) {
    final metrics = measureText(text);

    // Adjust x position based on alignment
    double adjustedX = x;
    switch (textAlign) {
      case TextAlign.center:
        adjustedX = x - metrics.width / 2;
        break;
      case TextAlign.right:
        adjustedX = x - metrics.width;
        break;
      case TextAlign.left:
      case TextAlign.justify:
        adjustedX = x;
        break;
    }

    // Adjust y position based on baseline
    double adjustedY = y;
    switch (textBaseline) {
      case TextBaseline.top:
        adjustedY = y + metrics.ascent;
        break;
      case TextBaseline.middle:
        adjustedY = y + (metrics.ascent - metrics.descent) / 2;
        break;
      case TextBaseline.bottom:
        adjustedY = y - metrics.descent;
        break;
      case TextBaseline.alphabetic:
        adjustedY = y;
        break;
      case TextBaseline.ideographic:
        // Ideographic baseline is typically 12% below alphabetic
        adjustedY = y + metrics.ascent * 0.12;
        break;
      case TextBaseline.hanging:
        // Hanging baseline is typically 80% of ascent
        adjustedY = y + metrics.ascent * 0.8;
        break;
    }

    return TextPosition(adjustedX, adjustedY);
  }

  /// Measure text without rendering
  TextMetrics measureText(String text) {
    // Use Unicode measurement if available
    if (_fontChain != null && _shaper != null) {
      return measureUnicodeText(text, fontSize, direction: TextDirection.auto);
    }

    // Use basic measurement
    if (font == null) {
      throw FontException(FontErrorMessages.noFontSetGeneric);
    }
    return font!.measureText(text, fontSize);
  }

  /// Measure text with full Unicode support
  TextMetrics measureUnicodeText(
    String text,
    double fontSize, {
    TextDirection direction = TextDirection.auto,
    ScriptType? script,
    String? language,
    List<String>? features,
  }) {
    if (text.isEmpty || (_fontChain?.primaryFont == null && font == null)) {
      return TextMetrics(
        width: 0,
        height: 0,
        ascent: 0,
        descent: 0,
        lineHeight: fontSize * 1.2,
      );
    }

    final normalizedText = _normalizeText(text);
    final processedText = _processComplexText(
      normalizedText,
      script ?? ScriptType.auto,
    );

    final shaped = _shapeTextWithFallback(
      processedText,
      fontSize,
      direction: direction,
      script: script ?? ScriptType.auto,
      language: language,
      features: features,
    );

    // Calculate metrics from shaped text
    double maxAscent = 0;
    double maxDescent = 0;

    for (final glyph in shaped.glyphs) {
      // Get font for this glyph
      final glyphFont = glyph.font ?? _fontChain?.primaryFont ?? font;
      if (glyphFont == null) continue;

      final metrics = glyphFont.metrics;
      final scale = fontSize / glyphFont.unitsPerEm;

      final ascent = metrics.ascender * scale;
      final descent = metrics.descender * scale;

      maxAscent = maxAscent > ascent ? maxAscent : ascent;
      maxDescent = maxDescent < descent ? maxDescent : descent;
    }

    return TextMetrics(
      width: shaped.totalAdvance,
      height: maxAscent - maxDescent,
      ascent: maxAscent,
      descent: maxDescent,
      lineHeight: (maxAscent - maxDescent) * 1.2,
    );
  }

  /// Get text path with letter spacing
  Path getTextPathWithSpacing(
    String text,
    double x,
    double y,
    double letterSpacing,
  ) {
    final pathBuilder = PathBuilder();
    final position = _calculatePosition(text, x, y);
    double currentX = position.x;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charPath = getTextPath(char, currentX, position.y);

      // Merge character path into result
      pathBuilder.addPath(charPath);

      // Advance position
      final charMetrics = measureText(char);
      currentX += charMetrics.width + letterSpacing;
    }

    return pathBuilder.build();
  }

  /// Get wrapped text paths for multi-line text
  List<TextPath> getWrappedTextPaths(
    String text,
    double x,
    double y,
    double maxWidth,
    double lineHeight,
  ) {
    final paths = <TextPath>[];
    final words = text.split(' ');
    final lines = <String>[];

    // Build lines with word wrapping
    String currentLine = '';
    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      final metrics = measureText(testLine);

      if (metrics.width > maxWidth && currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = word;
      } else {
        currentLine = testLine;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    // Create path for each line
    double currentY = y;
    for (final line in lines) {
      final position = _calculatePosition(line, x, currentY);
      paths.add(
        TextPath(
          text: line,
          path: getTextPath(line, position.x, position.y),
          position: position,
        ),
      );
      currentY += lineHeight;
    }

    return paths;
  }

  /// Shape text with font fallback support
  ShapedText _shapeTextWithFallback(
    String text,
    double fontSize, {
    required TextDirection direction,
    required ScriptType script,
    String? language,
    List<String>? features,
  }) {
    if (_fontChain == null || _shaper == null) {
      // Fallback to simple shaping
      final simpleFont = font;
      if (simpleFont == null) {
        throw FontException(FontErrorMessages.noFontAvailable);
      }
      return _shaper?.shapeText(
            text,
            simpleFont,
            fontSize,
            direction: direction,
            script: script,
            language: language,
            features: features,
          ) ??
          ShapedText(glyphs: [], totalAdvance: 0, direction: direction);
    }

    // Split text into runs based on font availability
    final runs = _fontChain.splitIntoFontRuns(text);
    final allGlyphs = <ShapedGlyph>[];
    double totalAdvance = 0;
    int clusterOffset = 0;

    for (final run in runs) {
      if (run.font != null) {
        // Shape this run
        final shaped = _shaper.shapeText(
          run.text,
          run.font!,
          fontSize,
          direction: direction,
          script: script,
          language: language,
          features: features,
        );

        // Adjust cluster indices and add glyphs
        for (final glyph in shaped.glyphs) {
          allGlyphs.add(
            ShapedGlyph(
              glyphId: glyph.glyphId,
              cluster: glyph.cluster + clusterOffset,
              xAdvance: glyph.xAdvance,
              yAdvance: glyph.yAdvance,
              xOffset: glyph.xOffset,
              yOffset: glyph.yOffset,
              font: run.font,
            ),
          );
        }

        totalAdvance += shaped.totalAdvance;
      } else {
        // Handle missing glyphs with tofu (□)
        final tofuWidth = fontSize * 0.6;
        for (int i = 0; i < run.text.length; i++) {
          allGlyphs.add(
            ShapedGlyph(
              glyphId: 0, // Missing glyph
              cluster: clusterOffset + i,
              xAdvance: tofuWidth,
              yAdvance: 0,
              font: null,
            ),
          );
          totalAdvance += tofuWidth;
        }
      }

      clusterOffset = clusterOffset + run.text.length;
    }

    return ShapedText(
      glyphs: allGlyphs,
      totalAdvance: totalAdvance,
      direction: direction,
    );
  }

  /// Convert shaped text to path
  Path _shapedToPath(ShapedText shaped, double x, double y, double fontSize) {
    final builder = PathBuilder();
    double currentX = x;
    double currentY = y;

    for (final glyph in shaped.glyphs) {
      if (glyph.glyphId == 0) {
        // Draw tofu (□) for missing glyphs
        final tofuSize = fontSize * 0.6;

        builder.moveTo(currentX, currentY - fontSize * 0.8);
        builder.lineTo(currentX + tofuSize, currentY - fontSize * 0.8);
        builder.lineTo(currentX + tofuSize, currentY);
        builder.lineTo(currentX, currentY);
        builder.close();
      } else {
        // Get glyph path from appropriate font
        final glyphFont = glyph.font ?? _fontChain?.primaryFont ?? font;
        if (glyphFont == null) continue;

        final glyphPath = glyphFont.getGlyphPath(glyph.glyphId, fontSize);

        // Apply position and offset
        final glyphX = currentX + glyph.xOffset;
        final glyphY = currentY + glyph.yOffset;

        // Merge glyph path
        for (final command in glyphPath.commands) {
          if (command.type == PathCommandType.moveTo &&
              command.points.isNotEmpty) {
            builder.moveTo(
              command.points[0].x + glyphX,
              command.points[0].y + glyphY,
            );
          } else if (command.type == PathCommandType.lineTo &&
              command.points.isNotEmpty) {
            builder.lineTo(
              command.points[0].x + glyphX,
              command.points[0].y + glyphY,
            );
          } else if (command.type == PathCommandType.cubicCurveTo &&
              command.points.length >= 3) {
            builder.cubicCurveTo(
              command.points[0].x + glyphX,
              command.points[0].y + glyphY,
              command.points[1].x + glyphX,
              command.points[1].y + glyphY,
              command.points[2].x + glyphX,
              command.points[2].y + glyphY,
            );
          } else if (command.type == PathCommandType.close) {
            builder.close();
          }
        }
      }

      // Advance position
      currentX += glyph.xAdvance;
      currentY += glyph.yAdvance;
    }

    return builder.build();
  }

  /// Normalize text using Unicode normalization (simplified NFC)
  String _normalizeText(String text) {
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // Handle common combining characters
      if (i > 0 && _isCombiningMark(char.codeUnitAt(0))) {
        // Keep combining marks with their base character
        buffer.write(char);
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Process text for complex scripts (Arabic, Devanagari, etc.)
  String _processComplexText(String text, ScriptType script) {
    switch (script) {
      case ScriptType.arabic:
        return _processArabicText(text);
      case ScriptType.devanagari:
        return _processDevanagariText(text);
      default:
        return text;
    }
  }

  /// Process Arabic text for contextual forms
  String _processArabicText(String text) {
    // Arabic requires contextual shaping
    // This is a simplified version; full support would use HarfBuzz
    // For now, return as-is
    return text;
  }

  /// Process Devanagari text for complex conjuncts
  String _processDevanagariText(String text) {
    // Devanagari has complex reordering rules
    // This is a simplified version
    // For now, return as-is
    return text;
  }

  /// Check if a code point is a combining mark
  bool _isCombiningMark(int codePoint) {
    return (codePoint >= 0x0300 &&
            codePoint <= 0x036F) || // Combining Diacritical Marks
        (codePoint >= 0x1AB0 &&
            codePoint <= 0x1AFF) || // Combining Diacritical Marks Extended
        (codePoint >= 0x1DC0 &&
            codePoint <= 0x1DFF) || // Combining Diacritical Marks Supplement
        (codePoint >= 0x20D0 &&
            codePoint <= 0x20FF) || // Combining Diacritical Marks for Symbols
        (codePoint >= 0xFE20 && codePoint <= 0xFE2F); // Combining Half Marks
  }

  /// Get Unicode category for a code point
  static UnicodeCategory getCategory(int codePoint) {
    if (_isLetter(codePoint)) return UnicodeCategory.letter;
    if (_isMark(codePoint)) return UnicodeCategory.mark;
    if (_isNumber(codePoint)) return UnicodeCategory.number;
    if (_isPunctuation(codePoint)) return UnicodeCategory.punctuation;
    if (_isSymbol(codePoint)) return UnicodeCategory.symbol;
    if (_isSeparator(codePoint)) return UnicodeCategory.separator;
    return UnicodeCategory.other;
  }

  static bool _isLetter(int cp) {
    return (cp >= 0x0041 && cp <= 0x005A) || // Latin uppercase
        (cp >= 0x0061 && cp <= 0x007A) || // Latin lowercase
        (cp >= 0x00C0 && cp <= 0x00FF) || // Latin extended
        (cp >= 0x0100 && cp <= 0x017F) || // Latin extended A
        (cp >= 0x0400 && cp <= 0x04FF) || // Cyrillic
        (cp >= 0x0530 && cp <= 0x058F) || // Armenian
        (cp >= 0x0590 && cp <= 0x05FF) || // Hebrew
        (cp >= 0x0600 && cp <= 0x06FF) || // Arabic
        (cp >= 0x4E00 && cp <= 0x9FFF); // CJK
  }

  static bool _isMark(int cp) {
    return (cp >= 0x0300 && cp <= 0x036F) || // Combining marks
        (cp >= 0x1AB0 && cp <= 0x1AFF) ||
        (cp >= 0x1DC0 && cp <= 0x1DFF);
  }

  static bool _isNumber(int cp) {
    return (cp >= 0x0030 && cp <= 0x0039) || // ASCII digits
        (cp >= 0x0660 && cp <= 0x0669) || // Arabic-Indic digits
        (cp >= 0x06F0 && cp <= 0x06F9) || // Extended Arabic-Indic
        (cp >= 0x0966 && cp <= 0x096F); // Devanagari digits
  }

  static bool _isPunctuation(int cp) {
    return (cp >= 0x0021 && cp <= 0x0023) ||
        (cp >= 0x0025 && cp <= 0x002A) ||
        (cp >= 0x002C && cp <= 0x002F) ||
        (cp >= 0x003A && cp <= 0x003B) ||
        (cp >= 0x003F && cp <= 0x0040) ||
        (cp >= 0x005B && cp <= 0x005D) ||
        (cp >= 0x007B && cp <= 0x007D);
  }

  static bool _isSymbol(int cp) {
    return (cp >= 0x0024 && cp <= 0x0024) || // Dollar
        (cp >= 0x002B && cp <= 0x002B) || // Plus
        (cp >= 0x003C && cp <= 0x003E) || // Less/Greater
        (cp >= 0x005E && cp <= 0x005E) || // Caret
        (cp >= 0x007C && cp <= 0x007C) || // Pipe
        (cp >= 0x007E && cp <= 0x007E); // Tilde
  }

  static bool _isSeparator(int cp) {
    return cp == 0x0020 || // Space
        cp == 0x00A0 || // Non-breaking space
        cp == 0x2002 || // En space
        cp == 0x2003 || // Em space
        cp == 0x2009 || // Thin space
        cp == 0x200A || // Hair space
        cp == 0x202F || // Narrow no-break space
        cp == 0x205F || // Medium mathematical space
        cp == 0x3000; // Ideographic space
  }
}

/// Represents a text path with metadata
class TextPath {
  final String text;
  final Path path;
  final TextPosition position;

  TextPath({required this.text, required this.path, required this.position});
}
