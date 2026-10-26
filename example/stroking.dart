import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 500, 2 * 500, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color.fromARGB(255, 255, 255, 255)); // White background

  // A simple open path with a curve
  final path = PathBuilder()
      .moveTo(50, 400)
      .bezierCurveTo(150, 100, 350, 100, 450, 400)
      .build();

  // Set a thick stroke with round caps
  engine.lineWidth = 40;
  engine.lineCap = LineCap.round;
  engine.strokeStyle = const Color.fromARGB(255, 155, 89, 182); // Purple

  // Stroke the path WITHOUT a dash pattern
  engine.stroke(path);

  await engine.write('output/stroking.ppm');
  print('...output/stroking.ppm saved successfully!');
}
