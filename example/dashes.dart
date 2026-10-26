import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

Future<void> main() async {
  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 500, 2 * 500, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color.fromARGB(100, 100, 100, 100));

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
  engine.setLineDash([50, 55]);
  engine.lineCap = LineCap.round;

  engine.stroke(path);

  engine.save();
  engine.translate(250, 250);
  engine.rotate(0.785);
  engine.scale(0.5);
  engine.fillStyle = const Color.fromARGB(170, 255, 255, 255);
  engine.globalCompositeOperation = BlendMode.screen;

  engine.fill(PathBuilder().circle(0, 0, 150).build());

  engine.restore();

  await engine.write('output/dashes.ppm');
  print('...output/dashes.ppm saved successfully!');
}
