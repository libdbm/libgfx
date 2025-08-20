import 'dart:math';

import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  final engine = GraphicsEngine(500, 500);
  engine.clear(const Color.fromARGB(255, 29, 43, 83));

  // --- 1. Define a clipping path (a 5-pointed star) ---
  final starPath = PathBuilder();
  final centerX = 250.0;
  final centerY = 250.0;
  final outerRadius = 220.0;
  final innerRadius = 100.0;

  for (int i = 0; i < 5; i++) {
    double outerAngle = i * (2 * pi / 5) - pi / 2;
    double innerAngle = outerAngle + pi / 5;

    final pOuter = Point(
      centerX + outerRadius * cos(outerAngle),
      centerY + outerRadius * sin(outerAngle),
    );
    final pInner = Point(
      centerX + innerRadius * cos(innerAngle),
      centerY + innerRadius * sin(innerAngle),
    );

    if (i == 0) {
      starPath.moveTo(pOuter.x, pOuter.y);
    } else {
      starPath.lineTo(pOuter.x, pOuter.y);
    }
    starPath.lineTo(pInner.x, pInner.y);
  }
  starPath.close();

  // --- 2. Apply the clipping path ---
  engine.clip(starPath.build());

  // --- 3. Draw the dashed circle like before ---
  final path = PathBuilder().circle(250, 250, 200).build();

  engine.setStrokePaint(
    LinearGradient(
      startPoint: Point(50, 50),
      endPoint: Point(450, 450),
      stops: [
        ColorStop(0.0, const Color.fromARGB(255, 0, 228, 54)),
        ColorStop(1.0, const Color.fromARGB(255, 255, 0, 77)),
      ],
    ),
  );
  engine.setLineWidth(25);
  engine.setLineDash([50, 15]);
  engine.setLineCap(LineCap.round);

  engine.stroke(path);

  // --- 4. Save the result ---
  await engine.saveToFile('output/clipping.ppm');
  print('...output/clipping.ppm saved successfully!');
}
