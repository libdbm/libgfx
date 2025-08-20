import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

void main() {
  // Create a 400x400 canvas
  final engine = GraphicsEngine(400, 400);

  // Clear background to white
  engine.setFillColor(Color(0xFFFFFFFF));
  engine.fill(
    (PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(400, 0)
          ..lineTo(400, 400)
          ..lineTo(0, 400)
          ..close())
        .build(),
  );

  // Test 1: Basic rectangular clipping
  engine.save();
  engine.clipRect(50, 50, 100, 100);

  // Draw a large red circle that should be clipped
  engine.setFillColor(Color(0xFFFF0000));
  final circle1 = PathBuilder();
  _addCircle(circle1, 100, 100, 80);
  engine.fill(circle1.build());
  engine.restore();

  // Test 2: Circular clipping region
  engine.save();
  engine.translate(200, 0);
  final clipCircle = PathBuilder();
  _addCircle(clipCircle, 100, 100, 50);
  engine.clip(clipCircle.build());

  // Draw a blue square that should be clipped to circle shape
  engine.setFillColor(Color(0xFF0000FF));
  engine.fill(
    (PathBuilder()
          ..moveTo(50, 50)
          ..lineTo(150, 50)
          ..lineTo(150, 150)
          ..lineTo(50, 150)
          ..close())
        .build(),
  );
  engine.restore();

  // Test 3: Nested clipping (clip intersection)
  engine.save();
  engine.translate(0, 200);

  // First clip to a rectangle
  engine.clipRect(50, 50, 100, 100);

  // Then clip to a circle - should show intersection
  final clipCircle2 = PathBuilder();
  _addCircle(clipCircle2, 100, 100, 60);
  engine.clip(clipCircle2.build());

  // Draw green pattern
  engine.setFillColor(Color(0xFF00FF00));
  for (int i = 0; i < 8; i++) {
    engine.fill(
      (PathBuilder()
            ..moveTo(40.0 + i * 15, 40)
            ..lineTo(45.0 + i * 15, 40)
            ..lineTo(45.0 + i * 15, 160)
            ..lineTo(40.0 + i * 15, 160)
            ..close())
          .build(),
    );
  }
  engine.restore();

  // Test 4: Complex path clipping with transform
  engine.save();
  engine.translate(200, 200);
  engine.rotate(0.3);

  // Star-shaped clipping path
  final star = PathBuilder();
  _addStar(star, 100, 100, 60, 30, 5);
  engine.clip(star.build());

  // Draw gradient-like pattern
  for (int y = 40; y < 160; y += 5) {
    final intensity = ((y - 40) / 120 * 255).round();
    engine.setFillColor(
      Color(0xFF000000 | (intensity << 16) | (intensity << 8)),
    );
    engine.fill(
      (PathBuilder()
            ..moveTo(40, y.toDouble())
            ..lineTo(160, y.toDouble())
            ..lineTo(160, (y + 4).toDouble())
            ..lineTo(40, (y + 4).toDouble())
            ..close())
          .build(),
    );
  }
  engine.restore();

  // Save the result
  final ppmBytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'p3');
  final ppmData = String.fromCharCodes(ppmBytes);
  File('output/drawing.ppm').writeAsStringSync(ppmData);
  print('...output/drawing.ppm successfully saved');
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

void _addStar(
  PathBuilder builder,
  double cx,
  double cy,
  double outerR,
  double innerR,
  int points,
) {
  builder.moveTo(cx, cy - outerR);
  for (int i = 0; i < points * 2; i++) {
    final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
    final r = i.isEven ? outerR : innerR;
    builder.lineTo(cx + r * math.cos(angle), cy + r * math.sin(angle));
  }
  builder.close();
}
