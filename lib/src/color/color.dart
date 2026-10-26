import '../matrix.dart';
import '../paint.dart';
import '../point.dart';
import '../result.dart';

/// A class to hold a 32-bit ARGB color value.
/// This class is a pure Dart replacement for dart:ui.Color. A color is also
/// a [Paint] that paints itself everywhere.
class Color implements Paint {
  /// The 32-bit ARGB value.
  final int value;

  /// Creates a color from a 32-bit integer.
  const Color(this.value);

  /// Creates a color from the individual a, r, g, b channels.
  const Color.fromARGB(int a, int r, int g, int b)
    : value =
          (((a & 0xff) << 24) |
              ((r & 0xff) << 16) |
              ((g & 0xff) << 8) |
              ((b & 0xff) << 0)) &
          0xFFFFFFFF;

  /// Creates a color from the individual r, g, b, a channels (RGBA order).
  factory Color.fromRGBA(int r, int g, int b, int a) {
    return Color.fromARGB(a, r, g, b);
  }

  factory Color.clamped(double r, double g, double b, double a) {
    int clamp(final double channel) => channel.round().clamp(0, 255);
    return Color.fromRGBA(clamp(r), clamp(g), clamp(b), clamp(a));
  }

  /// Parses `#RRGGBB` or `#RRGGBBAA`; anything else is [ErrorKind.malformed]
  static Result<Color, ErrorDetails> parse(final String text) {
    final digits = RegExp(
      r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).firstMatch(text);
    if (digits == null) {
      return Err(
        ErrorDetails(
          ErrorKind.malformed,
          'Color must be #RRGGBB or #RRGGBBAA: $text',
        ),
      );
    }
    final hex = digits.group(1)!;
    final rgb = int.parse(hex.substring(0, 6), radix: 16);
    final alpha = hex.length == 8
        ? int.parse(hex.substring(6), radix: 16)
        : 255;
    return Ok(Color((alpha << 24) | rgb));
  }

  /// Transparent color constant
  static const Color transparent = Color(0x00000000);

  Color get white => Color(0xffffffff);

  Color get black => Color(0xff000000);

  /// The alpha channel of this color.
  int get alpha => (value >> 24) & 0xFF;

  /// The red channel of this color.
  int get red => (value >> 16) & 0xFF;

  /// The green channel of this color.
  int get green => (value >> 8) & 0xFF;

  /// The blue channel of this color.
  int get blue => value & 0xFF;

  // Short aliases for convenience
  int get a => alpha;

  int get r => red;

  int get g => green;

  int get b => blue;

  /// The opacity of the color from 0.0 (transparent) to 1.0 (opaque).
  double get opacity => alpha / 255.0;

  @override
  Color sample(final Point point, final Matrix2D inverse) => this;
}
