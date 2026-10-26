import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('Color.parse', () {
    test('reads #RRGGBB as opaque', () {
      final result = Color.parse('#FF8000');
      expect(result, isA<Ok<Color, ErrorDetails>>());
      expect((result as Ok<Color, ErrorDetails>).value.value, 0xFFFF8000);
    });

    test('reads #RRGGBBAA with its alpha', () {
      final result = Color.parse('#ff800040');
      expect((result as Ok<Color, ErrorDetails>).value.value, 0x40FF8000);
    });

    test('rejects anything else as malformed', () {
      for (final text in ['FF8000', '#FF80', '#FF80000', '#GG8000', '']) {
        final result = Color.parse(text);
        expect(result, isA<Err<Color, ErrorDetails>>(), reason: text);
        expect(
          (result as Err<Color, ErrorDetails>).error.kind,
          ErrorKind.malformed,
        );
      }
    });
  });

  group('Color as paint', () {
    test('samples to itself everywhere', () {
      const color = Color(0x80123456);
      final inverse = Matrix2D.identity();
      expect(color.sample(const Point(0, 0), inverse), same(color));
      expect(color.sample(const Point(-5, 1e6), inverse), same(color));
    });

    test('fills with the color', () {
      final engine = GraphicsEngine(4, 4)
        ..fillStyle = const Color(0xFF00FF00)
        ..fillRect(0, 0, 4, 4);
      expect(engine.pixel(1, 1).value, 0xFF00FF00);
    });
  });
}
