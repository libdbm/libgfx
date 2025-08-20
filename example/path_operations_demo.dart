import 'dart:math' as math;

import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';

final _random = math.Random();

void main() async {
  final engine = GraphicsEngine(1200, 800);

  // Set background
  engine.clear(const Color(0xFF1a1a1a));

  // Demo various path operations
  demonstratePathSimplification(engine);
  demonstratePathOffset(engine);
  demonstrateBooleanOperations(engine);

  await engine.saveToFile('output/path_operations_demo.ppm');
  print('Saved output/path_operations_demo.ppm');
}

void demonstratePathSimplification(GraphicsEngine engine) {
  engine.save();
  engine.translate(50, 50);

  // Create a complex zigzag path
  final complexBuilder = PathBuilder()..moveTo(0, 0);

  // Add many points with slight variations
  for (int i = 1; i <= 20; i++) {
    final x = i * 10.0;
    final y =
        math.sin(i * 0.5) * 20 + (_random.nextDouble() - 0.5) * 5; // Add noise
    complexBuilder.lineTo(x, y);
  }
  final complexPath = complexBuilder.build();

  // Draw original path in red
  engine.setStrokeColor(const Color(0xFFFF4444));
  engine.setLineWidth(2);
  engine.stroke(complexPath);

  // Draw control points
  engine.setFillColor(const Color(0xFFFF4444));
  for (final command in complexPath.commands) {
    if (command.type == PathCommandType.lineTo ||
        command.type == PathCommandType.moveTo) {
      drawPoint(engine, command.points[0], 2);
    }
  }

  // Simplify with different tolerances
  final simplifiedLoose = complexPath.simplify(5.0);
  final simplifiedStrict = complexPath.simplify(1.0);

  // Draw simplified paths
  engine.translate(0, 80);
  engine.setStrokeColor(const Color(0xFF44FF44));
  engine.setLineWidth(3);
  engine.stroke(simplifiedStrict);

  engine.setFillColor(const Color(0xFF44FF44));
  for (final command in simplifiedStrict.commands) {
    if (command.type == PathCommandType.lineTo ||
        command.type == PathCommandType.moveTo) {
      drawPoint(engine, command.points[0], 3);
    }
  }

  engine.translate(0, 80);
  engine.setStrokeColor(const Color(0xFF4444FF));
  engine.setLineWidth(4);
  engine.stroke(simplifiedLoose);

  engine.setFillColor(const Color(0xFF4444FF));
  for (final command in simplifiedLoose.commands) {
    if (command.type == PathCommandType.lineTo ||
        command.type == PathCommandType.moveTo) {
      drawPoint(engine, command.points[0], 4);
    }
  }

  // Add labels
  drawLabel(
    engine,
    "Original (${complexPath.commands.length} commands)",
    220,
    -160,
    const Color(0xFFFF4444),
  );
  drawLabel(
    engine,
    "Strict Simplify (${simplifiedStrict.commands.length} commands)",
    220,
    -80,
    const Color(0xFF44FF44),
  );
  drawLabel(
    engine,
    "Loose Simplify (${simplifiedLoose.commands.length} commands)",
    220,
    0,
    const Color(0xFF4444FF),
  );

  engine.restore();
}

void demonstratePathOffset(GraphicsEngine engine) {
  engine.save();
  engine.translate(450, 50);

  // Create a star shape
  final starBuilder = PathBuilder();
  final centerX = 80.0;
  final centerY = 80.0;
  final outerRadius = 60.0;
  final innerRadius = 25.0;
  final points = 5;

  for (int i = 0; i <= points * 2; i++) {
    final angle = (i / (points * 2)) * 2 * math.pi - math.pi / 2;
    final radius = i % 2 == 0 ? outerRadius : innerRadius;
    final x = centerX + radius * math.cos(angle);
    final y = centerY + radius * math.sin(angle);

    if (i == 0) {
      starBuilder.moveTo(x, y);
    } else {
      starBuilder.lineTo(x, y);
    }
  }
  starBuilder.close();
  final starPath = starBuilder.build();

  // Draw original star
  engine.setFillColor(const Color(0x40FFFF00));
  engine.setStrokeColor(const Color(0xFFFFFF00));
  engine.setLineWidth(2);
  engine.fill(starPath);
  engine.stroke(starPath);

  // Note: Path offset functionality is not yet implemented
  // This would draw outward and inward offsets of the star shape

  // For now, just draw the star again translated
  engine.translate(0, 200);
  engine.fill(starPath);
  engine.stroke(starPath);

  // Labels
  drawLabel(
    engine,
    "Original + Outward Offsets",
    -80,
    -240,
    const Color(0xFFFFFFFF),
  );
  drawLabel(
    engine,
    "Original + Inward Offset",
    -80,
    -40,
    const Color(0xFFFFFFFF),
  );

  engine.restore();
}

