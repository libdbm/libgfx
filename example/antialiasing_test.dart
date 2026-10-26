import 'dart:io';
import 'dart:math' as math;
import 'package:libgfx/libgfx.dart';

void main() async {
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 400, 2 * 400)..scale(2, 2);

  // White background
  engine.clear(Color.fromARGB(255, 255, 255, 255));

  // Black fill
  engine.fillStyle = Color.fromARGB(255, 0, 0, 0);

  // Draw diagonal lines at various angles, each a bar 2 pixels wide: its
  // far side is offset at right angles to its direction
  for (int i = 0; i < 8; i++) {
    final angle = i * math.pi / 8;
    final centerX = 50.0 + i * 45.0;
    final centerY = 100.0;
    final length = 20.0; // half the length, so bars 45 apart do not touch
    final dx = -2 * math.sin(angle);
    final dy = 2 * math.cos(angle);

    final path = PathBuilder()
      ..moveTo(
        centerX - length * math.cos(angle),
        centerY - length * math.sin(angle),
      )
      ..lineTo(
        centerX + length * math.cos(angle),
        centerY + length * math.sin(angle),
      )
      ..lineTo(
        centerX + length * math.cos(angle) + dx,
        centerY + length * math.sin(angle) + dy,
      )
      ..lineTo(
        centerX - length * math.cos(angle) + dx,
        centerY - length * math.sin(angle) + dy,
      )
      ..closePath();

    engine.fill(path.build());
  }

  // Draw circles of various sizes
  for (int i = 0; i < 5; i++) {
    final radius = 10.0 + i * 5.0;
    final centerX = 50.0 + i * 70.0;
    final centerY = 250.0;

    final path = PathBuilder();
    // Create circle using cubic bezier approximation
    final kappa = 0.5522847498;
    path.moveTo(centerX + radius, centerY);
    path.bezierCurveTo(
      centerX + radius,
      centerY + radius * kappa,
      centerX + radius * kappa,
      centerY + radius,
      centerX,
      centerY + radius,
    );
    path.bezierCurveTo(
      centerX - radius * kappa,
      centerY + radius,
      centerX - radius,
      centerY + radius * kappa,
      centerX - radius,
      centerY,
    );
    path.bezierCurveTo(
      centerX - radius,
      centerY - radius * kappa,
      centerX - radius * kappa,
      centerY - radius,
      centerX,
      centerY - radius,
    );
    path.bezierCurveTo(
      centerX + radius * kappa,
      centerY - radius,
      centerX + radius,
      centerY - radius * kappa,
      centerX + radius,
      centerY,
    );
    path.closePath();

    engine.fill(path.build());
  }

  // Save the image
  final bytes = GraphicsEngine.encode(engine.canvas, 'p3');
  final file = await File(
    'output/antialiasing_test.ppm',
  ).create(recursive: true);
  await file.writeAsBytes(bytes);
  print('Anti-aliasing test saved to output/antialiasing_test.ppm');
}
