/// Represents a horizontal span of pixels on a scanline with coverage for anti-aliasing
class Span {
  final int y; // Y coordinate (scanline)
  final int x; // Starting X coordinate
  final int length; // Length of the span
  final int coverage; // Coverage value (0-255) for anti-aliasing

  Span(this.y, this.x, this.length, [this.coverage = 255]);

  factory Span.from(int y, int x1, int x2, [int coverage = 255]) {
    return Span(y, x1, x2 - x1, coverage);
  }

  /// Get the ending X coordinate
  int get x2 => x + length;

  /// Get the starting X coordinate (alias for x)
  int get x1 => x;

  /// Check if this span overlaps with another span on the same scanline
  bool overlaps(Span other) {
    if (y != other.y) return false;
    return x < other.x2 && other.x < x2;
  }
}
