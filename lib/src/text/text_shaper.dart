import '../fonts/font.dart';
import 'text_types.dart' show TextDirection, ScriptType, TextMetrics;
import 'text_utils.dart';

/// A shaped glyph with position and advance information
class ShapedGlyph {
  final int glyphId;
  final int cluster; // Character index in original text
  final double xAdvance;
  final double yAdvance;
  final double xOffset;
  final double yOffset;
  final Font? font; // Track which font this glyph comes from

  ShapedGlyph({
    required this.glyphId,
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
  final double totalAdvance;
  final TextDirection direction;
  final TextMetrics? metrics;

  ShapedText({
    required this.glyphs,
    required this.totalAdvance,
    required this.direction,
    this.metrics,
  });
}

/// Text shaper interface for complex text layout
abstract class TextShaper {
  /// Shape text into positioned glyphs
  ShapedText shapeText(
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

/// Basic text shaper without complex layout support
class BasicTextShaper implements TextShaper {
  @override
  bool get isAvailable => true;

  @override
  ShapedText shapeText(
    String text,
    Font font,
    double fontSize, {
    TextDirection direction = TextDirection.auto,
    ScriptType script = ScriptType.auto,
    String? language,
    List<String>? features,
  }) {
    final glyphs = <ShapedGlyph>[];
    double totalAdvance = 0;

    // Detect direction if auto
    final detectedDirection = direction == TextDirection.auto
        ? TextUtils.detectDirection(text)
        : direction;

    // Simple shaping: one glyph per character (properly handling surrogates)
    for (final textPoint in TextUtils.iterateCodePoints(text)) {
      // Get glyph from font
      final glyphId = font.getGlyphIndex(textPoint.codePoint);
      if (glyphId == 0) continue; // 0 is typically the missing glyph

      // Get glyph metrics
      final glyphMetrics = font.getGlyphMetrics(glyphId);
      final advance = (glyphMetrics.advanceWidth / font.unitsPerEm) * fontSize;

      glyphs.add(
        ShapedGlyph(
          glyphId: glyphId,
          cluster: textPoint.index,
          xAdvance: advance,
          yAdvance: 0,
          font: font,
        ),
      );

      totalAdvance += advance;
    }

    // Apply kerning if available and requested
    if (features?.contains('kern') ?? true) {
      _applyKerning(glyphs, font, fontSize);
    }

    // Get text metrics
    final metrics = font.measureText(text, fontSize);

    return ShapedText(
      glyphs: glyphs,
      totalAdvance: totalAdvance,
      direction: detectedDirection,
      metrics: metrics,
    );
  }

  /// Apply kerning adjustments to glyphs
  void _applyKerning(List<ShapedGlyph> glyphs, Font font, double fontSize) {
    if (glyphs.length < 2) return;

    for (int i = 0; i < glyphs.length - 1; i++) {
      final kern = font.getKerning(
        glyphs[i].glyphId,
        glyphs[i + 1].glyphId,
        fontSize,
      );
      if (kern != 0) {
        // Adjust the advance of the current glyph
        glyphs[i] = ShapedGlyph(
          glyphId: glyphs[i].glyphId,
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
