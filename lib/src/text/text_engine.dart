/// Consolidated text rendering engine for libgfx
/// Combines all text rendering functionality into a single, coherent system
library;

import '../errors.dart' show FontException;
import '../fonts/font.dart';
import '../fonts/font_error_messages.dart';
import '../fonts/font_fallback.dart';
import '../paths/path.dart' show Path, PathCommand;
import '../point.dart';
import 'bidi.dart';
import 'text_types.dart'
    show TextAlign, TextBaseline, TextDirection, ScriptType, TextMetrics;
import 'text_shaper.dart' show ShapedText, TextShaper, BasicTextShaper;

/// Text rendering engine with font management, shaping, and metrics calculation
class TextEngine {
  // Core properties
  Font? _font;
  final FontFallbackChain _chain;
  final TextShaper _shaper;
  double _fontSize;
  TextAlign _textAlign;
  TextBaseline _textBaseline;
  TextDirection _direction;

  // Caching
  final Map<String, ShapedText> _shapes = {};
  final Map<String, TextMetrics> _metrics = {};
  static const int maxCacheSize = 100;

  // Statistics
  int _hits = 0;
  int _misses = 0;

  /// Create a text engine with optional Unicode support
  TextEngine({
    Font? font,
    FontFallbackChain? fontChain,
    TextShaper? shaper,
    double fontSize = 12.0,
    TextAlign textAlign = TextAlign.start,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    TextDirection direction = TextDirection.ltr,
  }) : _font = font,
       _chain = fontChain ?? FontFallbackChain(),
       _shaper = shaper ?? BasicTextShaper(),
       _fontSize = fontSize,
       _textAlign = textAlign,
       _textBaseline = textBaseline,
       _direction = direction;

  /// Get the primary font for rendering
  Font? get font => _font ?? _chain.primary;

  /// Set the primary font
  set font(Font? value) {
    if (_font != value) {
      _font = value;
      purge();
    }
  }

  /// Current font size
  double get fontSize => _fontSize;
  set fontSize(double value) {
    if (_fontSize != value) {
      _fontSize = value;
      purge();
    }
  }

