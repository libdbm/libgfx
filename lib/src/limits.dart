import 'errors.dart';

/// Resource limits applied to untrusted input before memory is allocated.
final class Limits {
  /// Largest accepted width or height, in pixels.
  final int dimension;

  /// Largest accepted pixel count (width x height).
  final int pixels;

  /// Largest accepted font file, in bytes.
  final int font;

  /// Deepest accepted nesting of composite glyphs.
  final int depth;

  /// Largest accepted size of an expanded glyph: its outline points plus
  /// one for each component reference.
  final int points;

  /// Largest accepted blur radius, in pixels.
  final int radius;

  /// Largest number of dash pattern elements (dashes and gaps) applied to
  /// one path.
  final int dashes;

  /// Largest number of coverage entries and ligatures read from a font's
  /// GSUB table.
  final int ligatures;

  const Limits({
    this.dimension = 32768,
    this.pixels = 1 << 28,
    this.font = 64 << 20,
    this.depth = 16,
    this.points = 65536,
    this.radius = 256,
    this.dashes = 1000000,
    this.ligatures = 1 << 20,
  });

  /// Checks image dimensions read from input data. Negative dimensions are
  /// malformed input ([FormatException]); dimensions over these limits throw
  /// [ResourceLimitException].
  void require(final int width, final int height) {
    if (width < 0 || height < 0) {
      throw FormatException('Invalid image dimensions ${width}x$height');
    }
    if (width > dimension || height > dimension || width * height > pixels) {
      throw ResourceLimitException(
        'Image ${width}x$height exceeds the limits of $dimension pixels per '
        'side and $pixels pixels',
      );
    }
  }
}
