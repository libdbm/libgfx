/// Constants for font-related error messages
class FontErrorMessages {
  static const String noFontSet =
      'No font set. Call setFont() before rendering text.';
  static const String noFontSetMeasure =
      'No font set. Call setFont() before measuring text.';
  static const String noFontSetGeneric =
      'No font set. Use setFont() or addFont() first.';
  static const String noFontAvailable = 'No font available';
  static const String fontFileNotFound = 'Font file not found: ';
  static const String invalidTrueTypeFormat = 'Invalid TrueType font format';

  // Private constructor to prevent instantiation
  FontErrorMessages._();
}
