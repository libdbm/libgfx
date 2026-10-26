import 'package:libgfx/io/local_file_system.dart';
import 'package:libgfx/libgfx.dart';

/// Test square caps are rendered correctly at both ends
Future<void> main() async {
  const filesystem = LocalGraphicsFileSystem();
  // Drawn at twice the size, for high-DPI screens; the drawing below is in
  // page units
  final engine = GraphicsEngine(2 * 400, 2 * 200, filesystem: filesystem)
    ..scale(2, 2);
  engine.clear(const Color(0xFFFFFFFF));

  // Draw a thick horizontal line with square caps
  engine.lineWidth = 40;
  engine.strokeStyle = const Color(0xFF008000);
  engine.lineCap = LineCap.square;

  final path = PathBuilder()
    ..moveTo(100, 100)
    ..lineTo(300, 100);

  engine.stroke(path.build());

  // Draw thin reference lines at the actual endpoints
  engine.lineWidth = 1;
  engine.strokeStyle = const Color(0xFFFF0000);
  engine.lineCap = LineCap.butt;

  // Vertical lines at endpoints
  final line1 = PathBuilder()
    ..moveTo(100, 50)
    ..lineTo(100, 150);
  engine.stroke(line1.build());

  final line2 = PathBuilder()
    ..moveTo(300, 50)
    ..lineTo(300, 150);
  engine.stroke(line2.build());

  // Draw lines showing the expected square cap extension (halfWidth = 20)
  engine.strokeStyle = const Color(0xFF0000FF);
  final ext1 = PathBuilder()
    ..moveTo(80, 50)
    ..lineTo(80, 150);
  engine.stroke(ext1.build());

  final ext2 = PathBuilder()
    ..moveTo(320, 50)
    ..lineTo(320, 150);
  engine.stroke(ext2.build());

  await engine.write('output/square_cap_demo.ppm');
  print('Square cap test saved to output/square_cap_demo.ppm');
  print('The green line should have square caps extending to the blue lines');
}
