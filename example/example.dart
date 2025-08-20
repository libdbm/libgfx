import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  final engine = GraphicsEngine(500, 500);
  engine.clear(const Color.fromARGB(255, 29, 43, 83));

  // --- Test 1: A continuous curve with round joins and caps ---
  final continuousPath = PathBuilder()
      .moveTo(50, 400)
      .curveTo(150, 100, 350, 100, 450, 400)
      .build();

  engine.setLineWidth(40);
  engine.setLineCap(LineCap.round);
  engine.setLineJoin(LineJoin.round); // Round joins should now work
  engine.setStrokeColor(const Color.fromARGB(255, 0, 228, 54)); // Green
  engine.stroke(continuousPath);

  // --- Test 2: The dashed circle with round caps ---
  final circlePath = PathBuilder().circle(250, 250, 150).build();

  engine.setStrokeColor(const Color.fromARGB(255, 255, 0, 77)); // Red
  engine.setLineDash([60, 60]);
  engine.setLineCap(LineCap.round);

  engine.stroke(circlePath);

  await engine.saveToFile('output/example.ppm');
  print('...output/example.ppm saved successfully!');
}
