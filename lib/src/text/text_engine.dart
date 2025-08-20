/// Consolidated text rendering engine for libgfx
/// Combines all text rendering functionality into a single, coherent system
library;

import '../errors.dart' show FontException;
import '../fonts/font.dart';
import '../fonts/font_error_messages.dart';
import '../fonts/font_fallback.dart';
import '../paths/path.dart' show Path, PathCommand;
import '../point.dart';
import 'text_types.dart'
    show
        TextAlign,
        TextBaseline,
        TextOperation,
        TextDirection,
        ScriptType,
        TextMetrics;
import 'text_shaper.dart' show ShapedText, TextShaper, BasicTextShaper;

/// Text rendering engine with font management, shaping, and metrics calculation
class TextEngine {
  // Core properties
  Font? _font;
  final FontFallbackChain _fontChain;
  final TextShaper _shaper;
  double _fontSize;
  TextAlign _textAlign;
  TextBaseline _textBaseline;

  // Caching
  final Map<String, ShapedText> _shapedCache = {};
  final Map<String, TextMetrics> _metricsCache = {};
  static const int maxCacheSize = 100;

  // Statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Create a text engine with optional Unicode support
  TextEngine({
    Font? font,
    FontFallbackChain? fontChain,
    TextShaper? shaper,
    double fontSize = 12.0,
    TextAlign textAlign = TextAlign.left,
    TextBaseline textBaseline = TextBaseline.alphabetic,
  }) : _font = font,
       _fontChain = fontChain ?? FontFallbackChain(),
       _shaper = shaper ?? BasicTextShaper(),
       _fontSize = fontSize,
       _textAlign = textAlign,
       _textBaseline = textBaseline;

  /// Get the primary font for rendering
  Font? get font => _font ?? _fontChain.primaryFont;

  /// Set the primary font
  set font(Font? value) {
    if (_font != value) {
      _font = value;
      clearCache();
    }
  }

  /// Current font size
  double get fontSize => _fontSize;
  set fontSize(double value) {
    if (_fontSize != value) {
      _fontSize = value;
      clearCache();
    }
  }

