/// Common text rendering types and enums.
library;

/// Text rendering operations
enum TextOperation { fill, stroke, clip, fillAndStroke }

/// Text alignment options; [start] and [end] are left and right for
/// left-to-right text and the reverse for right-to-left text, as in W3C
/// canvas
enum TextAlign { start, end, left, right, center, justify }

/// Text baseline options
enum TextBaseline { alphabetic, top, middle, bottom, ideographic, hanging }

/// Text direction for bidirectional text
enum TextDirection {
  ltr, // Left-to-right
  rtl, // Right-to-left
  auto, // Automatically detect
}

/// Script type for text shaping
enum ScriptType {
  latin,
  arabic,
  hebrew,
  devanagari,
  chinese,
  japanese,
  korean,
  auto,
}

/// Text metrics returned by font measurement
class TextMetrics {
  final double width;
  final double height;
  final double ascent;
  final double descent;
  final double lineHeight;

  const TextMetrics({
    required this.width,
    required this.height,
    required this.ascent,
    required this.descent,
    required this.lineHeight,
  });
}

/// Represents an adjusted text position
class TextPosition {
  final double x;
  final double y;

  const TextPosition(this.x, this.y);
}
