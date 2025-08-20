import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/spans/span.dart';
import 'package:test/test.dart';

void main() {
  group('ClipRegion', () {
    test('empty clip region', () {
      final clip = ClipRegion.empty();

      expect(clip.isEmpty, isTrue);
      expect(clip.bounds.width, equals(0));
      expect(clip.bounds.height, equals(0));
      expect(clip.spansByY, isEmpty);
    });

    test('rectangular clip region', () {
      final clip = ClipRegion.fromRect(10, 20, 100, 50);

      expect(clip.isEmpty, isFalse);
      expect(clip.bounds.left, equals(10));
      expect(clip.bounds.top, equals(20));
      expect(clip.bounds.width, equals(100));
      expect(clip.bounds.height, equals(50));

      // Check spans exist for each scanline
      for (int y = 20; y < 70; y++) {
        expect(clip.spansByY.containsKey(y), isTrue);
        expect(clip.spansByY[y]!.length, equals(1));
        expect(clip.spansByY[y]![0].x1, equals(10));
        expect(clip.spansByY[y]![0].x2, equals(110));
      }
    });

    test('clip region from simple path', () {
      // Create a triangular path
      final builder = PathBuilder();
      builder.moveTo(50.0, 10.0);
      builder.lineTo(100.0, 90.0);
      builder.lineTo(0.0, 90.0);
      builder.close();
      final path = builder.build();

      final matrix = Matrix2D.identity();
      final clip = ClipRegion.fromPath(path, matrix, 200, 200);

      expect(clip.isEmpty, isFalse);
      expect(clip.bounds.left, greaterThanOrEqualTo(0));
      expect(clip.bounds.top, greaterThanOrEqualTo(10));
      expect(clip.bounds.right, lessThanOrEqualTo(100));
      expect(clip.bounds.bottom, lessThanOrEqualTo(90));
    });

    test('clip region contains point', () {
      final clip = ClipRegion.fromRect(10, 20, 100, 50);

      // Points inside
      expect(clip.contains(50, 40), isTrue);
      expect(clip.contains(10, 20), isTrue);
      expect(clip.contains(109, 69), isTrue);

      // Points outside
      expect(clip.contains(5, 40), isFalse);
      expect(clip.contains(150, 40), isFalse);
      expect(clip.contains(50, 10), isFalse);
      expect(clip.contains(50, 80), isFalse);
    });

    test('clip region intersection - overlapping rectangles', () {
      final clip1 = ClipRegion.fromRect(10, 10, 100, 100);
      final clip2 = ClipRegion.fromRect(60, 60, 100, 100);

      final intersection = clip1.intersect(clip2);

      expect(intersection.isEmpty, isFalse);
      expect(intersection.bounds.left, equals(60));
      expect(intersection.bounds.top, equals(60));
      expect(intersection.bounds.width, equals(50));
      expect(intersection.bounds.height, equals(50));
    });

    test('clip region intersection - non-overlapping', () {
      final clip1 = ClipRegion.fromRect(10, 10, 50, 50);
      final clip2 = ClipRegion.fromRect(100, 100, 50, 50);

      final intersection = clip1.intersect(clip2);

      expect(intersection.isEmpty, isTrue);
    });

    test('clip region intersection - nested rectangles', () {
      final outer = ClipRegion.fromRect(10, 10, 200, 200);
      final inner = ClipRegion.fromRect(50, 50, 100, 100);

      final intersection = outer.intersect(inner);

      // Intersection should be the inner rectangle
      expect(intersection.bounds.left, equals(50));
      expect(intersection.bounds.top, equals(50));
      expect(intersection.bounds.width, equals(100));
      expect(intersection.bounds.height, equals(100));
    });

    test('clip spans', () {
      final clip = ClipRegion.fromRect(20, 30, 60, 40);

      final testSpans = [
        Span.from(40, 10, 100), // Crosses clip region
        Span.from(40, 25, 75), // Partially inside
        Span.from(40, 50, 60), // Fully inside
        Span.from(20, 50, 60), // Outside clip region Y
        Span.from(40, 5, 15), // Outside clip region X
      ];

      final clipped = clip.clipSpans(testSpans);

      // Should have 3 clipped spans on scanline 40
      expect(clipped.length, equals(3));

      // First span clipped to [20, 80]
      expect(clipped[0].y, equals(40));
      expect(clipped[0].x1, equals(20));
      expect(clipped[0].x2, equals(80));

      // Second span clipped to [25, 75]
      expect(clipped[1].y, equals(40));
      expect(clipped[1].x1, equals(25));
      expect(clipped[1].x2, equals(75));

      // Third span unchanged [50, 60]
      expect(clipped[2].y, equals(40));
      expect(clipped[2].x1, equals(50));
      expect(clipped[2].x2, equals(60));
    });
  });

  group('GraphicsEngine Clipping', () {
    test('rectangular clipping', () {
      final engine = GraphicsEngine(200, 200);

      // Set white background
      engine.setFillColor(Color(0xFFFFFFFF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Set clip rectangle
      engine.clipRect(50, 50, 100, 100);

      // Draw a large red circle that should be clipped
      engine.setFillColor(Color(0xFFFF0000));
      final circle = PathBuilder();
      _addCircle(circle, 100, 100, 80);
      engine.fill(circle.build());

      // Check that pixels outside clip are still white
      expect(engine.canvas.getPixel(10, 10).value, equals(0xFFFFFFFF));
      expect(engine.canvas.getPixel(190, 190).value, equals(0xFFFFFFFF));

      // Check that pixels inside clip are red (approximately)
      final centerPixel = engine.canvas.getPixel(100, 100).value;
      expect((centerPixel >> 16) & 0xFF, greaterThan(200)); // Red channel
    });

    test('path clipping', () {
      final engine = GraphicsEngine(200, 200);

      // Set white background
      engine.setFillColor(Color(0xFFFFFFFF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Create circular clip path
      final clipPath = PathBuilder();
      _addCircle(clipPath, 100, 100, 50);
      engine.clip(clipPath.build());

      // Fill entire canvas with blue - should only show inside circle
      engine.setFillColor(Color(0xFF0000FF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Check corners are still white
      expect(engine.canvas.getPixel(10, 10).value, equals(0xFFFFFFFF));
      expect(engine.canvas.getPixel(190, 10).value, equals(0xFFFFFFFF));
      expect(engine.canvas.getPixel(10, 190).value, equals(0xFFFFFFFF));
      expect(engine.canvas.getPixel(190, 190).value, equals(0xFFFFFFFF));

      // Check center is blue
      final centerPixel = engine.canvas.getPixel(100, 100);
      final centerColor = centerPixel;
      expect(centerColor.blue, greaterThan(200)); // Blue channel
    });

    test('nested clipping', () {
      final engine = GraphicsEngine(200, 200);

      // White background
      engine.setFillColor(Color(0xFFFFFFFF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // First clip to a rectangle
      engine.clipRect(25, 25, 150, 150);

      // Then clip to a circle - should be intersection
      final clipCircle = PathBuilder();
      _addCircle(clipCircle, 100, 100, 60);
      engine.clip(clipCircle.build());

      // Fill with green
      engine.setFillColor(Color(0xFF00FF00));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Corners should be white (outside both clips)
      expect(engine.canvas.getPixel(10, 10).value, equals(0xFFFFFFFF));

      // Just inside rectangle but outside circle should be white
      expect(engine.canvas.getPixel(30, 30).value, equals(0xFFFFFFFF));

      // Center (inside both) should be green
      final centerPixel = engine.canvas.getPixel(100, 100);
      final centerColor = centerPixel;
      expect(centerColor.green, greaterThan(200)); // Green channel
    });

    test('clipping with save/restore', () {
      final engine = GraphicsEngine(200, 200);

      // White background
      engine.setFillColor(Color(0xFFFFFFFF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Save state
      engine.save();

      // Set clip
      engine.clipRect(50, 50, 100, 100);

      // Draw red square
      engine.setFillColor(Color(0xFFFF0000));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Restore state (removes clip)
      engine.restore();

      // Draw blue in top-left corner - should not be clipped
      engine.setFillColor(Color(0xFF0000FF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(40, 0)
              ..lineTo(40, 40)
              ..lineTo(0, 40)
              ..close())
            .build(),
      );

      // Top-left should be blue (no clipping after restore)
      // Graphics (20, 20) -> Bitmap (20, 179) due to Y-flip
      final topLeftPixel = engine.canvas.getPixel(20, 179).value;
      expect(topLeftPixel & 0xFF, greaterThan(200)); // Blue channel (bits 0-7)

      // Center should be red (from clipped draw)
      // Graphics (100, 100) -> Bitmap (100, 99)
      final centerPixel = engine.canvas.getPixel(100, 99).value;
      expect((centerPixel >> 16) & 0xFF, greaterThan(200)); // Red channel
    });

    test('clipping with transformations', () {
      final engine = GraphicsEngine(200, 200);

      // White background
      engine.setFillColor(Color(0xFFFFFFFF));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // Apply rotation
      engine.translate(100, 100);
      engine.rotate(math.pi / 4); // 45 degrees
      engine.translate(-100, -100);

      // Set rectangular clip (will be rotated)
      engine.clipRect(50, 50, 100, 100);

      // Fill with red
      engine.setFillColor(Color(0xFFFF0000));
      engine.fill(
        (PathBuilder()
              ..moveTo(0, 0)
              ..lineTo(200, 0)
              ..lineTo(200, 200)
              ..lineTo(0, 200)
              ..close())
            .build(),
      );

      // The clipped region should be a rotated square
      // Center should be red
      final centerPixel = engine.canvas.getPixel(100, 100).value;
      expect((centerPixel >> 16) & 0xFF, greaterThan(200)); // Red channel

      // Corners should be white (outside rotated clip)
      expect(engine.canvas.getPixel(10, 10).value, equals(0xFFFFFFFF));
      expect(engine.canvas.getPixel(190, 190).value, equals(0xFFFFFFFF));
    });
  });
}

void _addCircle(PathBuilder builder, double cx, double cy, double r) {
  const segments = 32;
  builder.moveTo(cx + r, cy);
  for (int i = 1; i <= segments; i++) {
    final angle = (i / segments) * 2 * math.pi;
    builder.lineTo(cx + r * math.cos(angle), cy + r * math.sin(angle));
  }
  builder.close();
}
