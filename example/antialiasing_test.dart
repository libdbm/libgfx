import 'dart:io';
import 'dart:math' as math;
import 'package:libgfx/libgfx.dart';

void main() async {
  final engine = GraphicsEngine(400, 400);

  // White background
  engine.clear(Color.fromARGB(255, 255, 255, 255));

  // Black fill
  engine.setFillColor(Color.fromARGB(255, 0, 0, 0));

  // Draw diagonal lines at various angles
  for (int i = 0; i < 8; i++) {
    final angle = i * math.pi / 8;
    final centerX = 50.0 + i * 45.0;
    final centerY = 100.0;
    final length = 40.0;

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
        centerX + length * math.cos(angle) + 2,
        centerY + length * math.sin(angle) + 2,
      )
      ..lineTo(
        centerX - length * math.cos(angle) + 2,
        centerY - length * math.sin(angle) + 2,
      )
      ..close();

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
    path.curveTo(
      centerX + radius,
      centerY + radius * kappa,
      centerX + radius * kappa,
      centerY + radius,
      centerX,
      centerY + radius,
    );
    path.curveTo(
      centerX - radius * kappa,
      centerY + radius,
      centerX - radius,
      centerY + radius * kappa,
      centerX - radius,
      centerY,
    );
    path.curveTo(
      centerX - radius,
      centerY - radius * kappa,
      centerX - radius * kappa,
      centerY - radius,
      centerX,
      centerY - radius,
    );
    path.curveTo(
      centerX + radius * kappa,
      centerY - radius,
      centerX + radius,
      centerY - radius * kappa,
      centerX + radius,
      centerY,
    );
    path.close();

    engine.fill(path.build());
  }

  // Save the image
  final bytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'p3');
  await File('output/antialiasing_test.ppm').writeAsBytes(bytes);
  print('Anti-aliasing test saved to output/antialiasing_test.ppm');
}
