import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

/// Creates a waterfall pattern demonstration
/// Inspired by waterfal.ps - shows geometric shapes at different sizes
/// (Original shows fonts, but libgfx doesn't have text rendering)
Future<void> main() async {
  const width = 600;
  const height = 800;

  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * width, 2 * height, filesystem: filesystem)
    ..scale(2, 2);

  // White background
  engine.clear(const Color.fromARGB(255, 255, 255, 255));

  // Sizes to demonstrate (like font sizes in original)
  final sizes = [6, 7, 8, 9, 10, 11, 12, 14, 16, 20, 24];

  // Different shapes to demonstrate instead of fonts
  final shapes = ['circle', 'square', 'triangle'];

  // Apply coordinate system
  engine.save();
  engine.translate(50, 50);
  engine.scale(1, 1);

  var yOffset = 0.0;

  for (final shape in shapes) {
    // Title for this shape type
    engine.save();
    engine.translate(0, yOffset);

    // Draw a line to separate sections
    engine.strokeStyle = const Color.fromARGB(255, 200, 200, 200);
    engine.lineWidth = 1;
    final line = PathBuilder().moveTo(0, -5).lineTo(width - 100, -5).build();
    engine.stroke(line);

    engine.restore();

    yOffset += 20;

    // Draw shapes at different sizes
    for (final size in sizes) {
      engine.save();
      engine.translate(0, yOffset);

      // Draw size indicator (small square)
      engine.fillStyle = const Color.fromARGB(255, 100, 100, 100);
      final indicator = PathBuilder()
          .moveTo(0, 0)
          .lineTo(3, 0)
          .lineTo(3, 3)
          .lineTo(0, 3)
          .closePath()
          .build();
      engine.fill(indicator);

      // Draw the shapes
      var xOffset = 50.0;

      // Draw multiple instances of the shape
      for (int i = 0; i < 10; i++) {
        engine.save();
        engine.translate(xOffset, 0);

        _drawShape(engine, shape, size.toDouble(), i);

        engine.restore();
        xOffset += size * 2.5;

        if (xOffset > width - 100) break;
      }

      engine.restore();
      yOffset += size * 2.5;

      if (yOffset > height - 150) break;
    }

    yOffset += 40; // Extra space between shape types
    if (yOffset > height - 100) break;
  }

  engine.restore();

  await engine.write('output/waterfall.ppm');
  print('output/waterfall.ppm saved successfully!');
  print('A waterfall pattern demonstration has been rendered.');
}

void _drawShape(GraphicsEngine engine, String shape, double size, int index) {
  // Vary the color based on index
  final hue = (index * 36) % 360;
  final color = HSLColor(hue.toDouble(), 0.7, 0.5).color;

  engine.fillStyle = color;

  Path path;
  switch (shape) {
    case 'circle':
      path = PathBuilder()
          .moveTo(size, 0)
          .arc(0, 0, size, 0, 2 * 3.14159)
          .closePath()
          .build();
      break;

    case 'square':
      path = PathBuilder()
          .moveTo(-size, -size)
          .lineTo(size, -size)
          .lineTo(size, size)
          .lineTo(-size, size)
          .closePath()
          .build();
      break;

    case 'triangle':
      path = PathBuilder()
          .moveTo(0, size)
          .lineTo(-size * 0.866, -size * 0.5)
          .lineTo(size * 0.866, -size * 0.5)
          .closePath()
          .build();
      break;

    default:
      return;
  }

  engine.fill(path);

  // Add a subtle outline
  engine.strokeStyle = const Color.fromARGB(255, 50, 50, 50);
  engine.lineWidth = 0.5;
  engine.stroke(path);
}
