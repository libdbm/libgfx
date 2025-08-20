import 'dart:math' as math;

import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/graphics_state.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';
import 'package:test/test.dart';

void main() {
  group('GraphicsState Save/Restore Tests', () {
    test('save creates a new state on the stack', () {
      final engine = GraphicsEngine(100, 100);

      engine.save();
      engine.save();
      engine.save();

      engine.restore();
      engine.restore();
      engine.restore();
    });

    test('restore preserves initial state when stack has only one state', () {
      final engine = GraphicsEngine(100, 100);

      engine.setFillColor(const Color(0xFFFF0000));
      engine.restore();

      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      final rect = builder.build();
      engine.fill(rect);

      final bitmap = engine.canvas;
      final pixel = bitmap.getPixel(15, bitmap.height - 1 - 15);
      expect(pixel.red, equals(255));
    });

    test('save/restore preserves transformation matrix', () {
      final engine = GraphicsEngine(100, 100);

      engine.save();
      engine.translate(20, 20);
      engine.rotate(math.pi / 4);
      engine.scale(2, 2);

      engine.save();
      engine.translate(10, 10);

      engine.restore();

      engine.restore();

      final builder = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();
      final rect = builder.build();
      engine.fill(rect);

      final bitmap = engine.canvas;
      final pixel = bitmap.getPixel(5, bitmap.height - 1 - 5);
      expect(pixel.alpha, isNot(0));
    });

    test('save/restore preserves fill color', () {
      final engine = GraphicsEngine(100, 100);

      engine.setFillColor(const Color(0xFFFF0000));
      engine.save();

      engine.setFillColor(const Color(0xFF00FF00));
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(40, 10)
        ..lineTo(60, 10)
        ..lineTo(60, 30)
        ..lineTo(40, 30)
        ..close();
      final rect2 = builder2.build();
      engine.fill(rect2);

      final bitmap = engine.canvas;
      final greenPixel = bitmap.getPixel(20, bitmap.height - 1 - 20);
      final redPixel = bitmap.getPixel(50, bitmap.height - 1 - 20);

      expect(greenPixel.green, equals(255));
      expect(greenPixel.red, equals(0));

      expect(redPixel.red, greaterThanOrEqualTo(254));
      expect(redPixel.green, equals(0));
    });

    test('save/restore preserves stroke color', () {
      final engine = GraphicsEngine(100, 100);

      engine.setStrokeColor(const Color(0xFFFF0000));
      engine.setLineWidth(3);
      engine.save();

      engine.setStrokeColor(const Color(0xFF0000FF));
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      final rect1 = builder1.build();
      engine.stroke(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(40, 10)
        ..lineTo(60, 10)
        ..lineTo(60, 30)
        ..lineTo(40, 30)
        ..close();
      final rect2 = builder2.build();
      engine.stroke(rect2);

      final bitmap = engine.canvas;
      final bluePixel = bitmap.getPixel(10, bitmap.height - 1 - 20);
      final redPixel = bitmap.getPixel(40, bitmap.height - 1 - 20);

      expect(bluePixel.blue, greaterThanOrEqualTo(254));
      expect(bluePixel.red, equals(0));

      expect(redPixel.red, greaterThanOrEqualTo(254));
      expect(redPixel.blue, equals(0));
    });

    test('save/restore preserves stroke width', () {
      final engine = GraphicsEngine(100, 100);

      engine.setLineWidth(5);
      engine.save();

      engine.setLineWidth(1);
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      final rect1 = builder1.build();
      engine.stroke(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(50, 10)
        ..lineTo(70, 10)
        ..lineTo(70, 30)
        ..lineTo(50, 30)
        ..close();
      final rect2 = builder2.build();
      engine.stroke(rect2);

      final bitmap = engine.canvas;

      final thinPixel1 = bitmap.getPixel(9, bitmap.height - 1 - 20);
      final thinPixel2 = bitmap.getPixel(8, bitmap.height - 1 - 20);
      expect(thinPixel1.alpha, isNot(0));
      expect(thinPixel2.alpha, equals(0));

      final thickPixel1 = bitmap.getPixel(49, bitmap.height - 1 - 20);
      final thickPixel2 = bitmap.getPixel(47, bitmap.height - 1 - 20);
      expect(thickPixel1.alpha, isNot(0));
      expect(thickPixel2.alpha, isNot(0));
    });

    test('save/restore preserves line cap style', () {
      final engine = GraphicsEngine(100, 100);

      engine.setLineCap(LineCap.round);
      engine.setLineWidth(10);
      engine.save();

      engine.setLineCap(LineCap.butt);
      final lineBuilder1 = PathBuilder()
        ..moveTo(20, 50)
        ..lineTo(40, 50);
      final line1 = lineBuilder1.build();
      engine.stroke(line1);

      engine.restore();

      final lineBuilder2 = PathBuilder()
        ..moveTo(60, 50)
        ..lineTo(80, 50);
      final line2 = lineBuilder2.build();
      engine.stroke(line2);

      final bitmap = engine.canvas;

      // Check pixels on the line itself, not past the end
      final buttLinePixel = bitmap.getPixel(30, bitmap.height - 1 - 50);
      final roundLinePixel = bitmap.getPixel(70, bitmap.height - 1 - 50);

      // Both lines should have been drawn
      expect(buttLinePixel.alpha, isNot(0));
      expect(roundLinePixel.alpha, isNot(0));

      // Check that round cap extends beyond the line end
      final roundCapPixel = bitmap.getPixel(82, bitmap.height - 1 - 50);
      final buttCapPixel = bitmap.getPixel(42, bitmap.height - 1 - 50);

      // Round cap should extend past x=80, butt cap should not extend past x=40
      expect(roundCapPixel.alpha, isNot(0)); // Round cap extends
      expect(buttCapPixel.alpha, equals(0)); // Butt cap doesn't extend
    });

    test('save/restore preserves line join style', () {
      final engine = GraphicsEngine(100, 100);

      engine.setLineJoin(LineJoin.round);
      engine.setLineWidth(10);
      engine.save();

      engine.setLineJoin(LineJoin.miter);
      final pathBuilder1 = PathBuilder()
        ..moveTo(10, 30)
        ..lineTo(20, 20)
        ..lineTo(30, 30);
      final path1 = pathBuilder1.build();
      engine.stroke(path1);

      engine.restore();

      final pathBuilder2 = PathBuilder()
        ..moveTo(50, 30)
        ..lineTo(60, 20)
        ..lineTo(70, 30);
      final path2 = pathBuilder2.build();
      engine.stroke(path2);
    });

    test('save/restore preserves dash pattern', () {
      final engine = GraphicsEngine(100, 100);

      engine.setLineDash([10, 5]);
      engine.setLineWidth(3);
      engine.save();

      engine.setLineDash([2, 2]);
      final lineBuilder1 = PathBuilder()
        ..moveTo(10, 30)
        ..lineTo(90, 30);
      final line1 = lineBuilder1.build();
      engine.stroke(line1);

      engine.restore();

      final lineBuilder2 = PathBuilder()
        ..moveTo(10, 60)
        ..lineTo(90, 60);
      final line2 = lineBuilder2.build();
      engine.stroke(line2);

      final bitmap = engine.canvas;

      final shortDash1 = bitmap.getPixel(10, bitmap.height - 1 - 30);
      final shortGap = bitmap.getPixel(12, bitmap.height - 1 - 30);
      final shortDash2 = bitmap.getPixel(14, bitmap.height - 1 - 30);

      expect(shortDash1.alpha, isNot(0));
      expect(shortGap.alpha, equals(0));
      expect(shortDash2.alpha, isNot(0));

      final longDash1 = bitmap.getPixel(10, bitmap.height - 1 - 60);
      final longDash2 = bitmap.getPixel(19, bitmap.height - 1 - 60);
      final longGap = bitmap.getPixel(20, bitmap.height - 1 - 60);

      expect(longDash1.alpha, isNot(0));
      expect(longDash2.alpha, isNot(0));
      expect(longGap.alpha, equals(0));
    });

    test('save/restore preserves gradient fill', () {
      final engine = GraphicsEngine(100, 100);

      engine.setFillPaint(
        LinearGradient(
          startPoint: Point(0, 0),
          endPoint: Point(100, 0),
          stops: [
            ColorStop(0.0, const Color(0xFFFF0000)),
            ColorStop(1.0, const Color(0xFF0000FF)),
          ],
        ),
      );
      engine.save();

      engine.setFillColor(const Color(0xFF00FF00));
      final builder1 = PathBuilder()
        ..moveTo(40, 40)
        ..lineTo(60, 40)
        ..lineTo(60, 60)
        ..lineTo(40, 60)
        ..close();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      final rect2 = builder2.build();
      engine.fill(rect2);

      final bitmap = engine.canvas;

      final greenPixel = bitmap.getPixel(50, bitmap.height - 1 - 50);
      expect(greenPixel.green, equals(255));

      final gradientPixel = bitmap.getPixel(20, bitmap.height - 1 - 20);
      expect(gradientPixel.red, greaterThan(0));
    });

    test('nested save/restore operations', () {
      final engine = GraphicsEngine(100, 100);

      engine.setFillColor(const Color(0xFFFF0000));
      engine.save();

      engine.setFillColor(const Color(0xFF00FF00));
      engine.translate(20, 0);
      engine.save();

      engine.setFillColor(const Color(0xFF0000FF));
      engine.translate(20, 0);
      engine.save();

      engine.setFillColor(const Color(0xFFFFFF00));
      engine.translate(20, 0);

      final builder1 = PathBuilder()
        ..moveTo(0, 10)
        ..lineTo(10, 10)
        ..lineTo(10, 20)
        ..lineTo(0, 20)
        ..close();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(0, 30)
        ..lineTo(10, 30)
        ..lineTo(10, 40)
        ..lineTo(0, 40)
        ..close();
      final rect2 = builder2.build();
      engine.fill(rect2);

      engine.restore();

      final builder3 = PathBuilder()
        ..moveTo(0, 50)
        ..lineTo(10, 50)
        ..lineTo(10, 60)
        ..lineTo(0, 60)
        ..close();
      final rect3 = builder3.build();
      engine.fill(rect3);

      engine.restore();

      final builder4 = PathBuilder()
        ..moveTo(0, 70)
        ..lineTo(10, 70)
        ..lineTo(10, 80)
        ..lineTo(0, 80)
        ..close();
      final rect4 = builder4.build();
      engine.fill(rect4);

      final bitmap = engine.canvas;

      final yellowPixel = bitmap.getPixel(65, bitmap.height - 1 - 15);
      expect(yellowPixel.red, equals(255));
      expect(yellowPixel.green, equals(255));

      final bluePixel = bitmap.getPixel(45, bitmap.height - 1 - 35);
      expect(bluePixel.blue, greaterThanOrEqualTo(254));

      final greenPixel = bitmap.getPixel(25, bitmap.height - 1 - 55);
      expect(greenPixel.green, equals(255));

      final redPixel = bitmap.getPixel(5, bitmap.height - 1 - 75);
      expect(redPixel.red, greaterThanOrEqualTo(254));
    });

    test('save/restore preserves clipping region', () {
      final engine = GraphicsEngine(100, 100);

      // First clip region: (10,10) to (60,60)
      final clipBuilder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(60, 10)
        ..lineTo(60, 60)
        ..lineTo(10, 60)
        ..close();
      final clipPath1 = clipBuilder1.build();
      engine.clip(clipPath1);
      engine.save();

      // Second clip region: (40,40) to (80,80)
      // This will intersect with first to create (40,40) to (60,60)
      final clipBuilder2 = PathBuilder()
        ..moveTo(40, 40)
        ..lineTo(80, 40)
        ..lineTo(80, 80)
        ..lineTo(40, 80)
        ..close();
      final clipPath2 = clipBuilder2.build();
      engine.clip(clipPath2);

      engine.setFillColor(const Color(0xFFFF0000));
      final builder1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 100)
        ..lineTo(0, 100)
        ..close();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      engine.setFillColor(const Color(0xFF00FF00));
      final builder2 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 100)
        ..lineTo(0, 100)
        ..close();
      final rect2 = builder2.build();
      engine.fill(rect2);

      final bitmap = engine.canvas;

      // After both fills, (50,50) should be green (was red, then overwritten by green)
      final clippedPixel = bitmap.getPixel(50, bitmap.height - 1 - 50);
      expect(clippedPixel.green, greaterThanOrEqualTo(254));
      expect(clippedPixel.red, equals(0));

      // Outside intersection should be empty
      final outsideIntersection = bitmap.getPixel(70, bitmap.height - 1 - 70);
      expect(outsideIntersection.alpha, equals(0));

      // Green should be visible in first clip region (10,10) to (60,60)
      final clippedGreen = bitmap.getPixel(35, bitmap.height - 1 - 35);
      expect(clippedGreen.green, greaterThanOrEqualTo(254));

      // Outside first clip should be empty
      final outsideFirst = bitmap.getPixel(70, bitmap.height - 1 - 35);
      expect(outsideFirst.alpha, equals(0));
    });

    test('save/restore with complex transformations', () {
      final engine = GraphicsEngine(100, 100);

      engine.translate(50, 50);
      engine.save();

      engine.rotate(math.pi / 4);
      engine.save();

      engine.scale(0.5, 0.5);
      engine.setFillColor(const Color(0xFFFF0000));
      final builder1 = PathBuilder()
        ..moveTo(-10, -10)
        ..lineTo(10, -10)
        ..lineTo(10, 10)
        ..lineTo(-10, 10)
        ..close();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      engine.setFillColor(const Color(0xFF00FF00));
      final builder2 = PathBuilder()
        ..moveTo(-5, -5)
        ..lineTo(5, -5)
        ..lineTo(5, 5)
        ..lineTo(-5, 5)
        ..close();
      final rect2 = builder2.build();
      engine.fill(rect2);

      engine.restore();

      engine.setFillColor(const Color(0xFF0000FF));
      final builder3 = PathBuilder()
        ..moveTo(-15, -15)
        ..lineTo(15, -15)
        ..lineTo(15, 15)
        ..lineTo(-15, 15)
        ..close();
      final rect3 = builder3.build();
      engine.fill(rect3);
    });

    test('save/restore preserves multiple style properties simultaneously', () {
      final engine = GraphicsEngine(100, 100);

      engine.setFillColor(const Color(0xFFFF0000));
      engine.setStrokeColor(const Color(0xFF00FF00));
      engine.setLineWidth(3);
      engine.setLineCap(LineCap.round);
      engine.setLineJoin(LineJoin.round);
      engine.setLineDash([5, 5]);
      engine.translate(10, 10);
      engine.rotate(math.pi / 6);

      engine.save();

      engine.setFillColor(const Color(0xFF0000FF));
      engine.setStrokeColor(const Color(0xFFFFFF00));
      engine.setLineWidth(1);
      engine.setLineCap(LineCap.butt);
      engine.setLineJoin(LineJoin.miter);
      engine.setLineDash([]);
      engine.translate(20, 20);
      engine.rotate(-math.pi / 3);

      final pathBuilder1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(20, 0)
        ..lineTo(20, 20)
        ..lineTo(0, 20)
        ..close();
      final path1 = pathBuilder1.build();
      engine.fill(path1);
      engine.stroke(path1);

      engine.restore();

      final pathBuilder2 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(15, 0)
        ..lineTo(15, 15)
        ..lineTo(0, 15)
        ..close();
      final path2 = pathBuilder2.build();
      engine.fill(path2);
      engine.stroke(path2);
    });

    test('GraphicsContext save/restore direct test', () {
      final bitmap = Bitmap(100, 100);
      final context = GraphicsContext(bitmap);

      context.state.fillPaint = SolidPaint(const Color(0xFFFF0000));
      context.state.strokeWidth = 5.0;
      context.state.transform.translate(10, 10);

      context.save();

      context.state.fillPaint = SolidPaint(const Color(0xFF00FF00));
      context.state.strokeWidth = 1.0;
      context.state.transform.scale(2, 2);

      context.save();

      context.state.fillPaint = SolidPaint(const Color(0xFF0000FF));

      context.restore();

      expect(
        (context.state.fillPaint as SolidPaint).color.value,
        equals(0xFF00FF00),
      );
      expect(context.state.strokeWidth, equals(1.0));

      context.restore();

      expect(
        (context.state.fillPaint as SolidPaint).color.value,
        equals(0xFFFF0000),
      );
      expect(context.state.strokeWidth, equals(5.0));
    });

    test('save without matching restore maintains state', () {
      final engine = GraphicsEngine(100, 100);

      engine.setFillColor(const Color(0xFFFF0000));
      engine.save();
      engine.setFillColor(const Color(0xFF00FF00));
      engine.save();
      engine.setFillColor(const Color(0xFF0000FF));

      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..close();
      final rect = builder.build();
      engine.fill(rect);

      final bitmap = engine.canvas;
      final pixel = bitmap.getPixel(20, bitmap.height - 1 - 20);
      expect(pixel.blue, equals(255));
    });

    test('restore at stack bottom preserves initial state', () {
      final bitmap = Bitmap(100, 100);
      final context = GraphicsContext(bitmap);

      final initialTransform = context.state.transform.clone();
      final initialFillPaint = context.state.fillPaint;

      context.restore();
      context.restore();
      context.restore();

      expect(context.state.transform == initialTransform, isTrue);
      expect(context.state.fillPaint, equals(initialFillPaint));
    });
  });
}
