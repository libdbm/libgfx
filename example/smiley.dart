import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

void main() async {
  const width = 150;
  const height = 150;

  const centerX = width / 2.0;
  const centerY = height / 2.0;
  const faceRadius = 70.0;
  const mouthRadius = 50.0;
  const eyeRadius = 10.0;
  const eyeOffsetX = 25.0;
  const eyeOffsetY = 20.0;
  const eyeX = centerX - eyeOffsetX;
  const eyeY = centerY - eyeOffsetY;

  final engine = GraphicsEngine(width, height);

  // Clear background to white
  engine.clear(const Color.fromARGB(255, 255, 255, 255));

  // Apply vertical flip to correct coordinate system
  engine.save();
  engine.translate(0, height.toDouble());
  engine.scale(1, -1);

  // Draw face (yellow fill with black stroke)
  engine.save();

  // Create face path
  final face = PathBuilder()
      .moveTo(centerX + faceRadius, centerY)
      .arc(centerX, centerY, faceRadius, 0, 2 * math.pi)
      .close()
      .build();

  // Fill with yellow
  engine.setFillColor(const Color.fromARGB(255, 255, 255, 0)); // Yellow
  engine.fill(face);

  // Stroke with black
  engine.setStrokeColor(const Color.fromARGB(255, 0, 0, 0)); // Black
  engine.setLineWidth(5);
  engine.stroke(face);

  engine.restore();

  // Draw eyes (black filled circles)
  engine.save();

  // Left eye
  final leftEye = PathBuilder()
      .moveTo(eyeX + eyeRadius, eyeY)
      .arc(eyeX, eyeY, eyeRadius, 0, 2 * math.pi)
      .close()
      .build();

  // Right eye
  final rightEye = PathBuilder()
      .moveTo(centerX + eyeOffsetX + eyeRadius, eyeY)
      .arc(centerX + eyeOffsetX, eyeY, eyeRadius, 0, 2 * math.pi)
      .close()
      .build();

  engine.setFillColor(const Color.fromARGB(255, 0, 0, 0)); // Black
  engine.fill(leftEye);
  engine.fill(rightEye);

  engine.restore();

  // Draw mouth (black stroked arc)
  engine.save();

  final mouth = PathBuilder()
      .moveTo(centerX + mouthRadius, centerY)
      .arc(centerX, centerY, mouthRadius, 0, math.pi)
      .build();

  engine.setStrokeColor(const Color.fromARGB(255, 0, 0, 0)); // Black
  engine.setLineWidth(5);
  engine.stroke(mouth);

  engine.restore();

  // Restore original transform
  engine.restore();

  // Save to file
  await engine.saveToFile('output/smiley.ppm');
  print('output/smiley.ppm saved successfully!');
}