void demonstrateBooleanOperations(GraphicsEngine engine) {
  engine.save();
  engine.translate(750, 50);

  // Create two overlapping shapes
  final rect1Builder = PathBuilder()
    ..moveTo(0, 0)
    ..lineTo(100, 0)
    ..lineTo(100, 80)
    ..lineTo(0, 80)
    ..close();
  final rect1 = rect1Builder.build();

  final circle1Builder = PathBuilder();
  final centerX = 60.0;
  final centerY = 40.0;
  final radius = 50.0;

  // Create circle as polygon
  for (int i = 0; i <= 32; i++) {
    final angle = (i / 32) * 2 * math.pi;
    final x = centerX + radius * math.cos(angle);
    final y = centerY + radius * math.sin(angle);

    if (i == 0) {
      circle1Builder.moveTo(x, y);
    } else {
      circle1Builder.lineTo(x, y);
    }
  }
  circle1Builder.close();
  final circle1 = circle1Builder.build();

  // Draw original shapes
  engine.setFillColor(const Color(0x60FF0000));
  engine.fill(rect1);
  engine.setFillColor(const Color(0x600000FF));
  engine.fill(circle1);

  engine.setStrokeColor(const Color(0xFFFF0000));
  engine.setLineWidth(2);
  engine.stroke(rect1);
  engine.setStrokeColor(const Color(0xFF0000FF));
  engine.stroke(circle1);

  // Demonstrate boolean operations
  final operations = [
    ('Union', rect1.union(circle1)),
    ('Intersection', rect1.intersection(circle1)),
    ('Difference', rect1.difference(circle1)),
    ('Exclusive OR', rect1.xor(circle1)),
  ];

  for (int i = 0; i < operations.length; i++) {
    final (name, result) = operations[i];

    engine.save();
    engine.translate((i % 2) * 150, (i ~/ 2) * 120 + 150);

    // Draw result
    engine.setFillColor(const Color(0x8000FF00));
    engine.setStrokeColor(const Color(0xFF00FF00));
    engine.setLineWidth(2);

    if (result.commands.isNotEmpty) {
      engine.fill(result);
      engine.stroke(result);
    }

    // Draw original shapes as outlines for context
    engine.setStrokeColor(const Color(0x80FFFFFF));
    engine.setLineWidth(1);
    engine.stroke(rect1);
    engine.stroke(circle1);

    // Label
    drawLabel(engine, name, -20, -20, const Color(0xFFFFFFFF));

    engine.restore();
  }

  drawLabel(engine, "Boolean Operations", -50, -30, const Color(0xFFFFFFFF));

  engine.restore();
}

void drawPoint(GraphicsEngine engine, Point point, double size) {
  final pointBuilder = PathBuilder()
    ..moveTo(point.x - size, point.y - size)
    ..lineTo(point.x + size, point.y - size)
    ..lineTo(point.x + size, point.y + size)
    ..lineTo(point.x - size, point.y + size)
    ..close();
  engine.fill(pointBuilder.build());
}

void drawLabel(
  GraphicsEngine engine,
  String text,
  double x,
  double y,
  Color color,
) {
  // Simple text representation using basic shapes
  // This is a placeholder since we don't have text rendering yet
  engine.save();
  engine.translate(x, y);
  engine.setFillColor(color);

  // Draw a simple rectangle as text placeholder
  final labelBuilder = PathBuilder()
    ..moveTo(0, 0)
    ..lineTo(text.length * 8.0, 0)
    ..lineTo(text.length * 8.0, 12)
    ..lineTo(0, 12)
    ..close();
  engine.stroke(labelBuilder.build());

  engine.restore();
}

void drawSimpleText(GraphicsEngine engine, String text, double x, double y) {
  // Very basic "text" using simple shapes
  engine.save();
  engine.translate(x, y);

  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    engine.save();
    engine.translate(i * 8.0, 0);

    // Draw simple character representations
    switch (char) {
      case 'O':
        drawCircle(engine, 0, 0, 3);
        break;
      case 'I':
      case 'l':
        drawLine(engine, 0, -5, 0, 5);
        break;
      default:
        // Generic character representation
        final charBuilder = PathBuilder()
          ..moveTo(-2, -5)
          ..lineTo(2, -5)
          ..lineTo(2, 5)
          ..lineTo(-2, 5)
          ..close();
        engine.stroke(charBuilder.build());
    }

    engine.restore();
  }

  engine.restore();
}

void drawCircle(GraphicsEngine engine, double cx, double cy, double radius) {
  final builder = PathBuilder();
  const segments = 16;

  for (int i = 0; i <= segments; i++) {
    final angle = (i / segments) * 2 * math.pi;
    final x = cx + radius * math.cos(angle);
    final y = cy + radius * math.sin(angle);

    if (i == 0) {
      builder.moveTo(x, y);
    } else {
      builder.lineTo(x, y);
    }
  }

  engine.stroke(builder.build());
}

void drawLine(
  GraphicsEngine engine,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final builder = PathBuilder()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2);
  engine.stroke(builder.build());
}
