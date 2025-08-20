import '../paths/path.dart';
import '../text/text_types.dart' show TextMetrics;

/// Represents a font face with metrics and glyph access
abstract class Font {
  /// The font family name (e.g., "Arial", "Times New Roman")
  String get familyName;

  /// The font style name (e.g., "Regular", "Bold", "Italic")
  String get styleName;

  /// The full font name combining family and style
  String get fullName => '$familyName $styleName';

  /// Units per em square (typically 1000 or 2048 for TrueType fonts)
  int get unitsPerEm;

  /// Font metrics in font units
  FontMetrics get metrics;

  /// Check if the font contains a glyph for the given character
  bool hasGlyph(int codePoint);

  /// Get the glyph index for a character code point
  int getGlyphIndex(int codePoint);

  /// Get glyph metrics for a specific glyph index
  GlyphMetrics getGlyphMetrics(int glyphIndex);

  /// Get the path outline for a glyph at the specified size
  Path getGlyphPath(int glyphIndex, double fontSize);

  /// Get kerning adjustment between two glyph indices
  double getKerning(int leftGlyphIndex, int rightGlyphIndex, double fontSize);

  /// Measure text dimensions
  TextMetrics measureText(String text, double fontSize);

  /// Get the path for rendering text
  Path getTextPath(String text, double x, double y, double fontSize);
}

/// Font metrics (ascender, descender, line gap, etc.)
class FontMetrics {
  /// Distance from baseline to highest ascender
  final int ascender;

  /// Distance from baseline to lowest descender (typically negative)
  final int descender;

  /// Recommended line spacing
  final int lineGap;

  /// Maximum advance width of any glyph
  final int maxAdvanceWidth;

  /// Maximum advance height of any glyph
  final int maxAdvanceHeight;

  /// Thickness of underline stroke
  final int underlineThickness;

  /// Position of underline relative to baseline
  final int underlinePosition;

  const FontMetrics({
    required this.ascender,
    required this.descender,
    required this.lineGap,
    required this.maxAdvanceWidth,
    required this.maxAdvanceHeight,
    required this.underlineThickness,
    required this.underlinePosition,
  });

  /// Total line height including line gap
  int get lineHeight => ascender - descender + lineGap;

  /// Scale metrics to a specific font size
  FontMetrics scale(double fontSize, int unitsPerEm) {
    final scale = fontSize / unitsPerEm;
    return FontMetrics(
      ascender: (ascender * scale).round(),
      descender: (descender * scale).round(),
      lineGap: (lineGap * scale).round(),
      maxAdvanceWidth: (maxAdvanceWidth * scale).round(),
      maxAdvanceHeight: (maxAdvanceHeight * scale).round(),
      underlineThickness: (underlineThickness * scale).round(),
      underlinePosition: (underlinePosition * scale).round(),
    );
  }
}

/// Metrics for an individual glyph
class GlyphMetrics {
  /// Horizontal advance width
  final int advanceWidth;

  /// Vertical advance height (usually 0 for horizontal text)
  final int advanceHeight;

  /// Left side bearing
  final int leftSideBearing;

  /// Top side bearing
  final int topSideBearing;

  /// Glyph bounding box
  final GlyphBoundingBox boundingBox;

  const GlyphMetrics({
    required this.advanceWidth,
    required this.advanceHeight,
    required this.leftSideBearing,
    required this.topSideBearing,
    required this.boundingBox,
  });

  /// Scale metrics to a specific font size
  GlyphMetrics scale(double fontSize, int unitsPerEm) {
    final scale = fontSize / unitsPerEm;
    return GlyphMetrics(
      advanceWidth: (advanceWidth * scale).round(),
      advanceHeight: (advanceHeight * scale).round(),
      leftSideBearing: (leftSideBearing * scale).round(),
      topSideBearing: (topSideBearing * scale).round(),
      boundingBox: boundingBox.scale(scale),
    );
  }
}

/// Bounding box for a glyph
class GlyphBoundingBox {
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;

  const GlyphBoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  int get width => xMax - xMin;

  int get height => yMax - yMin;

  GlyphBoundingBox scale(double scale) {
    return GlyphBoundingBox(
      xMin: (xMin * scale).round(),
      yMin: (yMin * scale).round(),
      xMax: (xMax * scale).round(),
      yMax: (yMax * scale).round(),
    );
  }
}
