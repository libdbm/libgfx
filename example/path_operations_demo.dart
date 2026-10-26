import 'dart:math' as math;

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

// A fixed seed makes every run draw the same image
final _random = math.Random(42);
TTFFont? _font;

Future<void> main() async {
  const filesystem = LocalGraphicsFileSystem();
  _font = await _loadDemoFont(filesystem);

  // Drawn at twice the size, for high-DPI screens; the drawing below is in

  // page units

  final engine = GraphicsEngine(2 * 1200, 2 * 800, filesystem: filesystem)
    ..scale(2, 2);

  // Set background
  engine.clear(const Color(0xFF1a1a1a));

  // Demo various path operations
  demonstratePathSimplification(engine);
  demonstratePathOffset(engine);
  demonstrateBooleanOperations(engine);

  await engine.write('output/path_operations_demo.ppm');
  print('Saved output/path_operations_demo.ppm');
}

Future<TTFFont?> _loadDemoFont(LocalGraphicsFileSystem filesystem) async {
  const candidates = [
    'data/fonts/Roboto-Regular.ttf',
    'data/fonts/NotoSans-Regular.ttf',
    'data/fonts/DejaVuSans.ttf',
  ];

  for (final path in candidates) {
    final result = await TTFFont.load(path, filesystem: filesystem);
    if (result case Ok(:final value)) {
      print('Loaded font for labels: $path');
      return value;
    }
    // Otherwise try the next candidate.
  }

  print('Could not load any demo font; labels will be skipped.');
  return null;
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
  engine.strokeStyle = const Color(0xFFFF4444);
  engine.lineWidth = 2;
  engine.stroke(complexPath);

  // Draw control points
  engine.fillStyle = const Color(0xFFFF4444);
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
  engine.strokeStyle = const Color(0xFF44FF44);
  engine.lineWidth = 3;
  engine.stroke(simplifiedStrict);

  engine.fillStyle = const Color(0xFF44FF44);
  for (final command in simplifiedStrict.commands) {
    if (command.type == PathCommandType.lineTo ||
        command.type == PathCommandType.moveTo) {
      drawPoint(engine, command.points[0], 3);
    }
  }

  engine.translate(0, 80);
  engine.strokeStyle = const Color(0xFF4444FF);
  engine.lineWidth = 4;
  engine.stroke(simplifiedLoose);

  engine.fillStyle = const Color(0xFF4444FF);
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
  starBuilder.closePath();
  final starPath = starBuilder.build();

  // Draw original star
  engine.fillStyle = const Color(0x40FFFF00);
  engine.strokeStyle = const Color(0xFFFFFF00);
  engine.lineWidth = 2;
  engine.fill(starPath);
  engine.stroke(starPath);

  // Draw outward and inward offsets of the star shape
  final outwardOffset = PathOperations.offset(starPath, 10);
  final inwardOffset = PathOperations.offset(starPath, -10);

  engine.strokeStyle = const Color(0xFF00FF00);
  engine.stroke(outwardOffset);

  engine.strokeStyle = const Color(0xFFFF00FF);
  engine.stroke(inwardOffset);

  // Labels
  drawLabel(engine, "Original + Offsets", -80, -40, const Color(0xFFFFFFFF));

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
    ..closePath();
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
  circle1Builder.closePath();
  final circle1 = circle1Builder.build();

  // Draw original shapes
  engine.fillStyle = const Color(0x60FF0000);
  engine.fill(rect1);
  engine.fillStyle = const Color(0x600000FF);
  engine.fill(circle1);

  engine.strokeStyle = const Color(0xFFFF0000);
  engine.lineWidth = 2;
  engine.stroke(rect1);
  engine.strokeStyle = const Color(0xFF0000FF);
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
    engine.fillStyle = const Color(0x8000FF00);
    engine.strokeStyle = const Color(0xFF00FF00);
    engine.lineWidth = 2;

    if (result.commands.isNotEmpty) {
      engine.fill(result);
      engine.stroke(result);
    }

    // Draw original shapes as outlines for context
    engine.strokeStyle = const Color(0x80FFFFFF);
    engine.lineWidth = 1;
    engine.stroke(rect1);
    engine.stroke(circle1);

    // Label
    drawLabel(engine, name, -20, -20, const Color(0xFFFFFFFF));

    engine.restore();
  }

  drawLabel(engine, "Boolean Operations", -50, -30, const Color(0xFFFFFFFF));

  engine.restore();
}

void drawLabel(
  GraphicsEngine engine,
  String text,
  double x,
  double y,
  Color color,
) {
  if (_font == null) return;
  engine.save();
  engine.translate(x, y);
  engine.fillStyle = color;
  final path = _font!.path(text, 0, 0, 12);
  engine.fill(path);
  engine.restore();
}

void drawPoint(GraphicsEngine engine, Point point, double radius) {
  engine.save();
  engine.translate(point.x, point.y);
  engine.fillStyle = const Color(0xFFFFFFFF);
  engine.fill(PathBuilder().circle(0, 0, radius).build());
  engine.restore();
}
