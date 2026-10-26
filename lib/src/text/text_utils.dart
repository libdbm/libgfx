/// Utility class for text processing and iteration
class TextUtils {
  // Private constructor to prevent instantiation
  TextUtils._();

  /// Iterator for text that properly handles surrogate pairs
  /// Returns an iterable of (index, codePoint) pairs
  static Iterable<TextCodePoint> iterateCodePoints(String text) sync* {
    for (int i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);

      // Handle surrogate pairs for proper Unicode support
      if (_isHigh(unit) && i + 1 < text.length) {
        final low = text.codeUnitAt(i + 1);
        if (_isLow(low)) {
          final codePoint = _combine(unit, low);
          yield TextCodePoint(i, codePoint, text.substring(i, i + 2));
          i++; // Skip the low surrogate
          continue;
        }
      }

      yield TextCodePoint(i, unit, text[i]);
    }
  }

  /// Check if a code unit is a high surrogate
  static bool _isHigh(final int unit) {
    return unit >= 0xD800 && unit <= 0xDBFF;
  }

  /// Check if a code unit is a low surrogate
  static bool _isLow(final int unit) {
    return unit >= 0xDC00 && unit <= 0xDFFF;
  }

  /// Combine high and low surrogates into a single code point
  static int _combine(int high, int low) {
    return 0x10000 + ((high & 0x3FF) << 10) + (low & 0x3FF);
  }
}

/// Represents a code point with its index and character representation
class TextCodePoint {
  final int index;
  final int codePoint;
  final String character;

  const TextCodePoint(this.index, this.codePoint, this.character);
}
