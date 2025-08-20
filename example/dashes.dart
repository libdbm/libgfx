import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  final engine = GraphicsEngine(500, 500);
  engine.clear(const Color.fromARGB(100, 100, 100, 100));

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
  engine.setLineDash([50, 55]);
  engine.setLineCap(LineCap.round);

  engine.stroke(path);

  engine.save();
  engine.translate(250, 250);
  engine.rotate(0.785);
  engine.scale(0.5);
  engine.setFillColor(const Color.fromARGB(170, 255, 255, 255));
  engine.setGlobalCompositeOperation(BlendMode.screen);

  engine.fill(PathBuilder().circle(0, 0, 150).build());

  engine.restore();

  await engine.saveToFile('output/dashes.ppm');
  print('...output/dashes.ppm saved successfully!');
}
