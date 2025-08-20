import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/color/color_utils.dart';

/// Creates a waterfall pattern demonstration
/// Inspired by waterfal.ps - shows geometric shapes at different sizes
/// (Original shows fonts, but libgfx doesn't have text rendering)
void main() async {
  const width = 600;
  const height = 800;

  final engine = GraphicsEngine(width, height);

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
    engine.setStrokeColor(const Color.fromARGB(255, 200, 200, 200));
    engine.setLineWidth(1);
    final line = PathBuilder().moveTo(0, -5).lineTo(width - 100, -5).build();
    engine.stroke(line);

    engine.restore();

    yOffset += 20;

    // Draw shapes at different sizes
    for (final size in sizes) {
      engine.save();
      engine.translate(0, yOffset);

      // Draw size indicator (small square)
      engine.setFillColor(const Color.fromARGB(255, 100, 100, 100));
      final indicator = PathBuilder()
          .moveTo(0, 0)
          .lineTo(3, 0)
          .lineTo(3, 3)
          .lineTo(0, 3)
          .close()
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

  await engine.saveToFile('output/waterfall.ppm');
  print('output/waterfall.ppm saved successfully!');
  print('A waterfall pattern demonstration has been rendered.');
}

void _drawShape(GraphicsEngine engine, String shape, double size, int index) {
  // Vary the color based on index
  final hue = (index * 36) % 360;
  final color = ColorUtils.hslToRgb(HSLColor(hue.toDouble(), 0.7, 0.5));

  engine.setFillColor(color);

  Path path;
  switch (shape) {
    case 'circle':
      path = PathBuilder()
          .moveTo(size, 0)
          .arc(0, 0, size, 0, 2 * 3.14159)
          .close()
          .build();
      break;

    case 'square':
      path = PathBuilder()
          .moveTo(-size, -size)
          .lineTo(size, -size)
          .lineTo(size, size)
          .lineTo(-size, size)
          .close()
          .build();
      break;

    case 'triangle':
      path = PathBuilder()
          .moveTo(0, size)
          .lineTo(-size * 0.866, -size * 0.5)
          .lineTo(size * 0.866, -size * 0.5)
          .close()
          .build();
      break;

    default:
      return;
  }

  engine.fill(path);

  // Add a subtle outline
  engine.setStrokeColor(const Color.fromARGB(255, 50, 50, 50));
  engine.setLineWidth(0.5);
  engine.stroke(path);
}

// Removed duplicate _hslToRgb function - now using ColorUtils.hslToRgb()
