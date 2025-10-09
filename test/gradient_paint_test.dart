import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('GradientPaint', () {
    test('addColorStop maintains ordering and clamps offsets', () {
      final gradient = LinearGradient(
        startPoint: Point(0, 0),
        endPoint: Point(10, 0),
        stops: [ColorStop(0.0, const Color(0xFF000000))],
      );

      gradient.addColorStop(0.5, const Color(0xFF00FF00));
      gradient.addColorStop(1.5, const Color(0xFF0000FF));

      expect(gradient.stops.length, equals(3));
      expect(gradient.stops[1].offset, equals(0.5));
      expect(gradient.stops[2].offset, equals(1.0));
    });

    test('setColorStops replaces and normalizes stops', () {
      final gradient = LinearGradient(
        startPoint: Point(0, 0),
        endPoint: Point(10, 0),
        stops: [ColorStop(0.0, const Color(0xFF000000))],
      );

      gradient.setColorStops([
        ColorStop(0.75, const Color(0xFFFF0000)),
        ColorStop(-0.5, const Color(0xFF00FF00)),
      ]);

      expect(gradient.stops.length, equals(2));
      expect(gradient.stops.first.offset, equals(0.0));
      expect(gradient.stops.last.offset, equals(0.75));
    });

    test('clearColorStops removes all stops', () {
      final gradient = LinearGradient(
        startPoint: Point(0, 0),
        endPoint: Point(10, 0),
        stops: [
          ColorStop(0.0, const Color(0xFF000000)),
          ColorStop(1.0, const Color(0xFFFFFFFF)),
        ],
      );

      gradient.clearColorStops();

      expect(gradient.stops, isEmpty);
    });
  });
}
