import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  final width = 600;
  final height = 600;

  final engine = GraphicsEngine(width, height);

  // Clear background with a dark blue
  engine.clear(const Color.fromARGB(255, 20, 30, 60));

  // Helper function to create a star path
  Path createStarPath(
    double centerX,
    double centerY,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    final builder = PathBuilder();
    final angleStep = (2 * math.pi) / (points * 2);

    // Start at the top point
    builder.moveTo(
      centerX + outerRadius * math.cos(-math.pi / 2),
      centerY + outerRadius * math.sin(-math.pi / 2),
    );

    // Create star points alternating between outer and inner radius
    for (int i = 1; i < points * 2; i++) {
      final radius = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + angleStep * i;
      builder.lineTo(
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      );
    }

    builder.close();
    return builder.build();
  }

  // Demo 1: Star-shaped clip with gradient background
  engine.save();

  // Create a star-shaped clipping region in the top-left
  final starClip1 = createStarPath(150, 150, 80, 40, 5);
  engine.clip(starClip1);

  // Draw a colorful gradient-like pattern that will be clipped
  for (int i = 0; i < 20; i++) {
    final progress = i / 20.0;
    final color = Color.fromARGB(
      255,
      (255 * progress).round(),
      (100 + 155 * (1 - progress)).round(),
      (200 * (1 - progress)).round(),
    );

    final circlePath = PathBuilder()
        .circle(150 - i * 2, 150 - i * 2, 100 - i * 3)
        .build();

    engine.setFillColor(color);
    engine.fill(circlePath);
  }

  engine.restore();

  // Demo 2: Inverted star clip (square with star cutout)
  engine.save();

  // Move to top-right quadrant
  engine.translate(300, 0);

  // Create a square with a star hole using path winding rules
  final builder2 = PathBuilder();

  // Outer square (clockwise)
  builder2.moveTo(50, 50);
  builder2.lineTo(250, 50);
  builder2.lineTo(250, 250);
  builder2.lineTo(50, 250);
  builder2.close();

  // Inner star (counter-clockwise for hole)
  final starCenterX = 150.0;
  final starCenterY = 150.0;
  final outerRadius = 60.0;
  final innerRadius = 30.0;
  final points = 5;
  final angleStep = (2 * math.pi) / (points * 2);

  // Move to first point of star (going counter-clockwise)
  builder2.moveTo(
    starCenterX + outerRadius * math.cos(-math.pi / 2),
    starCenterY + outerRadius * math.sin(-math.pi / 2),
  );

  // Draw star counter-clockwise
  for (int i = points * 2 - 1; i >= 0; i--) {
    final radius = (i % 2 == 0) ? outerRadius : innerRadius;
    final angle = -math.pi / 2 + angleStep * i;
    builder2.lineTo(
      starCenterX + radius * math.cos(angle),
      starCenterY + radius * math.sin(angle),
    );
  }
  builder2.close();

  final squareWithStarHole = builder2.build();

  // Fill the square with star cutout
  engine.setFillColor(const Color.fromARGB(255, 255, 200, 50));
  engine.fill(squareWithStarHole);

  // Add some stripes behind to show the hole
  engine.setStrokeColor(const Color.fromARGB(255, 100, 150, 255));
  engine.setLineWidth(3);
  for (int i = 0; i < 15; i++) {
    final y = 50.0 + i * 15;
    final linePath = PathBuilder().moveTo(40, y).lineTo(260, y).build();
    engine.stroke(linePath);
  }

  engine.restore();

  // Demo 3: Multiple overlapping clipped regions
  engine.save();

  // Move to bottom-left quadrant
  engine.translate(0, 300);

  // Create a hexagon clip
  final hexBuilder = PathBuilder();
  final hexCenterX = 150.0;
  final hexCenterY = 150.0;
  final hexRadius = 80.0;

  for (int i = 0; i < 6; i++) {
    final angle = (math.pi / 3) * i;
    final x = hexCenterX + hexRadius * math.cos(angle);
    final y = hexCenterY + hexRadius * math.sin(angle);

    if (i == 0) {
      hexBuilder.moveTo(x, y);
    } else {
      hexBuilder.lineTo(x, y);
    }
  }
  hexBuilder.close();

  engine.clip(hexBuilder.build());

  // Draw overlapping circles with different colors
  final colors = [
    const Color.fromARGB(180, 255, 100, 100),
    const Color.fromARGB(180, 100, 255, 100),
    const Color.fromARGB(180, 100, 100, 255),
  ];

  final positions = [
    [120.0, 120.0],
    [180.0, 120.0],
    [150.0, 170.0],
  ];

  for (int i = 0; i < 3; i++) {
    final circlePath = PathBuilder()
        .circle(positions[i][0], positions[i][1], 50)
        .build();

    engine.setFillColor(colors[i]);
    engine.fill(circlePath);
  }

  engine.restore();

  // Demo 4: Text-like pattern with circular clip
  engine.save();

  // Move to bottom-right quadrant
  engine.translate(300, 300);

  // Create a circular clipping region
  final circleClip = PathBuilder().circle(150, 150, 90).build();

  engine.clip(circleClip);

  // Draw a checkerboard pattern
  final squareSize = 20.0;
  for (int row = 0; row < 15; row++) {
    for (int col = 0; col < 15; col++) {
      if ((row + col) % 2 == 0) {
        final squarePath = PathBuilder()
            .moveTo(col * squareSize, row * squareSize)
            .lineTo((col + 1) * squareSize, row * squareSize)
            .lineTo((col + 1) * squareSize, (row + 1) * squareSize)
            .lineTo(col * squareSize, (row + 1) * squareSize)
            .close()
            .build();

        // Alternate between two colors
        final color = (row % 4 < 2)
            ? const Color.fromARGB(255, 255, 120, 180)
            : const Color.fromARGB(255, 120, 180, 255);

        engine.setFillColor(color);
        engine.fill(squarePath);
      }
    }
  }

  // Draw a star in the center
  final centerStar = createStarPath(150, 150, 40, 20, 8);
  engine.setFillColor(const Color.fromARGB(255, 255, 255, 100));
  engine.fill(centerStar);

  engine.restore();

  // Add labels for each demo
  engine.setStrokeColor(const Color.fromARGB(255, 200, 200, 200));
  engine.setLineWidth(1);

  // Draw dividing lines
  final hLine = PathBuilder().moveTo(0, 300).lineTo(600, 300).build();
  engine.stroke(hLine);

  final vLine = PathBuilder().moveTo(300, 0).lineTo(300, 600).build();
  engine.stroke(vLine);

  // Draw borders around each demo
  for (int i = 0; i < 2; i++) {
    for (int j = 0; j < 2; j++) {
      final x = i * 300.0;
      final y = j * 300.0;

      final borderPath = PathBuilder()
          .moveTo(x + 10, y + 10)
          .lineTo(x + 290, y + 10)
          .lineTo(x + 290, y + 290)
          .lineTo(x + 10, y + 290)
          .close()
          .build();

      engine.setStrokeColor(const Color.fromARGB(100, 255, 255, 255));
      engine.setLineWidth(0.5);
      engine.stroke(borderPath);
    }
  }

  // Save to file
  await engine.saveToFile('output/clip_demo.ppm');
  print(
    'Saved output/clip_demo.ppm - Demonstrates various clipping region shapes:',
  );
  print('  - Bottom-left: Star-shaped clip with gradient fill');
  print('  - Bottom-right: Square with star cutout (inverted clip)');
  print('  - Top-left: Hexagon clip with overlapping circles');
  print('  - Top-right: Circular clip with checkerboard pattern');
}
