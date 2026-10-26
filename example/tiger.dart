import 'dart:io';
import 'package:libgfx/libgfx.dart';

void main() async {
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 900, 2 * 900)..scale(2, 2);

  // White background
  engine.clear(Color.fromARGB(255, 255, 255, 255));

  // Load and parse SVG
  final svg = await File('data/tiger.svg').readAsString();
  final paths = SVGPath.parse(svg);

  // Apply transform to fit the SVG viewBox (0, 0, 680, 688) into 900x900 canvas
  engine.save();

  // Center and scale to fit
  final scaleX = 900.0 / 680.0;
  final scaleY = 900.0 / 688.0;
  final scale = (scaleX < scaleY) ? scaleX : scaleY;

  engine.translate(450, 450); // Center of canvas
  engine.scale(scale, -scale); // Negative scale on Y to flip vertically
  engine.translate(-340, -344); // Center of SVG viewBox

  // Draw all paths
  for (final pathData in paths) {
    engine.fillStyle = pathData.color;
    engine.fill(pathData.path);
  }

  engine.restore();

  // Save the image
  final bytes = GraphicsEngine.encode(engine.canvas, 'p3');
  await File('output/tiger.ppm').writeAsBytes(bytes);
  print('Tiger from SVG saved to output/tiger.ppm');
}
