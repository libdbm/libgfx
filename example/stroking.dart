import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  final engine = GraphicsEngine(500, 500);
  engine.clear(const Color.fromARGB(255, 255, 255, 255)); // White background

  // A simple open path with a curve
  final path = PathBuilder()
      .moveTo(50, 400)
      .curveTo(150, 100, 350, 100, 450, 400)
      .build();

  // Set a thick stroke with round caps
  engine.setLineWidth(40);
  engine.setLineCap(LineCap.round);
  engine.setStrokeColor(const Color.fromARGB(255, 155, 89, 182)); // Purple

  // Stroke the path WITHOUT a dash pattern
  engine.stroke(path);

  await engine.saveToFile('output/stroking.ppm');
  print('...output/stroking.ppm saved successfully!');
}
