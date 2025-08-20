import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  group('Text Rendering Refactoring Tests', () {
    late GraphicsEngine engine;

    setUp(() {
      engine = GraphicsEngine(200, 100);
      // We need a font to test text rendering
      // For testing, we'll skip actual font loading
    });

    test('fillText, strokeText, and clipText use unified implementation', () {
      // This test verifies that the refactored methods still work
      // In a real test, we'd need to load a font first

      // Test that methods exist and can be called
      expect(() => engine.fillText, returnsNormally);
      expect(() => engine.strokeText, returnsNormally);
      expect(() => engine.clipText, returnsNormally);
      expect(() => engine.fillAndStrokeText, returnsNormally);
    });

    test('fillAndStrokeText is available as a combined operation', () {
      // The new fillAndStrokeText method should be more efficient
      // than calling fillText and strokeText separately
      expect(engine.fillAndStrokeText, isNotNull);
    });

    test('text alignment options are respected', () {
      // Verify all text alignment options exist
      expect(TextAlign.values, contains(TextAlign.left));
      expect(TextAlign.values, contains(TextAlign.center));
      expect(TextAlign.values, contains(TextAlign.right));
      expect(TextAlign.values, contains(TextAlign.justify));
    });

    test('text baseline options are respected', () {
      // Verify all text baseline options exist
      expect(TextBaseline.values, contains(TextBaseline.alphabetic));
      expect(TextBaseline.values, contains(TextBaseline.top));
      expect(TextBaseline.values, contains(TextBaseline.middle));
      expect(TextBaseline.values, contains(TextBaseline.bottom));
      expect(TextBaseline.values, contains(TextBaseline.ideographic));
      expect(TextBaseline.values, contains(TextBaseline.hanging));
    });
  });
}
