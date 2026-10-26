import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 500, 2 * 500, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color.fromARGB(255, 29, 43, 83));

  // --- Test 1: A continuous curve with round joins and caps ---
  final continuousPath = PathBuilder()
      .moveTo(50, 400)
      .bezierCurveTo(150, 100, 350, 100, 450, 400)
      .build();

  engine.lineWidth = 40;
  engine.lineCap = LineCap.round;
  engine.lineJoin = LineJoin.round; // Round joins should now work
  engine.strokeStyle = const Color.fromARGB(255, 0, 228, 54); // Green
  engine.stroke(continuousPath);

  // --- Test 2: The dashed circle with round caps ---
  final circlePath = PathBuilder().circle(250, 250, 150).build();

  engine.strokeStyle = const Color.fromARGB(255, 255, 0, 77); // Red
  engine.setLineDash([60, 60]);
  engine.lineCap = LineCap.round;

  engine.stroke(circlePath);

  await engine.write('output/example.ppm');
  print('...output/example.ppm saved successfully!');
}
