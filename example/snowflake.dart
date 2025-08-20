import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

/// Creates a snowflake pattern similar to snowflak.ps
/// Original by Elizabeth D. Zwicky
void main() async {
  const width = 800;
  const height = 800;
  const minSize = 250.0;

  final engine = GraphicsEngine(width, height);
  final random = math.Random();

  // Calculate box size for tiling
  final inWidth = width / minSize;
  final inHeight = height / minSize;
  final boxSize = inWidth > inHeight
      ? width / inWidth.truncate()
      : height / inHeight.truncate();

  final tilesX = (width / boxSize).truncate();
  final tilesY = (height / boxSize).truncate();

  // Background - random pastel color
  final bgColor = Color.fromARGB(
    255,
    200 + random.nextInt(55),
    200 + random.nextInt(55),
    200 + random.nextInt(55),
  );
  engine.clear(bgColor);

  // Apply coordinate flip once
  engine.save();
  engine.translate(0, height.toDouble());
  engine.scale(1, -1);

  // Generate snowflakes in a grid
  for (int row = 0; row < tilesY; row++) {
    for (int col = 0; col < tilesX; col++) {
      engine.save();

      // Translate to tile position
      engine.translate(
        col * boxSize + boxSize / 2,
        row * boxSize + boxSize / 2,
      );

      // Create a unique snowflake
      _drawSnowflake(engine, random, boxSize * 0.4);

      engine.restore();
    }
  }

  engine.restore();

  await engine.saveToFile('output/snowflake.ppm');
  print('output/snowflake.ppm saved successfully!');
  print('A field of unique snowflakes has been rendered.');
}

void _drawSnowflake(GraphicsEngine engine, math.Random random, double size) {
  // Random colors for this snowflake
  final strokeColor = Color.fromARGB(
    255,
    random.nextInt(256),
    random.nextInt(256),
    256 - random.nextInt(56),
  );

  final fillColor = Color.fromARGB(
    255,
    random.nextInt(256),
    256 - random.nextInt(56),
    random.nextInt(256),
  );

  // Create one arm of the snowflake
  Path createArm() {
    final builder = PathBuilder();
    builder.moveTo(0, 0);

    // Random control points for curves
    final points = <Point>[];
    for (int i = 0; i < 15; i++) {
      points.add(
        Point(random.nextDouble() * size * 0.3, random.nextDouble() * size),
      );
    }

    // Create curves using the random points
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 3; j++) {
        final idx = i * 3 + j;
        if (idx + 2 < points.length) {
          builder.curveTo(
            points[idx].x,
            points[idx].y,
            points[idx + 1].x,
            points[idx + 1].y,
            points[idx + 2].x,
            points[idx + 2].y,
          );
        }
      }
    }

    // Mirror the arm
    builder.moveTo(0, 0);
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 3; j++) {
        final idx = i * 3 + j;
        if (idx + 2 < points.length) {
          builder.curveTo(
            -points[idx].x,
            points[idx].y,
            -points[idx + 1].x,
            points[idx + 1].y,
            -points[idx + 2].x,
            points[idx + 2].y,
          );
        }
      }
    }

    return builder.build();
  }

  // Draw the snowflake with 6-fold symmetry
  for (int i = 0; i < 6; i++) {
    engine.save();
    engine.rotate(i * math.pi / 3);

    final arm = createArm();

    // Fill and stroke each arm
    engine.setFillColor(fillColor);
    engine.fill(arm);

    engine.restore();
  }

  // Stroke all arms together
  engine.setStrokeColor(strokeColor);
  engine.setLineWidth(2);
  for (int i = 0; i < 6; i++) {
    engine.save();
    engine.rotate(i * math.pi / 3);

    final arm = createArm();
    engine.stroke(arm);

    engine.restore();
  }
}
