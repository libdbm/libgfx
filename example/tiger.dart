import 'dart:io';
import 'package:libgfx/libgfx.dart';

import 'package:libgfx/src/svg/svg_parser.dart';

void main() async {
  final engine = GraphicsEngine(900, 900);

  // White background
  engine.clear(Color.fromARGB(255, 255, 255, 255));

  // Load and parse SVG
  final svg = await File('data/tiger.svg').readAsString();
  final paths = parsePaths(svg);

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
    engine.setFillColor(pathData.color);
    engine.fill(pathData.path);
  }

  engine.restore();

  // Save the image
  final bytes = GraphicsEngine.saveImageToBytes(engine.canvas, 'p3');
  await File('output/tiger.ppm').writeAsBytes(bytes);
  print('Tiger from SVG saved to output/tiger.ppm');
}
