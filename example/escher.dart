import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';

/// Creates an Escher-like butterfly tesselation pattern
/// Based on escher.ps by Bob Wallis
void main() async {
  const width = 800;
  const height = 800;

  final engine = GraphicsEngine(width, height);

  // Light background
  engine.clear(const Color.fromARGB(255, 240, 240, 240));

  // Set up the transform
  engine.save();
  engine.translate(width / 2, height / 2);
  engine.scale(0.7, 0.7);

  // Draw multiple layers of butterflies
  const nlayers = 1; // Increase for more complexity
  final warp = true; // Apply ellipsoidal distortion

  // Hexagonal grid parameters
  const x4 = 152.0;
  const y4 = 205.6;
  const x12 = 387.20;
  const y12 = 403.84;

  final dx = x4 - x12;
  final dy = y4 - y12;
  final dm = math.sqrt(dx * dx + dy * dy) * math.sqrt(3);

  final da1 = math.atan2(dy, dx) + 30 * math.pi / 180;
  final d1x = dm * math.cos(da1);
  final d1y = dm * math.sin(da1);

  final da2 = math.atan2(dy, dx) - 30 * math.pi / 180;
  final d2x = dm * math.cos(da2);
  final d2y = dm * math.sin(da2);

  // Color cycling
  var colorIndex = 0;
  const nColors = 6;

  Color nextColor() {
    final hue = colorIndex / nColors;
    colorIndex = (colorIndex + 1) % nColors;
    return _hsbToRgb(hue, 0.75, 0.8);
  }

  // Draw butterflies in a hexagonal pattern
  for (int layer = 0; layer <= nlayers; layer++) {
    final range = 3 + layer * 2;

    for (int i = -range; i <= range; i++) {
      for (int j = -range; j <= range; j++) {
        // Skip if outside hexagonal boundary
        if ((i.abs() + j.abs()) > range * 1.5) continue;

        final x = i * d1x + j * d2x;
        final y = i * d1y + j * d2y;

        // Apply warping if enabled
        double wx = x;
        double wy = y;
        if (warp) {
          final r = math.sqrt(x * x + y * y);
          final maxR = 600.0;
          if (r < maxR) {
            final scale = 1.0 - (r / maxR) * (r / maxR);
            wx = x * scale;
            wy = y * scale;
          } else {
            continue; // Skip butterflies outside the circle
          }
        }

        engine.save();
        engine.translate(wx, wy);

        // Alternate rotation for tessellation
        if ((i + j) % 2 == 0) {
          engine.rotate(math.pi);
        }

        _drawButterfly(engine, nextColor);

        engine.restore();
      }
    }
  }

  engine.restore();

  await engine.saveToFile('output/escher.ppm');
  print('output/escher.ppm saved successfully!');
  print('An Escher-like butterfly tessellation has been rendered.');
}

void _drawButterfly(GraphicsEngine engine, Color Function() nextColor) {
  // Scale down the butterfly
  engine.save();
  engine.scale(0.3, 0.3);

  // Body
  final body = PathBuilder()
      .moveTo(314.96, 280.19)
      .curveTo(383.4, 261.71, 445.11, 243.23, 513.52, 224.68)
      .curveTo(463.68, 256.59, 490.26, 328.83, 446.99, 360.76)
      .curveTo(423.71, 347.32, 397.08, 339.7, 367.07, 337.9)
      .curveTo(388.93, 358.28, 414.14, 372.84, 442.73, 381.58)
      .curveTo(426.68, 398.18, 394.07, 389.7, 387.2, 403.84)
      .curveTo(371.52, 404.96, 362.56, 372.48, 340.16, 366.88)
      .curveTo(346.88, 396.01, 346.88, 425.12, 340.16, 454.24)
      .curveTo(326.72, 427.35, 320, 400.48, 320, 373.6)
      .curveTo(270.71, 352.1, 221.44, 411.23, 168.88, 384.02)
      .curveTo(189.04, 388.03, 202.48, 380.4, 212.57, 366.95)
      .curveTo(216.72, 350.85, 209.23, 341.46, 190.1, 338.79)
      .curveTo(177.34, 343.57, 167.94, 354.17, 161.9, 370.59)
      .curveTo(176.06, 305.52, 132.02, 274.05, 152, 205.6)
      .curveTo(201.29, 257.12, 250.56, 234.72, 299.84, 279.52)
      .curveTo(288.64, 266.08, 284.16, 252.64, 286.4, 239.2)
      .curveTo(298.27, 223.97, 310.15, 222.18, 322.02, 233.82)
      .curveTo(328.62, 249.28, 328.51, 264.74, 314.96, 280.19)
      .close()
      .build();

  // Draw body with random color
  engine.setFillColor(nextColor());
  engine.fill(body);
  engine.setStrokeColor(const Color.fromARGB(255, 0, 0, 0));
  engine.setLineWidth(1);
  engine.stroke(body);

  // Eyes
  _drawEyes(engine);

  // Wing spots
  _drawSpots(engine, nextColor);

  // Stripes
  _drawStripes(engine);

  // Nostrils
  _drawNostrils(engine);

  engine.restore();
}

