import 'dart:math';

import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 500, 2 * 500, filesystem: filesystem)
    ..scale(2, 2);
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
  starPath.closePath();

  // --- 2. Apply the clipping path ---
  engine.clip(starPath.build());

  // --- 3. Draw the dashed circle like before ---
  final path = PathBuilder().circle(250, 250, 200).build();

  engine.strokeStyle = LinearGradient(
    start: Point(50, 50),
    end: Point(450, 450),
    stops: [
      ColorStop(0.0, const Color.fromARGB(255, 0, 228, 54)),
      ColorStop(1.0, const Color.fromARGB(255, 255, 0, 77)),
    ],
  );
  engine.lineWidth = 25;
  engine.setLineDash([50, 15]);
  engine.lineCap = LineCap.round;

  engine.stroke(path);

  // --- 4. Save the result ---
  await engine.write('output/clipping.ppm');
  print('...output/clipping.ppm saved successfully!');
}
