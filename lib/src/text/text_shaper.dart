import '../fonts/font.dart';
import 'arabic.dart';
import 'bidi.dart';
import 'text_types.dart' show TextDirection, ScriptType, TextMetrics;
import 'text_utils.dart';

/// A shaped glyph with position and advance information
class ShapedGlyph {
  final int glyph;
  final int cluster; // Character index in original text
  final double xAdvance;
  final double yAdvance;
  final double xOffset;
  final double yOffset;
  final Font? font; // Track which font this glyph comes from

  ShapedGlyph({
    required this.glyph,
    required this.cluster,
    required this.xAdvance,
    required this.yAdvance,
    this.xOffset = 0,
    this.yOffset = 0,
    this.font,
  });
}

/// Result of text shaping
class ShapedText {
  final List<ShapedGlyph> glyphs;
  final double advance;
  final TextDirection direction;
  final TextMetrics? metrics;

  ShapedText({
    required this.glyphs,
    required this.advance,
    required this.direction,
    this.metrics,
  });
}

/// Text shaper interface for complex text layout
abstract class TextShaper {
  /// Shape text into positioned glyphs
  ShapedText shape(
    String text,
    Font font,
    double fontSize, {
    TextDirection direction = TextDirection.auto,
    ScriptType script = ScriptType.auto,
    String? language,
    List<String>? features, // OpenType features like 'liga', 'kern'
  });

  /// Check if shaper is available
  bool get isAvailable;
}

/// Basic text shaper without complex layout support: one glyph per
/// character, Arabic letters in the forms [Arabic.join] picks, the font's
/// ligatures ([Font.ligate]), in visual
/// order by the simplified bidi algorithm of [Bidi], with brackets mirrored
/// in right-to-left runs
class BasicTextShaper implements TextShaper {
  @override
  bool get isAvailable => true;

  @override
  ShapedText shape(
    String text,
    Font font,
    double fontSize, {
    TextDirection direction = TextDirection.auto,
    ScriptType script = ScriptType.auto,
    String? language,
    List<String>? features,
  }) {
    final glyphs = <ShapedGlyph>[];

    final levels = Bidi.levels(text, direction);
    final resolved = Bidi.paragraph(text, direction).isOdd
        ? TextDirection.rtl
        : TextDirection.ltr;

    // Simple shaping: one glyph per character (properly handling
    // surrogates), with the joined forms of Arabic letters
    final points = TextUtils.iterateCodePoints(text).toList();
    final joined = Arabic.join([
      for (final point in points) point.codePoint,
    ], (code) => font.glyph(code) != 0);
    final mapped = <int>[];
    final clusters = <int>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (joined[i] == -1) continue; // absorbed by a lam-alef ligature

      // Get glyph from font, mirrored in right-to-left runs (L4)
      final glyph = font.glyph(
        levels[point.index].isOdd ? Bidi.mirror(joined[i]) : joined[i],
      );
      if (glyph == 0) continue; // 0 is typically the missing glyph
      mapped.add(glyph);
      clusters.add(point.index);
    }

    // The font's ligatures, in logical order; a ligature takes the cluster
    // of its first glyph
    var next = 0;
    for (final (glyph, length) in font.ligate(mapped)) {
      final dimensions = font.dimensions(glyph);
      final advance = (dimensions.advanceWidth / font.unitsPerEm) * fontSize;
      glyphs.add(
        ShapedGlyph(
          glyph: glyph,
          cluster: clusters[next],
          xAdvance: advance,
          yAdvance: 0,
          font: font,
        ),
      );
      next += length;
    }

    // Visual order (L2), so that kerning pairs visual neighbours
    final rank = List.filled(levels.length, 0);
    final order = Bidi.order(levels);
    for (var position = 0; position < order.length; position++) {
      rank[order[position]] = position;
    }
    glyphs.sort((a, b) => rank[a.cluster].compareTo(rank[b.cluster]));

    // Apply kerning if available and requested
    if (features?.contains('kern') ?? true) {
      _kern(glyphs, font, fontSize);
    }

    // Sum after kerning so the total matches the glyph advances
    final advance = glyphs.fold<double>(
      0,
      (sum, glyph) => sum + glyph.xAdvance,
    );

    // Get text metrics
    final metrics = font.measure(text, fontSize);

    return ShapedText(
      glyphs: glyphs,
      advance: advance,
      direction: resolved,
      metrics: metrics,
    );
  }

  /// Apply kerning adjustments to glyphs
  void _kern(List<ShapedGlyph> glyphs, Font font, double fontSize) {
    if (glyphs.length < 2) return;

    for (int i = 0; i < glyphs.length - 1; i++) {
      final kern = font.kerning(glyphs[i].glyph, glyphs[i + 1].glyph, fontSize);
      if (kern != 0) {
        // Adjust the advance of the current glyph
        glyphs[i] = ShapedGlyph(
          glyph: glyphs[i].glyph,
          cluster: glyphs[i].cluster,
          xAdvance: glyphs[i].xAdvance + kern,
          yAdvance: glyphs[i].yAdvance,
          xOffset: glyphs[i].xOffset,
          yOffset: glyphs[i].yOffset,
          font: glyphs[i].font,
        );
      }
    }
  }
}
