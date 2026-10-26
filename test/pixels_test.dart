import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

import 'support/pixels.dart';

void main() {
  group('Pixel helpers', () {
    test('empty bitmap has no coverage', () {
      final bitmap = Bitmap(4, 4);

      expect(coverage(bitmap), equals(0));
      expect(painted(bitmap), equals(0));
    });

    test('coverage sums alpha and painted counts pixels', () {
      final bitmap = Bitmap(4, 4);
      bitmap.plot(0, 0, const Color(0xFF000000));
      bitmap.plot(3, 3, const Color(0x40FF0000));

      expect(coverage(bitmap), equals(0xFF + 0x40));
      expect(painted(bitmap), equals(2));
    });

    test('transparent colour is not painted', () {
      final bitmap = Bitmap(2, 2);
      bitmap.plot(1, 1, const Color(0x00FFFFFF));

      expect(coverage(bitmap), equals(0));
      expect(painted(bitmap), equals(0));
    });
  });
}