  /// Current text alignment
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign value) => _textAlign = value;

  /// Current text baseline
  TextBaseline get textBaseline => _textBaseline;
  set textBaseline(TextBaseline value) => _textBaseline = value;

  /// The paragraph direction of [path], and the side [TextAlign.start] and
  /// [TextAlign.end] mean
  TextDirection get direction => _direction;
  set direction(TextDirection value) => _direction = value;

  /// Add a font to the fallback chain
  void add(Font font) {
    _chain.add(font);
    purge();
  }

  /// Clear all caches
  void purge() {
    _shapes.clear();
    _metrics.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Get cache statistics
  Map<String, int> get stats => {
    'hits': _hits,
    'misses': _misses,
    'hitRate': _hits + _misses > 0 ? (_hits * 100 ~/ (_hits + _misses)) : 0,
  };

  /// Measure text with caching
  TextMetrics measure(String text, [double? fontSize]) {
    fontSize ??= _fontSize;
    final typeface = font;
    if (typeface == null) {
      throw FontException(FontErrorMessages.noFontSetMeasure);
    }

    // Check cache
    final key = '${text}_${fontSize}_${typeface.hashCode}';
    final cached = _metrics[key];
    if (cached != null) {
      _hits++;
      return cached;
    }

    // Measure and cache
    _misses++;
    final metrics = typeface.measure(text, fontSize);

    // Manage cache size
    if (_metrics.length >= maxCacheSize) {
      _metrics.remove(_metrics.keys.first);
    }
    _metrics[key] = metrics;

    return metrics;
  }

  /// Shape text with caching
  ShapedText shape(
    String text, {
    double? fontSize,
    TextDirection direction = TextDirection.auto,
    ScriptType script = ScriptType.auto,
    String? language,
    List<String>? features,
  }) {
    fontSize ??= _fontSize;
    final typeface = font;
    if (typeface == null) {
      throw FontException(FontErrorMessages.noFontSetGeneric);
    }

    // Generate cache key
    final key =
        '${text}_${fontSize}_${typeface.hashCode}_'
        '${direction.index}_${script.index}_${language ?? ""}_'
        '${features?.join(",") ?? ""}';

    // Check cache
    final cached = _shapes[key];
    if (cached != null) {
      _hits++;
      return cached;
    }

    // Shape and cache
    _misses++;
    final shaped = _shaper.shape(
      text,
      typeface,
      fontSize,
      direction: direction,
      script: script,
      language: language,
      features: features,
    );

    // Manage cache size
    if (_shapes.length >= maxCacheSize) {
      _shapes.remove(_shapes.keys.first);
    }
    _shapes[key] = shaped;

    return shaped;
  }

  /// Generate a path for text
  Path path(
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

    final typeface = font;
    if (typeface == null) {
      throw FontException(FontErrorMessages.noFontSet);
    }

    // Calculate adjusted position
    final position = _position(text, x, y, fontSize, align, baseline);

    // Shape the text
    final shaped = shape(text, fontSize: fontSize, direction: _direction);

    // Build the path
    final path = Path();
    double cursor = position.x;

    for (final glyph in shaped.glyphs) {
      final outline = (glyph.font ?? typeface).outline(glyph.glyph, fontSize);
      // The path is already scaled by the font's outline method
      // Transform and add to the main path
      final transformed = Path();
      for (final command in outline.commands) {
        final points = command.points.map((point) {
          return Point(
            point.x + cursor + glyph.xOffset,
            point.y + position.y + glyph.yOffset,
          );
        }).toList();
        transformed.add(PathCommand(command.type, points));
      }
      path.addPath(transformed);
      cursor += glyph.xAdvance;
    }

    return path;
  }

  /// Calculate adjusted text position based on alignment and baseline
  Point _position(
    String text,
    double x,
    double y,
    double fontSize,
    TextAlign align,
    TextBaseline baseline,
  ) {
    final metrics = measure(text, fontSize);
    // Align on the shaped run, which is what gets drawn
    final width = shape(
      text,
      fontSize: fontSize,
      direction: _direction,
    ).advance;
    final rtl = Bidi.paragraph(text, _direction).isOdd;

    // Horizontal alignment
    double left = x;
    switch (align) {
      case TextAlign.center:
        left = x - width / 2;
        break;
      case TextAlign.right:
        left = x - width;
        break;
      case TextAlign.start:
        left = rtl ? x - width : x;
        break;
      case TextAlign.end:
        left = rtl ? x : x - width;
        break;
      case TextAlign.left:
      case TextAlign.justify:
        // No adjustment needed
        break;
    }

    // Vertical baseline; graphics space is Y-up, so text hangs below a top
    // baseline and stands above a bottom one
    double base = y;
    switch (baseline) {
      case TextBaseline.top:
        base = y - metrics.ascent;
        break;
      case TextBaseline.middle:
        base = y - metrics.ascent / 2;
        break;
      case TextBaseline.bottom:
        base = y + metrics.descent.abs();
        break;
      case TextBaseline.alphabetic:
      case TextBaseline.ideographic:
      case TextBaseline.hanging:
        // Default position
        break;
    }

    return Point(left, base);
  }

  /// Layout multi-line text
  List<String> wrap(String text, double maxWidth, {double? fontSize}) {
    final size = fontSize ?? _fontSize;
    return split(text, maxWidth, (value) => measure(value, size).width);
  }

  /// Breaks [text] into lines no wider than [maxWidth], greedily by words.
  /// Any run of whitespace separates words; a word wider than [maxWidth]
  /// gets a line of its own. [width] measures a string, and must be
  /// additive apart from kerning between adjacent characters: the line's
  /// width is kept as a running total, adding the width of each word with
  /// its space and the kerning measured at the join, so each word is
  /// measured once rather than re-measuring the growing line.
  static List<String> split(
    String text,
    double maxWidth,
    double Function(String) width,
  ) {
    final lines = <String>[];
    final line = StringBuffer();
    final space = width(' ');
    var total = 0.0; // width of line
    var last = ''; // last character of line

    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (line.isEmpty) {
        line.write(word);
        total = width(word);
      } else {
        final join = width('$last ') - width(last) - space;
        final candidate = total + join + width(' $word');
        if (candidate <= maxWidth) {
          line
            ..write(' ')
            ..write(word);
          total = candidate;
        } else {
          lines.add(line.toString());
          line
            ..clear()
            ..write(word);
          total = width(word);
        }
      }
      last = String.fromCharCode(word.runes.last);
    }

    if (line.isNotEmpty) {
      lines.add(line.toString());
    }

    return lines;
  }

  /// Generate paths for multi-line text, the first line at y and each
  /// following line [lineSpacing] line heights below the one before
  List<Path> paths(
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
    final lines = wrap(text, maxWidth, fontSize: fontSize);
    final paths = <Path>[];

    double cursor = y;
    for (final line in lines) {
      paths.add(
        path(
          line,
          x,
          cursor,
          fontSize: fontSize,
          align: align,
          baseline: baseline,
        ),
      );

      final metrics = measure(line, fontSize);
      // Graphics space is Y-up, so the next line is lower
      cursor -= metrics.lineHeight * lineSpacing;
    }

    return paths;
  }
}
