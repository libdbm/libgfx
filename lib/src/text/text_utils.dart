import 'text_types.dart' show TextDirection;

/// Utility class for text processing and iteration
class TextUtils {
  // Private constructor to prevent instantiation
  TextUtils._();

  /// Iterator for text that properly handles surrogate pairs
  /// Returns an iterable of (index, codePoint) pairs
  static Iterable<TextCodePoint> iterateCodePoints(String text) sync* {
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);

      // Handle surrogate pairs for proper Unicode support
      if (_isHighSurrogate(codeUnit) && i + 1 < text.length) {
        final lowSurrogate = text.codeUnitAt(i + 1);
        if (_isLowSurrogate(lowSurrogate)) {
          final codePoint = _combineSurrogates(codeUnit, lowSurrogate);
          yield TextCodePoint(i, codePoint, text.substring(i, i + 2));
          i++; // Skip the low surrogate
          continue;
        }
      }

      yield TextCodePoint(i, codeUnit, text[i]);
    }
  }

  /// Iterate over text runes (handles surrogates automatically)
  static Iterable<int> iterateRunes(String text) {
    return text.runes;
  }

  /// Iterate over characters with index
  static Iterable<IndexedCharacter> iterateCharacters(String text) sync* {
    for (int i = 0; i < text.length; i++) {
      yield IndexedCharacter(i, text[i]);
    }
  }

  /// Check if a code unit is a high surrogate
  static bool _isHighSurrogate(int codeUnit) {
    return codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
  }

  /// Check if a code unit is a low surrogate
  static bool _isLowSurrogate(int codeUnit) {
    return codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
  }

  /// Combine high and low surrogates into a single code point
  static int _combineSurrogates(int high, int low) {
    return 0x10000 + ((high & 0x3FF) << 10) + (low & 0x3FF);
  }

  /// Check if text contains RTL characters
  static bool hasRTLCharacters(String text) {
    for (final char in text.runes) {
      if (_isRTLCharacter(char)) {
        return true;
      }
    }
    return false;
  }

  /// Check if a character is RTL
  static bool _isRTLCharacter(int codePoint) {
    return (codePoint >= 0x0590 && codePoint <= 0x05FF) || // Hebrew
        (codePoint >= 0x0600 && codePoint <= 0x06FF) || // Arabic
        (codePoint >= 0x0700 && codePoint <= 0x074F) || // Syriac
        (codePoint >= 0x0750 && codePoint <= 0x077F) || // Arabic Supplement
        (codePoint >= 0x08A0 && codePoint <= 0x08FF); // Arabic Extended-A
  }

  /// Check if a character is strong LTR
  static bool _isLTRCharacter(int codePoint) {
    return (codePoint >= 0x0041 && codePoint <= 0x005A) || // Latin uppercase
        (codePoint >= 0x0061 && codePoint <= 0x007A); // Latin lowercase
  }

  /// Detect text direction based on content
  static TextDirection detectDirection(String text) {
    for (final char in text.runes) {
      if (_isRTLCharacter(char)) {
        return TextDirection.rtl;
      }
      if (_isLTRCharacter(char)) {
        return TextDirection.ltr;
      }
    }
    return TextDirection.ltr; // Default to LTR
  }
}

/// Represents a code point with its index and character representation
class TextCodePoint {
  final int index;
  final int codePoint;
  final String character;

  const TextCodePoint(this.index, this.codePoint, this.character);
}

/// Represents a character with its index
class IndexedCharacter {
  final int index;
  final String character;

  const IndexedCharacter(this.index, this.character);
}
