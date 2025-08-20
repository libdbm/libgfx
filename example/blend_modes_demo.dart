import 'dart:math' as math;

import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/graphics_state.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';

void main() async {
  final engine = GraphicsEngine(1200, 800);

  // Set background
  engine.clear(const Color(0xFF1a1a1a));

  // Draw blend mode grid
  drawBlendModeGrid(engine);

  await engine.saveToFile('output/blend_modes_demo.ppm');
  print('Saved output/blend_modes_demo.ppm');
}

void drawBlendModeGrid(GraphicsEngine engine) {
  // Define blend modes to demonstrate
  final blendModes = [
    // Porter-Duff modes
    BlendMode.clear,
    BlendMode.src,
    BlendMode.dst,
    BlendMode.srcOver,
    BlendMode.dstOver,
    BlendMode.srcIn,
    BlendMode.dstIn,
    BlendMode.srcOut,
    BlendMode.dstOut,
    BlendMode.srcAtop,
    BlendMode.dstAtop,
    BlendMode.xor,

    // Additional blend modes
    BlendMode.add,
    BlendMode.multiply,
    BlendMode.screen,
    BlendMode.overlay,
    BlendMode.darken,
    BlendMode.lighten,
    BlendMode.colorDodge,
    BlendMode.colorBurn,
    BlendMode.hardLight,
    BlendMode.softLight,
    BlendMode.difference,
    BlendMode.exclusion,
  ];

  const cellSize = 120.0;
  const padding = 20.0;
  const cols = 6;

  for (int i = 0; i < blendModes.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final x = padding + col * (cellSize + padding);
    final y = padding + row * (cellSize + padding);

    drawBlendModeCell(engine, x, y, cellSize, blendModes[i]);
  }
}

void drawBlendModeCell(
  GraphicsEngine engine,
  double x,
  double y,
  double size,
  BlendMode mode,
) {
  engine.save();

  // Create clipping region for this cell
  final cellRect = createRect(x, y, size, size);
  engine.clip(cellRect);

  // Draw background pattern
  drawBackgroundPattern(engine, x, y, size);

  // Draw destination shape (blue circle with gradient)
  engine.save();
  engine.setFillPaint(
    RadialGradient(
      center: Point(x + size * 0.4, y + size * 0.6),
      radius: size * 0.35,
      stops: [
        ColorStop(0.0, const Color(0xFF0080FF)),
        ColorStop(0.7, const Color(0xFF0040AA)),
        ColorStop(1.0, const Color(0xFF002055)),
      ],
    ),
  );
  final destCircle = createCircle(x + size * 0.4, y + size * 0.6, size * 0.35);
  engine.fill(destCircle);
  engine.restore();

  // Draw source shape (red/yellow gradient square) with blend mode
  engine.save();
  engine.setGlobalCompositeOperation(mode);
  engine.setFillPaint(
    LinearGradient(
      startPoint: Point(x + size * 0.3, y + size * 0.2),
      endPoint: Point(x + size * 0.8, y + size * 0.7),
      stops: [
        ColorStop(0.0, const Color(0xFFFF8800)),
        ColorStop(0.5, const Color(0xFFFFFF00)),
        ColorStop(1.0, const Color(0xFFFF0000)),
      ],
    ),
  );
  final srcRect = createRect(
    x + size * 0.3,
    y + size * 0.2,
    size * 0.5,
    size * 0.5,
  );
  engine.fill(srcRect);
  engine.restore();

  // Draw border
  engine.setStrokeColor(const Color(0xFF444444));
  engine.setLineWidth(1);
  engine.stroke(cellRect);

  // Draw mode name label background
  engine.setFillColor(const Color(0xCC000000));
  final labelBg = createRect(x, y + size - 20, size, 20);
  engine.fill(labelBg);

  engine.restore();
}

void drawBackgroundPattern(
  GraphicsEngine engine,
  double x,
  double y,
  double size,
) {
  // Draw a subtle checkerboard pattern
  const checkSize = 10.0;
  final checks = (size / checkSize).ceil();

  engine.save();
  for (int row = 0; row < checks; row++) {
    for (int col = 0; col < checks; col++) {
      if ((row + col) % 2 == 0) {
        engine.setFillColor(const Color(0xFF2a2a2a));
      } else {
        engine.setFillColor(const Color(0xFF252525));
      }

      final checkX = x + col * checkSize;
      final checkY = y + row * checkSize;
      final check = createRect(checkX, checkY, checkSize, checkSize);
      engine.fill(check);
    }
  }
  engine.restore();
}

Path createRect(double x, double y, double width, double height) {
  final builder = PathBuilder()
    ..moveTo(x, y)
    ..lineTo(x + width, y)
    ..lineTo(x + width, y + height)
    ..lineTo(x, y + height)
    ..close();
  return builder.build();
}

Path createCircle(double cx, double cy, double radius) {
  final builder = PathBuilder();
  const segments = 64;

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

  return builder.build();
}
