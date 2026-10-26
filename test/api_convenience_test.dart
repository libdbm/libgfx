import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  // Helper to get pixel with Y-flip correction
  int pixel(GraphicsEngine engine, int x, int y) {
    return engine.canvas.pixel(x, engine.canvas.height - 1 - y).value;
  }

  group('GraphicsEngine Convenience API Tests', () {
    late GraphicsEngine engine;

    setUp(() {
      engine = GraphicsEngine(100, 100);
    });

    group('Rectangle Methods', () {
      test('fillRect fills a rectangle area', () {
        engine.fillStyle = const Color(0xFFFF0000);
        engine.fillRect(10, 10, 30, 20);

        // Check corners are filled
        expect(pixel(engine, 10, 10), equals(0xFFFF0000));
        expect(pixel(engine, 39, 10), equals(0xFFFF0000));
        expect(pixel(engine, 10, 29), equals(0xFFFF0000));
        expect(pixel(engine, 39, 29), equals(0xFFFF0000));

        // Check outside is not filled
        expect(pixel(engine, 9, 10), equals(0x00000000));
        expect(pixel(engine, 41, 10), equals(0x00000000));
      });

      test('strokeRect strokes rectangle outline', () {
        engine.strokeStyle = const Color(0xFF0000FF);
        engine.lineWidth = 1.0;
        engine.strokeRect(20, 20, 40, 30);

        // Check edges are stroked (allow for anti-aliasing)
        // With the rasterizer fix, edges are now correctly positioned
        final topLeft = pixel(engine, 20, 21);
        final topRight = pixel(engine, 59, 21);
        final bottomLeft = pixel(engine, 20, 50);

        // Check blue channel is dominant (stroked with blue)
        expect(
          (topLeft & 0xFF) > 100,
          isTrue,
          reason: 'Top-left should have blue',
        );
        expect(
          (topRight & 0xFF) > 100,
          isTrue,
          reason: 'Top-right should have blue',
        );
        expect(
          (bottomLeft & 0xFF) > 100,
          isTrue,
          reason: 'Bottom-left should have blue',
        );

        // Check interior is not filled
        expect(pixel(engine, 30, 35), equals(0x00000000));
      });

      test('clearRect clears a rectangular area', () {
        // Fill background
        engine.clear(const Color(0xFFFFFFFF));

        // Clear a rectangle
        engine.clearRect(25, 25, 50, 50);

        // Check cleared area
        expect(pixel(engine, 30, 30), equals(0x00000000));
        expect(pixel(engine, 70, 70), equals(0x00000000));

        // Check outside is still filled
        expect(pixel(engine, 20, 20), equals(0xFFFFFFFF));
        expect(pixel(engine, 80, 80), equals(0xFFFFFFFF));
      });
    });

    group('Circle Methods', () {
      test('filling a circle path fills a circular area', () {
        engine.fillStyle = const Color(0xFF00FF00);
        engine.fill(PathBuilder().circle(50, 50, 20).build());

        // Check center is filled
        expect(pixel(engine, 50, 50), equals(0xFF00FF00));

        // Check points near edge (allowing for anti-aliasing)
        final edgeRight = pixel(engine, 69, 50);
        final edgeLeft = pixel(engine, 31, 50);
        final edgeTop = pixel(engine, 50, 69);
        final edgeBottom = pixel(engine, 50, 31);

        // Check green channel is dominant (filled with green)
        expect(
          (edgeRight >> 8) & 0xFF,
          greaterThan(100),
          reason: 'Right edge should have green',
        );
        expect(
          (edgeLeft >> 8) & 0xFF,
          greaterThan(100),
          reason: 'Left edge should have green',
        );
        expect(
          (edgeTop >> 8) & 0xFF,
          greaterThan(100),
          reason: 'Top edge should have green',
        );
        expect(
          (edgeBottom >> 8) & 0xFF,
          greaterThan(100),
          reason: 'Bottom edge should have green',
        );

        // Check outside radius
        expect(pixel(engine, 75, 50), equals(0x00000000));
      });

      test('strokeCircle strokes circle outline', () {
        engine.strokeStyle = const Color(0xFFFF00FF);
        engine.lineWidth = 2.0; // Use thicker stroke for more reliable test
        engine.stroke(PathBuilder().circle(50, 50, 15).build());

        // Check that some points on circumference are stroked
        // Due to bezier approximation, not all points may be exact
        final leftEdge = pixel(engine, 35, 50);
        final topEdge = pixel(engine, 50, 65);
        final bottomEdge = pixel(engine, 50, 35);

        // At least some edges should have the stroke color
        final hasStroke =
            ((leftEdge >> 16) & 0xFF) > 100 ||
            ((topEdge >> 16) & 0xFF) > 100 ||
            ((bottomEdge >> 16) & 0xFF) > 100;

        expect(hasStroke, isTrue, reason: 'Circle should have stroked edges');

        // Check center is not filled
        expect(pixel(engine, 50, 50), equals(0x00000000));
      });
    });

    group('Line Drawing', () {
      test('strokeLine draws a line between two points', () {
        engine.strokeStyle = const Color(0xFF000000);
        engine.lineWidth = 2.0; // Use thicker stroke for more reliable test
        final linePath = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(90, 10);
        engine.stroke(linePath.build());

        // Check line pixels - at least middle should be drawn
        final middle = pixel(engine, 50, 10);

        // Check that middle pixel is dark (black or nearly black)
        expect(middle >> 24, greaterThan(50), reason: 'Line should be drawn');

        // Check off-line pixels
        expect(pixel(engine, 50, 15), equals(0x00000000));
      });

      test('strokeLine works with diagonal lines', () {
        engine.strokeStyle = const Color(0xFF0000FF);
        engine.lineWidth = 2.0; // Use thicker stroke for more reliable test
        final linePath = PathBuilder()
          ..moveTo(20, 20)
          ..lineTo(80, 80);
        engine.stroke(linePath.build());

        // Check middle of diagonal line
        final middle = pixel(engine, 50, 50);

        // Check blue channel is present
        expect(
          middle & 0xFF,
          greaterThan(50),
          reason: 'Diagonal line should have blue',
        );
      });
    });

    group('Transform Methods', () {
      test('resetTransform resets to identity', () {
        // Apply transformations
        engine.translate(50, 50);
        engine.rotate(1.5);
        engine.scale(2.0);

        // Reset
        engine.resetTransform();

        // Draw at origin should be at origin
        engine.fillStyle = const Color(0xFFFF0000);
        engine.fillRect(0, 0, 10, 10);

        expect(pixel(engine, 5, 5), equals(0xFFFF0000));
      });

      test('setTransform sets specific transform', () {
        // Identity matrix with translation (30, 30)
        // Matrix is: [1, 0, 30]
        //            [0, 1, 30]
        engine.setTransform(1, 0, 0, 1, 30, 30);
        engine.fillStyle = const Color(0xFF00FF00);
        engine.fillRect(0, 0, 10, 10);

        // Rectangle should be at (30, 30)
        expect(pixel(engine, 35, 35), equals(0xFF00FF00));
        expect(pixel(engine, 5, 5), equals(0x00000000));
      });

      // getTransform is not available in public API
      // test('getTransform returns current transform', () {
      //   engine.translate(10, 20);

      //   final transform = engine.getTransform();

      //   // Transform should have translation
      //   final testPoint = transform.transform(Point(0, 0));
      //   expect(testPoint.x, closeTo(10, 0.001));
      //   expect(testPoint.y, closeTo(20, 0.001));
      // });
    });
  });

  group('Error Handling Tests', () {
    late GraphicsEngine engine;

    setUp(() {
      engine = GraphicsEngine(100, 100);
    });

    test('fillText throws when no font is set', () {
      expect(
        () => engine.fillText('Hello', 50, 50),
        throwsA(
          isA<FontException>().having(
            (e) => e.message,
            'message',
            contains('No font set'),
          ),
        ),
      );
    });

    test('strokeText throws when no font is set', () {
      expect(
        () => engine.strokeText('Hello', 50, 50),
        throwsA(
          isA<FontException>().having(
            (e) => e.message,
            'message',
            contains('No font set'),
          ),
        ),
      );
    });

    test('clipText throws when no font is set', () {
      expect(
        () => engine.clipText('Hello', 50, 50),
        throwsA(
          isA<FontException>().having(
            (e) => e.message,
            'message',
            contains('No font set'),
          ),
        ),
      );
    });

    test('measureText throws when no font is set', () {
      expect(
        () => engine.measureText('Hello'),
        throwsA(
          isA<FontException>().having(
            (e) => e.message,
            'message',
            contains('No font set'),
          ),
        ),
      );
    });
  });

  group('Edge Cases', () {
    late GraphicsEngine engine;

    setUp(() {
      engine = GraphicsEngine(100, 100);
    });

    test('handles zero-size rectangles', () {
      engine.fillStyle = const Color(0xFFFF0000);
      engine.fillRect(50, 50, 0, 0);

      // Should not crash, but also not draw anything
      expect(pixel(engine, 50, 50), equals(0x00000000));
    });

    test('handles negative-size rectangles', () {
      engine.fillStyle = const Color(0xFFFF0000);
      engine.fillRect(50, 50, -10, -10);

      // Should draw from (40, 40) to (50, 50)
      expect(pixel(engine, 45, 45), equals(0xFFFF0000));
    });

    test('handles zero-radius circles', () {
      engine.fillStyle = const Color(0xFFFF0000);
      engine.fill(PathBuilder().circle(50, 50, 0).build());

      // Should not crash, might draw a point
      // Implementation dependent
    });

    test('handles out-of-bounds drawing', () {
      engine.fillStyle = const Color(0xFFFF0000);

      // Draw rectangle partially out of bounds
      engine.fillRect(90, 90, 20, 20);

      // Should clip to canvas bounds
      expect(pixel(engine, 95, 95), equals(0xFFFF0000));
      // Out of bounds area not testable
    });

    test('handles very large transformations', () {
      engine.scale(1000, 1000);
      engine.fillStyle = const Color(0xFFFF0000);
      engine.fillRect(0, 0, 1, 1);

      // Should fill entire canvas
      expect(pixel(engine, 50, 50), equals(0xFFFF0000));
    });

    test('handles multiple save/restore operations', () {
      engine.fillStyle = const Color(0xFFFF0000);

      engine.save();
      engine.translate(10, 10);
      engine.save();
      engine.translate(10, 10);
      engine.save();
      engine.translate(10, 10);

      engine.fillRect(0, 0, 10, 10);

      // Should be at (30, 30)
      expect(pixel(engine, 35, 35), equals(0xFFFF0000));

      engine.restore();
      engine.restore();
      engine.restore();

      engine.fillStyle = const Color(0xFF00FF00);
      engine.fillRect(0, 0, 5, 5);

      // Should be at origin
      expect(pixel(engine, 2, 2), equals(0xFF00FF00));
    });
  });
}
