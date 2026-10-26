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
import 'bidi.dart';
import 'text_engine.dart';
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
  final FontFallbackChain? _chain;
  final TextShaper? _shaper;
  final Map<String, ShapedText> _cache = {};

  /// Maximum cache size before clearing
  static const int maxCacheSize = 100;

  /// Create a text renderer with basic or Unicode support
  TextRenderer({
    this.font,
    required this.fontSize,
    this.textAlign = TextAlign.start,
    this.textBaseline = TextBaseline.alphabetic,
    FontFallbackChain? fontChain,
    TextShaper? shaper,
  }) : _chain = fontChain,
       _shaper = shaper ?? (fontChain != null ? BasicTextShaper() : null);

  /// Create a Unicode-aware text renderer
  factory TextRenderer.unicode({
    FontFallbackChain? fontChain,
    TextShaper? shaper,
    double fontSize = 12.0,
    TextAlign textAlign = TextAlign.start,
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
  void add(Font font) {
    if (_chain != null) {
      _chain.add(font);
      _clear();
    }
  }

  /// Clear the shaped text cache
  void _clear() {
    _cache.clear();
  }

  /// Get the primary font for rendering
  Font? get primary {
    if (font != null) return font;
    return _chain?.primary;
  }

  /// Get text path for rendering
  Path path(String text, double x, double y) {
    final position = _position(text, x, y, fontSize);
    return _place(text, position.x, position.y);
  }

  /// The outline of [text] at [fontSize] with its alphabetic baseline
  /// starting at (x, y), before alignment
  Path _place(String text, double x, double y) {
    // Use Unicode rendering if font chain is available
    if (_chain != null && _shaper != null) {
      if (text.isEmpty || _chain.primary == null) {
        return PathBuilder().build();
      }
      return _build(
        _shaped(text, fontSize, direction: TextDirection.auto),
        x,
        y,
        fontSize,
      );
    }

    // Use basic rendering
    if (font == null) {
      throw FontException(FontErrorMessages.noFontSetGeneric);
    }
    return font!.path(text, x, y, fontSize);
  }

  /// Render text with Unicode support
  Path layout(
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
    if (text.isEmpty || (_chain?.primary == null && font == null)) {
      return PathBuilder().build();
    }

    final shaped = _shaped(
      text,
      fontSize,
      direction: direction,
      script: script,
      language: language,
      features: features,
      useCache: useCache,
    );

    // Apply text alignment and baseline
    final position = _position(text, x, y, fontSize, direction);

    // Convert shaped text to path
    return _build(shaped, position.x, position.y, fontSize);
  }

  /// [text] shaped at [fontSize], from the cache when [useCache]
  ShapedText _shaped(
    String text,
    double fontSize, {
    required TextDirection direction,
    ScriptType? script,
    String? language,
    List<String>? features,
    bool useCache = true,
  }) {
    final key =
        '$text-$fontSize-$direction-$script-$language-${features?.join(',')}';
    final cached = useCache ? _cache[key] : null;
    if (cached != null) return cached;

    final shaped = _shape(
      text,
      fontSize,
      direction: direction,
      script: script ?? ScriptType.auto,
      language: language,
      features: features,
    );

    if (useCache) {
      if (_cache.length >= maxCacheSize) {
        _clear();
      }
      _cache[key] = shaped;
    }
    return shaped;
  }

  /// Calculate adjusted position based on alignment and baseline, measuring
  /// [text] at [size]; [TextAlign.start] and [TextAlign.end] follow the
  /// paragraph direction of [text] under [direction]
  TextPosition _position(
    String text,
    double x,
    double y,
    double size, [
    TextDirection direction = TextDirection.auto,
  ]) {
    final metrics = _measure(text, size);
    final rtl = Bidi.paragraph(text, direction).isOdd;

    // Adjust x position based on alignment
    double left = x;
    switch (textAlign) {
      case TextAlign.center:
        left = x - metrics.width / 2;
        break;
      case TextAlign.right:
        left = x - metrics.width;
        break;
      case TextAlign.start:
        left = rtl ? x - metrics.width : x;
        break;
      case TextAlign.end:
        left = rtl ? x : x - metrics.width;
        break;
      case TextAlign.left:
      case TextAlign.justify:
        left = x;
        break;
    }

    // Adjust y position based on baseline; graphics space is Y-up, so text
    // hangs below a top baseline and stands above a bottom one. Descent is
    // positive in basic mode and negative in Unicode mode, so use its size
    final descent = metrics.descent.abs();
    double base = y;
    switch (textBaseline) {
      case TextBaseline.top:
        base = y - metrics.ascent;
        break;
      case TextBaseline.middle:
        base = y - (metrics.ascent - descent) / 2;
        break;
      case TextBaseline.bottom:
        base = y + descent;
        break;
      case TextBaseline.alphabetic:
        base = y;
        break;
      case TextBaseline.ideographic:
        // The ideographic baseline lies about 12% of the ascent below the
        // alphabetic one, so the alphabetic baseline is above y
        base = y + metrics.ascent * 0.12;
        break;
      case TextBaseline.hanging:
        // The hanging baseline lies about 80% of the ascent above the
        // alphabetic one, so the alphabetic baseline is below y
        base = y - metrics.ascent * 0.8;
        break;
    }

    return TextPosition(left, base);
  }

  /// Measure text without rendering
  TextMetrics measure(String text) => _measure(text, fontSize);

  TextMetrics _measure(String text, double size) {
    // Use Unicode measurement if available
    if (_chain != null && _shaper != null) {
      return extent(text, size, direction: TextDirection.auto);
    }

    // Use basic measurement
    if (font == null) {
      throw FontException(FontErrorMessages.noFontSetGeneric);
    }
    return font!.measure(text, size);
  }

  /// Measure text with full Unicode support
  TextMetrics extent(
    String text,
    double fontSize, {
    TextDirection direction = TextDirection.auto,
    ScriptType? script,
    String? language,
    List<String>? features,
  }) {
    if (text.isEmpty || (_chain?.primary == null && font == null)) {
      return TextMetrics(
        width: 0,
        height: 0,
        ascent: 0,
        descent: 0,
        lineHeight: fontSize * 1.2,
      );
    }

    final shaped = _shape(
      text,
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
      final typeface = glyph.font ?? _chain?.primary ?? font;
      if (typeface == null) continue;

      final metrics = typeface.metrics;
      final scale = fontSize / typeface.unitsPerEm;

      final ascent = metrics.ascender * scale;
      final descent = metrics.descender * scale;

      maxAscent = maxAscent > ascent ? maxAscent : ascent;
      maxDescent = maxDescent < descent ? maxDescent : descent;
    }

    return TextMetrics(
      width: shaped.advance,
      height: maxAscent - maxDescent,
      ascent: maxAscent,
      descent: maxDescent,
      lineHeight: (maxAscent - maxDescent) * 1.2,
    );
  }

  /// Get text path with letter spacing
  Path spaced(String text, double x, double y, double letterSpacing) {
    final builder = PathBuilder();
    final position = _position(text, x, y, fontSize);
    double cursor = position.x;

    for (int i = 0; i < text.length; i++) {
      final character = text[i];
      final outline = _place(character, cursor, position.y);

      // Merge character path into result
      builder.addPath(outline);

      // Advance position
      final metrics = measure(character);
      cursor += metrics.width + letterSpacing;
    }

    return builder.build();
  }

  /// Get wrapped text paths for multi-line text, the first line at y and
  /// each following line [lineHeight] below the one before
  List<TextPath> wrap(
    String text,
    double x,
    double y,
    double maxWidth,
    double lineHeight,
  ) {
    final paths = <TextPath>[];
    final lines = TextEngine.split(
      text,
      maxWidth,
      (value) => measure(value).width,
    );

    // Create path for each line
    double cursor = y;
    for (final line in lines) {
      final position = _position(line, x, cursor, fontSize);
      paths.add(
        TextPath(
          text: line,
          path: _place(line, position.x, position.y),
          position: position,
        ),
      );
      // Graphics space is Y-up, so the next line is lower
      cursor -= lineHeight;
    }

    return paths;
  }

  /// Shape text with font fallback support
  ShapedText _shape(
    String text,
    double fontSize, {
    required TextDirection direction,
    required ScriptType script,
    String? language,
    List<String>? features,
  }) {
    if (_chain == null || _shaper == null) {
      // Fallback to simple shaping
      final typeface = font;
      if (typeface == null) {
        throw FontException(FontErrorMessages.noFontAvailable);
      }
      return _shaper?.shape(
            text,
            typeface,
            fontSize,
            direction: direction,
            script: script,
            language: language,
            features: features,
          ) ??
          ShapedText(glyphs: [], advance: 0, direction: direction);
    }

    // Split text into pieces of one font and one bidi level, shape each in
    // its own direction, and order the pieces as L2 orders runs
    final levels = Bidi.levels(text, direction);
    final pieces = <({String text, Font? font, int level, int offset})>[];
    var offset = 0;
    for (final run in _chain.runs(text)) {
      var start = 0;
      for (var i = 1; i <= run.text.length; i++) {
        if (i == run.text.length ||
            levels[offset + i] != levels[offset + start]) {
          pieces.add((
            text: run.text.substring(start, i),
            font: run.font,
            level: levels[offset + start],
            offset: offset + start,
          ));
          start = i;
        }
      }
      offset += run.text.length;
    }

    final glyphs = <ShapedGlyph>[];
    double advance = 0;
    for (final index in Bidi.order([for (final piece in pieces) piece.level])) {
      final piece = pieces[index];
      final font = piece.font;
      if (font != null) {
        final shaped = _shaper.shape(
          piece.text,
          font,
          fontSize,
          direction: piece.level.isOdd ? TextDirection.rtl : TextDirection.ltr,
          script: script,
          language: language,
          features: features,
        );

        // Adjust cluster indices and add glyphs
        for (final glyph in shaped.glyphs) {
          glyphs.add(
            ShapedGlyph(
              glyph: glyph.glyph,
              cluster: glyph.cluster + piece.offset,
              xAdvance: glyph.xAdvance,
              yAdvance: glyph.yAdvance,
              xOffset: glyph.xOffset,
              yOffset: glyph.yOffset,
              font: font,
            ),
          );
        }

        advance += shaped.advance;
      } else {
        // Handle missing glyphs with tofu (□)
        final width = fontSize * 0.6;
        for (int i = 0; i < piece.text.length; i++) {
          glyphs.add(
            ShapedGlyph(
              glyph: 0, // Missing glyph
              cluster: piece.offset + i,
              xAdvance: width,
              yAdvance: 0,
              font: null,
            ),
          );
          advance += width;
        }
      }
    }

    return ShapedText(
      glyphs: glyphs,
      advance: advance,
      direction: Bidi.paragraph(text, direction).isOdd
          ? TextDirection.rtl
          : TextDirection.ltr,
    );
  }

  /// Convert shaped text to path
  Path _build(ShapedText shaped, double x, double y, double fontSize) {
    final builder = PathBuilder();
    double currentX = x;
    double currentY = y;

    for (final glyph in shaped.glyphs) {
      if (glyph.glyph == 0) {
        // Draw tofu (□) for missing glyphs
        final size = fontSize * 0.6;

        builder.moveTo(currentX, currentY - fontSize * 0.8);
        builder.lineTo(currentX + size, currentY - fontSize * 0.8);
        builder.lineTo(currentX + size, currentY);
        builder.lineTo(currentX, currentY);
        builder.closePath();
      } else {
        // Get glyph path from appropriate font
        final typeface = glyph.font ?? _chain?.primary ?? font;
        if (typeface == null) continue;

        final outline = typeface.outline(glyph.glyph, fontSize);

        // Apply position and offset
        final glyphX = currentX + glyph.xOffset;
        final glyphY = currentY + glyph.yOffset;

        // Merge glyph path
        for (final command in outline.commands) {
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
            builder.bezierCurveTo(
              command.points[0].x + glyphX,
              command.points[0].y + glyphY,
              command.points[1].x + glyphX,
              command.points[1].y + glyphY,
              command.points[2].x + glyphX,
              command.points[2].y + glyphY,
            );
          } else if (command.type == PathCommandType.close) {
            builder.closePath();
          }
        }
      }

      // Advance position
      currentX += glyph.xAdvance;
      currentY += glyph.yAdvance;
    }

    return builder.build();
  }

  /// Get Unicode category for a code point
  static UnicodeCategory category(int codePoint) {
    if (_isLetter(codePoint)) return UnicodeCategory.letter;
    if (_isMark(codePoint)) return UnicodeCategory.mark;
    if (_isNumber(codePoint)) return UnicodeCategory.number;
    if (_isPunctuation(codePoint)) return UnicodeCategory.punctuation;
    if (_isSymbol(codePoint)) return UnicodeCategory.symbol;
    if (_isSeparator(codePoint)) return UnicodeCategory.separator;
    return UnicodeCategory.other;
  }

  static bool _isLetter(final int codePoint) {
    return (codePoint >= 0x0041 && codePoint <= 0x005A) || // Latin uppercase
        (codePoint >= 0x0061 && codePoint <= 0x007A) || // Latin lowercase
        (codePoint >= 0x00C0 && codePoint <= 0x00FF) || // Latin extended
        (codePoint >= 0x0100 && codePoint <= 0x017F) || // Latin extended A
        (codePoint >= 0x0400 && codePoint <= 0x04FF) || // Cyrillic
        (codePoint >= 0x0530 && codePoint <= 0x058F) || // Armenian
        (codePoint >= 0x0590 && codePoint <= 0x05FF) || // Hebrew
        (codePoint >= 0x0600 && codePoint <= 0x06FF) || // Arabic
        (codePoint >= 0x4E00 && codePoint <= 0x9FFF); // CJK
  }

  static bool _isMark(final int codePoint) {
    return (codePoint >= 0x0300 && codePoint <= 0x036F) || // Combining marks
        (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) ||
        (codePoint >= 0x1DC0 && codePoint <= 0x1DFF);
  }

  static bool _isNumber(final int codePoint) {
    return (codePoint >= 0x0030 && codePoint <= 0x0039) || // ASCII digits
        (codePoint >= 0x0660 && codePoint <= 0x0669) || // Arabic-Indic digits
        (codePoint >= 0x06F0 && codePoint <= 0x06F9) || // Extended Arabic-Indic
        (codePoint >= 0x0966 && codePoint <= 0x096F); // Devanagari digits
  }

  static bool _isPunctuation(final int codePoint) {
    return (codePoint >= 0x0021 && codePoint <= 0x0023) ||
        (codePoint >= 0x0025 && codePoint <= 0x002A) ||
        (codePoint >= 0x002C && codePoint <= 0x002F) ||
        (codePoint >= 0x003A && codePoint <= 0x003B) ||
        (codePoint >= 0x003F && codePoint <= 0x0040) ||
        (codePoint >= 0x005B && codePoint <= 0x005D) ||
        (codePoint >= 0x007B && codePoint <= 0x007D);
  }

  static bool _isSymbol(final int codePoint) {
    return (codePoint >= 0x0024 && codePoint <= 0x0024) || // Dollar
        (codePoint >= 0x002B && codePoint <= 0x002B) || // Plus
        (codePoint >= 0x003C && codePoint <= 0x003E) || // Less/Greater
        (codePoint >= 0x005E && codePoint <= 0x005E) || // Caret
        (codePoint >= 0x007C && codePoint <= 0x007C) || // Pipe
        (codePoint >= 0x007E && codePoint <= 0x007E); // Tilde
  }

  static bool _isSeparator(final int codePoint) {
    return codePoint == 0x0020 || // Space
        codePoint == 0x00A0 || // Non-breaking space
        codePoint == 0x2002 || // En space
        codePoint == 0x2003 || // Em space
        codePoint == 0x2009 || // Thin space
        codePoint == 0x200A || // Hair space
        codePoint == 0x202F || // Narrow no-break space
        codePoint == 0x205F || // Medium mathematical space
        codePoint == 0x3000; // Ideographic space
  }
}

/// Represents a text path with metadata
class TextPath {
  final String text;
  final Path path;
  final TextPosition position;

  TextPath({required this.text, required this.path, required this.position});
}