void _drawEyes(GraphicsEngine engine) {
  // White of eyes
  engine.setFillColor(const Color.fromARGB(255, 255, 255, 255));

  final leftEyeWhite = PathBuilder()
      .moveTo(298.6132, 248.3125)
      .arc(294.8125, 248.3125, 4, 0, 2 * math.pi)
      .close()
      .build();
  engine.fill(leftEyeWhite);
  engine.setStrokeColor(const Color.fromARGB(255, 0, 0, 0));
  engine.setLineWidth(0.5);
  engine.stroke(leftEyeWhite);

  final rightEyeWhite = PathBuilder()
      .moveTo(323.5659, 250.8125)
      .arc(319.5, 250.8125, 4, 0, 2 * math.pi)
      .close()
      .build();
  engine.fill(rightEyeWhite);
  engine.stroke(rightEyeWhite);

  // Pupils
  engine.setFillColor(const Color.fromARGB(255, 0, 0, 0));

  final leftPupil = PathBuilder()
      .moveTo(297.9356, 245.1875)
      .arc(296.875, 245.1875, 1.5, 0, 2 * math.pi)
      .close()
      .build();
  engine.fill(leftPupil);

  final rightPupil = PathBuilder()
      .moveTo(319.9142, 246.6875)
      .arc(318.5, 246.6875, 1.5, 0, 2 * math.pi)
      .close()
      .build();
  engine.fill(rightPupil);
}

void _drawSpots(GraphicsEngine engine, Color Function() nextColor) {
  // Wing spots in various colors
  final spots = [
    [192.0, 262.0, 18.0],
    [447.5, 266.5, 22.0],
    [401.0, 379.0, 15.0],
    [249.0, 361.0, 22.0],
  ];

  for (final spot in spots) {
    engine.setFillColor(nextColor());
    final spotPath = PathBuilder()
        .moveTo(spot[0] + spot[2], spot[1])
        .arc(spot[0], spot[1], spot[2], 0, 2 * math.pi)
        .close()
        .build();
    engine.fill(spotPath);
    engine.setStrokeColor(const Color.fromARGB(255, 0, 0, 0));
    engine.setLineWidth(1);
    engine.stroke(spotPath);
  }
}

void _drawStripes(GraphicsEngine engine) {
  engine.setStrokeColor(const Color.fromARGB(255, 0, 0, 0));
  engine.setLineWidth(1.5);

  // Wing stripes
  final stripes = PathBuilder()
      .moveTo(292, 289)
      .curveTo(252, 294, 241, 295, 213, 279)
      .curveTo(185, 263, 175, 252, 159, 222)
      .moveTo(285, 313)
      .curveTo(239, 326, 226, 325, 206, 315)
      .curveTo(186, 305, 164, 278, 161, 267)
      .moveTo(298, 353)
      .curveTo(262, 342, 251, 339, 237, 355)
      .curveTo(223, 371, 213, 380, 201, 383)
      .moveTo(330, 288)
      .curveTo(384, 293, 385, 292, 418, 280)
      .curveTo(451, 268, 452, 264, 473, 247)
      .moveTo(342, 306)
      .curveTo(381, 311, 386, 317, 410, 311)
      .curveTo(434, 305, 460, 287, 474, 262)
      .moveTo(345, 321)
      .curveTo(352, 357, 359, 367, 379, 377)
      .curveTo(399, 387, 409, 385, 426, 382)
      .build();

  engine.stroke(stripes);
}

void _drawNostrils(GraphicsEngine engine) {
  engine.setFillColor(const Color.fromARGB(255, 0, 0, 0));

  final leftNostril = PathBuilder()
      .moveTo(305.034, 230.25)
      .arc(304.062, 230.25, 1, 0, 2 * math.pi)
      .close()
      .build();
  engine.fill(leftNostril);

  final rightNostril = PathBuilder()
      .moveTo(310.534, 230.75)
      .arc(309.562, 230.75, 1, 0, 2 * math.pi)
      .close()
      .build();
  engine.fill(rightNostril);
}

Color _hsbToRgb(double h, double s, double b) {
  final c = b * s;
  final x = c * (1 - ((h * 6) % 2 - 1).abs());
  final m = b - c;

  double r, g, blue;
  if (h < 1 / 6) {
    r = c;
    g = x;
    blue = 0;
  } else if (h < 2 / 6) {
    r = x;
    g = c;
    blue = 0;
  } else if (h < 3 / 6) {
    r = 0;
    g = c;
    blue = x;
  } else if (h < 4 / 6) {
    r = 0;
    g = x;
    blue = c;
  } else if (h < 5 / 6) {
    r = x;
    g = 0;
    blue = c;
  } else {
    r = c;
    g = 0;
    blue = x;
  }

  return Color.fromARGB(
    255,
    ((r + m) * 255).round(),
    ((g + m) * 255).round(),
    ((blue + m) * 255).round(),
  );
}
