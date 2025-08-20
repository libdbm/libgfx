import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/point.dart';
import 'package:test/test.dart';

void main() {
  group('PatternPaint', () {
    late Bitmap testPattern;

    setUp(() {
      // Create a simple 4x4 test pattern
      testPattern = Bitmap.empty(4, 4);

      // Fill with distinct colors
      for (int y = 0; y < 4; y++) {
        for (int x = 0; x < 4; x++) {
          final r = (x * 64).clamp(0, 255);
          final g = (y * 64).clamp(0, 255);
          final b = ((x + y) * 32).clamp(0, 255);
          testPattern.setPixel(x, y, Color.fromRGBA(r, g, b, 255));
        }
      }
    });

    test('creates pattern paint with default settings', () {
      final paint = PatternPaint(pattern: testPattern);

      expect(paint.pattern, equals(testPattern));
      expect(paint.repeat, equals(PatternRepeat.repeat));
      expect(paint.opacity, equals(1.0));
      expect(paint.transform, isNotNull);
    });

    test('creates pattern with custom settings', () {
      final paint = PatternPaint(
        pattern: testPattern,
        repeat: PatternRepeat.repeatX,
        opacity: 0.8,
      );

      expect(paint.pattern.width, equals(4));
      expect(paint.pattern.height, equals(4));
      expect(paint.repeat, equals(PatternRepeat.repeatX));
      expect(paint.opacity, equals(0.8));
    });

    test('samples pattern with repeat mode', () {
      final paint = PatternPaint(
        pattern: testPattern,
        repeat: PatternRepeat.repeat,
      );

      final identityTransform = Matrix2D.identity();

      // Test wrapping behavior
      final color1 = paint.getColorAt(Point(5, 5), identityTransform);
      expect(color1.red, equals(64)); // Should wrap to (1, 1)
      expect(color1.green, equals(64));

      final color2 = paint.getColorAt(Point(10, 10), identityTransform);
      expect(color2.red, equals(128)); // Should wrap to (2, 2)
      expect(color2.green, equals(128));
    });

    test('samples pattern with repeatX mode', () {
      final paint = PatternPaint(
        pattern: testPattern,
        repeat: PatternRepeat.repeatX,
      );

      final identityTransform = Matrix2D.identity();

      // X should wrap
      final color1 = paint.getColorAt(Point(5, 1), identityTransform);
      expect(color1.red, equals(64)); // Wraps to (1, 1)

      // Y should not wrap (return transparent)
      final color2 = paint.getColorAt(Point(1, 5), identityTransform);
      expect(color2, equals(Color.transparent));
    });

    test('samples pattern with repeatY mode', () {
      final paint = PatternPaint(
        pattern: testPattern,
        repeat: PatternRepeat.repeatY,
      );

      final identityTransform = Matrix2D.identity();

      // Y should wrap
      final color1 = paint.getColorAt(Point(1, 5), identityTransform);
      expect(color1.red, equals(64)); // Wraps to (1, 1)

      // X should not wrap (return transparent)
      final color2 = paint.getColorAt(Point(5, 1), identityTransform);
      expect(color2, equals(Color.transparent));
    });

    test('samples pattern with noRepeat mode', () {
      final paint = PatternPaint(
        pattern: testPattern,
        repeat: PatternRepeat.noRepeat,
      );

      final identityTransform = Matrix2D.identity();

      // Within bounds
      final color1 = paint.getColorAt(Point(2, 2), identityTransform);
      expect(color1.red, equals(128));
      expect(color1.green, equals(128));

      // Outside bounds (should return transparent)
      final color2 = paint.getColorAt(Point(5, 5), identityTransform);
      expect(color2, equals(Color.transparent));

      final color3 = paint.getColorAt(Point(-1, 2), identityTransform);
      expect(color3, equals(Color.transparent));
    });

    test('applies opacity to pattern', () {
      final paint = PatternPaint(pattern: testPattern, opacity: 0.5);

      final identityTransform = Matrix2D.identity();

      // Sample a pixel we know has full opacity
      final color = paint.getColorAt(Point(2, 2), identityTransform);
      expect(
        color.alpha,
        closeTo(127, 1),
      ); // 255 * 0.5 ≈ 127 (allow for rounding)
      expect(color.red, equals(128)); // Color values preserved
      expect(color.green, equals(128));
    });

    test('applies transformation to pattern', () {
      // Create a pattern with scale transform
      final transform = Matrix2D.identity()..scale(2.0, 2.0);
      final paint = PatternPaint(pattern: testPattern, transform: transform);

      final identityTransform = Matrix2D.identity();

      // Point (2, 2) should now sample from pattern (1, 1) due to 2x scale
      final color = paint.getColorAt(Point(2, 2), identityTransform);
      expect(color.red, equals(64)); // Pattern pixel at (1, 1)
      expect(color.green, equals(64));
    });

    test('uses bilinear interpolation for smooth sampling', () {
      final paint = PatternPaint(pattern: testPattern);
      final identityTransform = Matrix2D.identity();

      // Sample at fractional coordinates
      final color = paint.getColorAt(Point(1.5, 1.5), identityTransform);

      // Should be interpolated between surrounding pixels
      // Exact value depends on interpolation, but should be between surrounding values
      expect(color.red, greaterThan(64));
      expect(color.red, lessThan(128));
      expect(color.green, greaterThan(64));
      expect(color.green, lessThan(128));
    });

    test('handles edge cases correctly', () {
      final paint = PatternPaint(pattern: testPattern);
      final identityTransform = Matrix2D.identity();

      // Test corner pixels
      var color = paint.getColorAt(Point(0, 0), identityTransform);
      expect(color.red, equals(0));
      expect(color.green, equals(0));

      color = paint.getColorAt(Point(3, 3), identityTransform);
      expect(color.red, equals(192));
      expect(color.green, equals(192));

      // Test negative coordinates with repeat
      color = paint.getColorAt(Point(-1, -1), identityTransform);
      expect(color.red, equals(192)); // Should wrap to (3, 3)
      expect(color.green, equals(192));
    });

    test('pattern paint integrates with graphics state', () {
      // This test ensures PatternPaint can be used as a Paint
      final paint = PatternPaint(pattern: testPattern);

      // Should be assignable to Paint type
      Paint abstractPaint = paint;
      expect(abstractPaint, isA<PatternPaint>());

      // Should have getColorAt method
      final color = abstractPaint.getColorAt(Point(1, 1), Matrix2D.identity());
      expect(color, isNotNull);
    });
  });

  group('PatternRepeat', () {
    test('has all expected modes', () {
      expect(PatternRepeat.values.length, equals(4));
      expect(PatternRepeat.values, contains(PatternRepeat.repeat));
      expect(PatternRepeat.values, contains(PatternRepeat.repeatX));
      expect(PatternRepeat.values, contains(PatternRepeat.repeatY));
      expect(PatternRepeat.values, contains(PatternRepeat.noRepeat));
    });
  });
}
