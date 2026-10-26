import 'dart:io';
import 'dart:math' as math;

import 'package:libgfx/src/image/bitmap.dart';
import 'package:libgfx/src/color/color.dart';
import 'package:libgfx/src/graphics_context.dart';
import 'package:libgfx/src/graphics_engine_facade.dart';
import 'package:libgfx/src/graphics_state.dart';
import 'package:libgfx/src/matrix.dart';
import 'package:libgfx/src/paint.dart';
import 'package:libgfx/src/paths/path.dart';
import 'package:libgfx/src/point.dart';
import 'package:libgfx/src/result.dart';
import 'package:libgfx/src/text/text_types.dart';
import 'package:test/test.dart';

import 'support/results.dart';

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

      engine.fillStyle = const Color(0xFFFF0000);
      engine.restore();

      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..closePath();
      final rect = builder.build();
      engine.fill(rect);

      final bitmap = engine.canvas;
      final pixel = bitmap.pixel(15, bitmap.height - 1 - 15);
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
        ..closePath();
      final rect = builder.build();
      engine.fill(rect);

      final bitmap = engine.canvas;
      final pixel = bitmap.pixel(5, bitmap.height - 1 - 5);
      expect(pixel.alpha, isNot(0));
    });

    test('save/restore preserves fill color', () {
      final engine = GraphicsEngine(100, 100);

      engine.fillStyle = const Color(0xFFFF0000);
      engine.save();

      engine.fillStyle = const Color(0xFF00FF00);
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..closePath();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(40, 10)
        ..lineTo(60, 10)
        ..lineTo(60, 30)
        ..lineTo(40, 30)
        ..closePath();
      final rect2 = builder2.build();
      engine.fill(rect2);

      final bitmap = engine.canvas;
      final greenPixel = bitmap.pixel(20, bitmap.height - 1 - 20);
      final redPixel = bitmap.pixel(50, bitmap.height - 1 - 20);

      expect(greenPixel.green, equals(255));
      expect(greenPixel.red, equals(0));

      expect(redPixel.red, greaterThanOrEqualTo(254));
      expect(redPixel.green, equals(0));
    });

    test('save/restore preserves stroke color', () {
      final engine = GraphicsEngine(100, 100);

      engine.strokeStyle = const Color(0xFFFF0000);
      engine.lineWidth = 3;
      engine.save();

      engine.strokeStyle = const Color(0xFF0000FF);
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..closePath();
      final rect1 = builder1.build();
      engine.stroke(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(40, 10)
        ..lineTo(60, 10)
        ..lineTo(60, 30)
        ..lineTo(40, 30)
        ..closePath();
      final rect2 = builder2.build();
      engine.stroke(rect2);

      final bitmap = engine.canvas;
      final bluePixel = bitmap.pixel(10, bitmap.height - 1 - 20);
      final redPixel = bitmap.pixel(40, bitmap.height - 1 - 20);

      expect(bluePixel.blue, greaterThanOrEqualTo(254));
      expect(bluePixel.red, equals(0));

      expect(redPixel.red, greaterThanOrEqualTo(254));
      expect(redPixel.blue, equals(0));
    });

    test('save/restore preserves stroke width', () {
      final engine = GraphicsEngine(100, 100);

      engine.lineWidth = 5;
      engine.save();

      engine.lineWidth = 1;
      final builder1 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..closePath();
      final rect1 = builder1.build();
      engine.stroke(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(50, 10)
        ..lineTo(70, 10)
        ..lineTo(70, 30)
        ..lineTo(50, 30)
        ..closePath();
      final rect2 = builder2.build();
      engine.stroke(rect2);

      final bitmap = engine.canvas;

      final thinPixel1 = bitmap.pixel(9, bitmap.height - 1 - 20);
      final thinPixel2 = bitmap.pixel(8, bitmap.height - 1 - 20);
      expect(thinPixel1.alpha, isNot(0));
      expect(thinPixel2.alpha, equals(0));

      final thickPixel1 = bitmap.pixel(49, bitmap.height - 1 - 20);
      final thickPixel2 = bitmap.pixel(47, bitmap.height - 1 - 20);
      expect(thickPixel1.alpha, isNot(0));
      expect(thickPixel2.alpha, isNot(0));
    });

    test('save/restore preserves line cap style', () {
      final engine = GraphicsEngine(100, 100);

      engine.lineCap = LineCap.round;
      engine.lineWidth = 10;
      engine.save();

      engine.lineCap = LineCap.butt;
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
      final buttLinePixel = bitmap.pixel(30, bitmap.height - 1 - 50);
      final roundLinePixel = bitmap.pixel(70, bitmap.height - 1 - 50);

      // Both lines should have been drawn
      expect(buttLinePixel.alpha, isNot(0));
      expect(roundLinePixel.alpha, isNot(0));

      // Check that round cap extends beyond the line end
      final roundCapPixel = bitmap.pixel(82, bitmap.height - 1 - 50);
      final buttCapPixel = bitmap.pixel(42, bitmap.height - 1 - 50);

      // Round cap should extend past x=80, butt cap should not extend past x=40
      expect(roundCapPixel.alpha, isNot(0)); // Round cap extends
      expect(buttCapPixel.alpha, equals(0)); // Butt cap doesn't extend
    });

    test('save/restore preserves line join style', () {
      final engine = GraphicsEngine(100, 100);

      engine.lineJoin = LineJoin.round;
      engine.lineWidth = 10;
      engine.save();

      engine.lineJoin = LineJoin.miter;
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
      engine.lineWidth = 3;
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

      final shortDash1 = bitmap.pixel(10, bitmap.height - 1 - 30);
      final shortGap = bitmap.pixel(12, bitmap.height - 1 - 30);
      final shortDash2 = bitmap.pixel(14, bitmap.height - 1 - 30);

      expect(shortDash1.alpha, isNot(0));
      expect(shortGap.alpha, equals(0));
      expect(shortDash2.alpha, isNot(0));

      final longDash1 = bitmap.pixel(10, bitmap.height - 1 - 60);
      final longDash2 = bitmap.pixel(19, bitmap.height - 1 - 60);
      final longGap = bitmap.pixel(20, bitmap.height - 1 - 60);

      expect(longDash1.alpha, isNot(0));
      expect(longDash2.alpha, isNot(0));
      expect(longGap.alpha, equals(0));
    });

    test('save/restore preserves gradient fill', () {
      final engine = GraphicsEngine(100, 100);

      engine.fillStyle = LinearGradient(
        start: Point(0, 0),
        end: Point(100, 0),
        stops: [
          ColorStop(0.0, const Color(0xFFFF0000)),
          ColorStop(1.0, const Color(0xFF0000FF)),
        ],
      );
      engine.save();

      engine.fillStyle = const Color(0xFF00FF00);
      final builder1 = PathBuilder()
        ..moveTo(40, 40)
        ..lineTo(60, 40)
        ..lineTo(60, 60)
        ..lineTo(40, 60)
        ..closePath();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..closePath();
      final rect2 = builder2.build();
      engine.fill(rect2);

      final bitmap = engine.canvas;

      final greenPixel = bitmap.pixel(50, bitmap.height - 1 - 50);
      expect(greenPixel.green, equals(255));

      final gradientPixel = bitmap.pixel(20, bitmap.height - 1 - 20);
      expect(gradientPixel.red, greaterThan(0));
    });

    test('nested save/restore operations', () {
      final engine = GraphicsEngine(100, 100);

      engine.fillStyle = const Color(0xFFFF0000);
      engine.save();

      engine.fillStyle = const Color(0xFF00FF00);
      engine.translate(20, 0);
      engine.save();

      engine.fillStyle = const Color(0xFF0000FF);
      engine.translate(20, 0);
      engine.save();

      engine.fillStyle = const Color(0xFFFFFF00);
      engine.translate(20, 0);

      final builder1 = PathBuilder()
        ..moveTo(0, 10)
        ..lineTo(10, 10)
        ..lineTo(10, 20)
        ..lineTo(0, 20)
        ..closePath();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      final builder2 = PathBuilder()
        ..moveTo(0, 30)
        ..lineTo(10, 30)
        ..lineTo(10, 40)
        ..lineTo(0, 40)
        ..closePath();
      final rect2 = builder2.build();
      engine.fill(rect2);

      engine.restore();

      final builder3 = PathBuilder()
        ..moveTo(0, 50)
        ..lineTo(10, 50)
        ..lineTo(10, 60)
        ..lineTo(0, 60)
        ..closePath();
      final rect3 = builder3.build();
      engine.fill(rect3);

      engine.restore();

      final builder4 = PathBuilder()
        ..moveTo(0, 70)
        ..lineTo(10, 70)
        ..lineTo(10, 80)
        ..lineTo(0, 80)
        ..closePath();
      final rect4 = builder4.build();
      engine.fill(rect4);

      final bitmap = engine.canvas;

      final yellowPixel = bitmap.pixel(65, bitmap.height - 1 - 15);
      expect(yellowPixel.red, equals(255));
      expect(yellowPixel.green, equals(255));

      final bluePixel = bitmap.pixel(45, bitmap.height - 1 - 35);
      expect(bluePixel.blue, greaterThanOrEqualTo(254));

      final greenPixel = bitmap.pixel(25, bitmap.height - 1 - 55);
      expect(greenPixel.green, equals(255));

      final redPixel = bitmap.pixel(5, bitmap.height - 1 - 75);
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
        ..closePath();
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
        ..closePath();
      final clipPath2 = clipBuilder2.build();
      engine.clip(clipPath2);

      engine.fillStyle = const Color(0xFFFF0000);
      final builder1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 100)
        ..lineTo(0, 100)
        ..closePath();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      engine.fillStyle = const Color(0xFF00FF00);
      final builder2 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(100, 100)
        ..lineTo(0, 100)
        ..closePath();
      final rect2 = builder2.build();
      engine.fill(rect2);

      final bitmap = engine.canvas;

      // After both fills, (50,50) should be green (was red, then overwritten by green)
      final clippedPixel = bitmap.pixel(50, bitmap.height - 1 - 50);
      expect(clippedPixel.green, greaterThanOrEqualTo(254));
      expect(clippedPixel.red, equals(0));

      // Outside intersection should be empty
      final outsideIntersection = bitmap.pixel(70, bitmap.height - 1 - 70);
      expect(outsideIntersection.alpha, equals(0));

      // Green should be visible in first clip region (10,10) to (60,60)
      final clippedGreen = bitmap.pixel(35, bitmap.height - 1 - 35);
      expect(clippedGreen.green, greaterThanOrEqualTo(254));

      // Outside first clip should be empty
      final outsideFirst = bitmap.pixel(70, bitmap.height - 1 - 35);
      expect(outsideFirst.alpha, equals(0));
    });

    test('save/restore with complex transformations', () {
      final engine = GraphicsEngine(100, 100);

      engine.translate(50, 50);
      engine.save();

      engine.rotate(math.pi / 4);
      engine.save();

      engine.scale(0.5, 0.5);
      engine.fillStyle = const Color(0xFFFF0000);
      final builder1 = PathBuilder()
        ..moveTo(-10, -10)
        ..lineTo(10, -10)
        ..lineTo(10, 10)
        ..lineTo(-10, 10)
        ..closePath();
      final rect1 = builder1.build();
      engine.fill(rect1);

      engine.restore();

      engine.fillStyle = const Color(0xFF00FF00);
      final builder2 = PathBuilder()
        ..moveTo(-5, -5)
        ..lineTo(5, -5)
        ..lineTo(5, 5)
        ..lineTo(-5, 5)
        ..closePath();
      final rect2 = builder2.build();
      engine.fill(rect2);

      engine.restore();

      engine.fillStyle = const Color(0xFF0000FF);
      final builder3 = PathBuilder()
        ..moveTo(-15, -15)
        ..lineTo(15, -15)
        ..lineTo(15, 15)
        ..lineTo(-15, 15)
        ..closePath();
      final rect3 = builder3.build();
      engine.fill(rect3);
    });

    test('save/restore preserves multiple style properties simultaneously', () {
      final engine = GraphicsEngine(100, 100);

      engine.fillStyle = const Color(0xFFFF0000);
      engine.strokeStyle = const Color(0xFF00FF00);
      engine.lineWidth = 3;
      engine.lineCap = LineCap.round;
      engine.lineJoin = LineJoin.round;
      engine.setLineDash([5, 5]);
      engine.translate(10, 10);
      engine.rotate(math.pi / 6);

      engine.save();

      engine.fillStyle = const Color(0xFF0000FF);
      engine.strokeStyle = const Color(0xFFFFFF00);
      engine.lineWidth = 1;
      engine.lineCap = LineCap.butt;
      engine.lineJoin = LineJoin.miter;
      engine.setLineDash([]);
      engine.translate(20, 20);
      engine.rotate(-math.pi / 3);

      final pathBuilder1 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(20, 0)
        ..lineTo(20, 20)
        ..lineTo(0, 20)
        ..closePath();
      final path1 = pathBuilder1.build();
      engine.fill(path1);
      engine.stroke(path1);

      engine.restore();

      final pathBuilder2 = PathBuilder()
        ..moveTo(0, 0)
        ..lineTo(15, 0)
        ..lineTo(15, 15)
        ..lineTo(0, 15)
        ..closePath();
      final path2 = pathBuilder2.build();
      engine.fill(path2);
      engine.stroke(path2);
    });

    test('GraphicsContext save/restore direct test', () {
      final bitmap = Bitmap(100, 100);
      final context = GraphicsContext(bitmap);

      context.state.fillPaint = const Color(0xFFFF0000);
      context.state.strokeWidth = 5.0;
      context.state.transform.translate(10, 10);

      context.save();

      context.state.fillPaint = const Color(0xFF00FF00);
      context.state.strokeWidth = 1.0;
      context.state.transform.scale(2, 2);

      context.save();

      context.state.fillPaint = const Color(0xFF0000FF);

      context.restore();

      expect((context.state.fillPaint as Color).value, equals(0xFF00FF00));
      expect(context.state.strokeWidth, equals(1.0));

      context.restore();

      expect((context.state.fillPaint as Color).value, equals(0xFFFF0000));
      expect(context.state.strokeWidth, equals(5.0));
    });

    test('save without matching restore maintains state', () {
      final engine = GraphicsEngine(100, 100);

      engine.fillStyle = const Color(0xFFFF0000);
      engine.save();
      engine.fillStyle = const Color(0xFF00FF00);
      engine.save();
      engine.fillStyle = const Color(0xFF0000FF);

      final builder = PathBuilder()
        ..moveTo(10, 10)
        ..lineTo(30, 10)
        ..lineTo(30, 30)
        ..lineTo(10, 30)
        ..closePath();
      final rect = builder.build();
      engine.fill(rect);

      final bitmap = engine.canvas;
      final pixel = bitmap.pixel(20, bitmap.height - 1 - 20);
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

  group('Inverse transform', () {
    test('inverse follows in-place changes to the transform', () {
      final state = GraphicsState();
      expect((state.inverse as Ok<Matrix2D, ErrorDetails>).value.tx, equals(0));

      state.transform.translate(7, 0);

      expect(
        (state.inverse as Ok<Matrix2D, ErrorDetails>).value.tx,
        closeTo(-7, 1e-9),
      );
    });

    test('inverse follows TransformState operations', () {
      final state = GraphicsState();
      expect((state.inverse as Ok<Matrix2D, ErrorDetails>).value.a, equals(1));

      state.transform = Matrix2D.scaling(2, 2);

      expect(
        (state.inverse as Ok<Matrix2D, ErrorDetails>).value.a,
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('Saved paints', () {
    test('changing the original stops after save leaves the paint intact', () {
      final context = GraphicsContext(Bitmap(10, 10));
      final stops = [
        ColorStop(0, const Color(0xFFFF0000)),
        ColorStop(1, const Color(0xFF0000FF)),
      ];
      context.state.fillPaint = LinearGradient(
        start: Point(0, 0),
        end: Point(10, 0),
        stops: stops,
      );
      context.save();
      stops[0] = ColorStop(0, const Color(0xFF00FF00));
      stops.add(ColorStop(0.5, const Color(0xFF000000)));
      context.restore();
      final restored = context.state.fillPaint as LinearGradient;
      expect(restored.stops, hasLength(2));
      expect(restored.stops.first.color.value, equals(0xFFFF0000));
    });

    test('changing the original pattern bitmap after save leaves the paint '
        'intact', () {
      final context = GraphicsContext(Bitmap(10, 10));
      final tile = Bitmap(2, 2)..plot(0, 0, const Color(0xFFFF0000));
      context.state.fillPaint = PatternPaint(pattern: tile);
      context.save();
      tile.plot(0, 0, const Color(0xFF00FF00));
      context.restore();
      final restored = context.state.fillPaint as PatternPaint;
      expect(restored.pattern.pixel(0, 0).value, equals(0xFFFF0000));
    });
  });

  group('Saved text settings', () {
    test('restore brings back the font size', () {
      final engine = GraphicsEngine(10, 10);
      engine.fontSize = 14;
      engine.save();
      expect(engine.fontSize, equals(14), reason: 'save keeps the size');
      engine.fontSize = 30;
      expect(engine.fontSize, equals(30));
      engine.restore();
      expect(engine.fontSize, equals(14));
    });

    test('restore brings back the alignment and baseline', () {
      final engine = GraphicsEngine(10, 10);
      engine.textAlign = TextAlign.center;
      engine.textBaseline = TextBaseline.top;
      engine.save();
      expect(engine.textAlign, equals(TextAlign.center));
      expect(engine.textBaseline, equals(TextBaseline.top));
      engine.textAlign = TextAlign.right;
      engine.textBaseline = TextBaseline.bottom;
      engine.restore();
      expect(engine.textAlign, equals(TextAlign.center));
      expect(engine.textBaseline, equals(TextBaseline.top));
    });

    test('restore brings back the font', () {
      final engine = GraphicsEngine(10, 10);
      final first = ok(
        engine.readFont(
          File('test/fixtures/fonts/Radley-Regular.ttf').readAsBytesSync(),
        ),
      );
      engine.save();
      expect(engine.font, same(first), reason: 'save keeps the font');
      ok(
        engine.readFont(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
      expect(engine.font, isNot(same(first)));
      engine.restore();
      expect(engine.font, same(first));
    });

    test('text is measured with the restored size', () {
      final engine = GraphicsEngine(10, 10);
      ok(
        engine.readFont(
          File('test/fixtures/fonts/DejaVuSans.ttf').readAsBytesSync(),
        ),
      );
      engine.fontSize = 10;
      final width = engine.measureText('Hello').width;
      engine.save();
      engine.fontSize = 40;
      expect(engine.measureText('Hello').width, closeTo(width * 4, 1e-6));
      engine.restore();
      expect(engine.measureText('Hello').width, closeTo(width, 1e-6));
    });
  });
}