  /// Current text alignment
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign value) => _textAlign = value;

  /// Current text baseline
  TextBaseline get textBaseline => _textBaseline;
  set textBaseline(TextBaseline value) => _textBaseline = value;

  /// Add a font to the fallback chain
  void addFont(Font font) {
    _fontChain.addFont(font);
    clearCache();
  }

  /// Clear all caches
  void clearCache() {
    _shapedCache.clear();
    _metricsCache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Get cache statistics
  Map<String, int> get cacheStats => {
    'hits': _cacheHits,
    'misses': _cacheMisses,
    'hitRate': _cacheHits + _cacheMisses > 0
        ? (_cacheHits * 100 ~/ (_cacheHits + _cacheMisses))
        : 0,
  };

  /// Measure text with caching
  TextMetrics measureText(String text, [double? fontSize]) {
    fontSize ??= _fontSize;
    final currentFont = font;
    if (currentFont == null) {
      throw FontException(FontErrorMessages.noFontSetMeasure);
    }

    // Check cache
    final cacheKey = '${text}_${fontSize}_${currentFont.hashCode}';
    final cached = _metricsCache[cacheKey];
    if (cached != null) {
      _cacheHits++;
      return cached;
    }

    // Measure and cache
    _cacheMisses++;
    final metrics = currentFont.measureText(text, fontSize);

    // Manage cache size
    if (_metricsCache.length >= maxCacheSize) {
      _metricsCache.remove(_metricsCache.keys.first);
    }
    _metricsCache[cacheKey] = metrics;

    return metrics;
  }

  /// Shape text with caching
  ShapedText shapeText(
    String text, {
    double? fontSize,
    TextDirection direction = TextDirection.auto,
    ScriptType script = ScriptType.auto,
    String? language,
    List<String>? features,
  }) {
    fontSize ??= _fontSize;
    final currentFont = font;
    if (currentFont == null) {
      throw FontException(FontErrorMessages.noFontSetGeneric);
    }

    // Generate cache key
    final cacheKey =
        '${text}_${fontSize}_${currentFont.hashCode}_'
        '${direction.index}_${script.index}_${language ?? ""}_'
        '${features?.join(",") ?? ""}';

    // Check cache
    final cached = _shapedCache[cacheKey];
    if (cached != null) {
      _cacheHits++;
      return cached;
    }

    // Shape and cache
    _cacheMisses++;
    final shaped = _shaper.shapeText(
      text,
      currentFont,
      fontSize,
      direction: direction,
      script: script,
      language: language,
      features: features,
    );

    // Manage cache size
    if (_shapedCache.length >= maxCacheSize) {
      _shapedCache.remove(_shapedCache.keys.first);
    }
    _shapedCache[cacheKey] = shaped;

    return shaped;
  }

  /// Generate a path for text
  Path generateTextPath(
    String text,
    double x,
    double y, {
    double? fontSize,
    TextAlign? align,
    TextBaseline? baseline,
  }) {
    fontSize ??= _fontSize;
    align ??= _textAlign;
    baseline ??= _textBaseline;

    final currentFont = font;
    if (currentFont == null) {
      throw FontException(FontErrorMessages.noFontSet);
    }

    // Calculate adjusted position
    final position = _calculatePosition(text, x, y, fontSize, align, baseline);

    // Shape the text
    final shaped = shapeText(text, fontSize: fontSize);

    // Build the path
    final path = Path();
    double currentX = position.x;

    for (final glyph in shaped.glyphs) {
      final glyphPath = (glyph.font ?? currentFont).getGlyphPath(
        glyph.glyphId,
        fontSize,
      );
      // The path is already scaled by the font's getGlyphPath method
      // Transform and add to the main path
      final transformedPath = Path();
      for (final cmd in glyphPath.commands) {
        final transformedPoints = cmd.points.map((p) {
          return Point(
            p.x + currentX + glyph.xOffset,
            p.y + position.y + glyph.yOffset,
          );
        }).toList();
        transformedPath.addCommand(PathCommand(cmd.type, transformedPoints));
      }
      path.addPath(transformedPath);
      currentX += glyph.xAdvance;
    }

    return path;
  }

  /// Calculate adjusted text position based on alignment and baseline
  Point _calculatePosition(
    String text,
    double x,
    double y,
    double fontSize,
    TextAlign align,
    TextBaseline baseline,
  ) {
    final metrics = measureText(text, fontSize);

    // Horizontal alignment
    double adjustedX = x;
    switch (align) {
      case TextAlign.center:
        adjustedX = x - metrics.width / 2;
        break;
      case TextAlign.right:
        adjustedX = x - metrics.width;
        break;
      case TextAlign.left:
      case TextAlign.justify:
        // No adjustment needed
        break;
    }

    // Vertical baseline
    double adjustedY = y;
    switch (baseline) {
      case TextBaseline.top:
        adjustedY = y + metrics.ascent;
        break;
      case TextBaseline.middle:
        adjustedY = y + metrics.ascent / 2;
        break;
      case TextBaseline.bottom:
        adjustedY = y - metrics.descent;
        break;
      case TextBaseline.alphabetic:
      case TextBaseline.ideographic:
      case TextBaseline.hanging:
        // Default position
        break;
    }

    return Point(adjustedX, adjustedY);
  }

  /// Layout multi-line text
  List<String> layoutMultilineText(
    String text,
    double maxWidth, {
    double? fontSize,
    double lineSpacing = 1.2,
  }) {
    fontSize ??= _fontSize;
    final lines = <String>[];
    final words = text.split(RegExp(r'\s+'));

    String currentLine = '';
    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      final metrics = measureText(testLine, fontSize);

      if (metrics.width <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Generate paths for multi-line text
  List<Path> generateMultilineTextPaths(
    String text,
    double x,
    double y,
    double maxWidth, {
    double? fontSize,
    double lineSpacing = 1.2,
    TextAlign? align,
    TextBaseline? baseline,
  }) {
    fontSize ??= _fontSize;
    final lines = layoutMultilineText(text, maxWidth, fontSize: fontSize);
    final paths = <Path>[];

    double currentY = y;
    for (final line in lines) {
      paths.add(
        generateTextPath(
          line,
          x,
          currentY,
          fontSize: fontSize,
          align: align,
          baseline: baseline,
        ),
      );

      final metrics = measureText(line, fontSize);
      currentY += metrics.lineHeight * lineSpacing;
    }

    return paths;
  }
}

/// Mixin to add text rendering capabilities to GraphicsEngine
mixin TextRenderingMixin {
  // These must be provided by the class using this mixin
  TextEngine? get textEngine;
  void fill(Path path);
  void stroke(Path path);
  void clip(Path path);

  /// Render text with the specified operation
  void renderText(
    String text,
    double x,
    double y,
    TextOperation operation, {
    double? fontSize,
    TextAlign? align,
    TextBaseline? baseline,
  }) {
    final engine = textEngine;
    if (engine == null) {
      throw FontException('Text engine not initialized');
    }

    // Generate text path
    final path = engine.generateTextPath(
      text,
      x,
      y,
      fontSize: fontSize,
      align: align,
      baseline: baseline,
    );

    // Apply operation
    switch (operation) {
      case TextOperation.fill:
        fill(path);
        break;
      case TextOperation.stroke:
        stroke(path);
        break;
      case TextOperation.clip:
        clip(path);
        break;
      case TextOperation.fillAndStroke:
        fill(path);
        stroke(path);
        break;
    }
  }

  /// Fill text at the specified position
  void fillText(String text, double x, double y) {
    renderText(text, x, y, TextOperation.fill);
  }

  /// Stroke text at the specified position
  void strokeText(String text, double x, double y) {
    renderText(text, x, y, TextOperation.stroke);
  }

  /// Fill and stroke text at the specified position
  void fillAndStrokeText(String text, double x, double y) {
    renderText(text, x, y, TextOperation.fillAndStroke);
  }

  /// Measure text dimensions
  TextMetrics measureText(String text, [double? fontSize]) {
    final engine = textEngine;
    if (engine == null) {
      throw FontException('Text engine not initialized');
    }
    return engine.measureText(text, fontSize);
  }
}
