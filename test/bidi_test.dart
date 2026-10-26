import 'package:libgfx/src/text/bidi.dart';
import 'package:libgfx/src/text/text_types.dart' show TextDirection;
import 'package:libgfx/src/text/unicode_tables.dart' show BidiClass;
import 'package:test/test.dart';

void main() {
  // [text] as it is displayed, left to right
  String visual(
    final String text, [
    TextDirection direction = TextDirection.auto,
  ]) {
    final order = Bidi.order(Bidi.levels(text, direction));
    return String.fromCharCodes([
      for (final index in order) text.codeUnitAt(index),
    ]);
  }

  group('Bidi classes', () {
    test('the table matches the Unicode classes', () {
      expect(Bidi.type('א'.codeUnitAt(0)), BidiClass.r);
      expect(Bidi.type('ا'.codeUnitAt(0)), BidiClass.al);
      expect(Bidi.type('٣'.codeUnitAt(0)), BidiClass.an);
      expect(Bidi.type('3'.codeUnitAt(0)), BidiClass.en);
      expect(Bidi.type('('.codeUnitAt(0)), BidiClass.on);
      expect(Bidi.type(0x064E), BidiClass.nsm);
      expect(Bidi.type(' '.codeUnitAt(0)), BidiClass.ws);
      expect(Bidi.type('a'.codeUnitAt(0)), BidiClass.l);
      expect(Bidi.type(0x1D400), BidiClass.l);
      // Unassigned, in the Hebrew block
      expect(Bidi.type(0x05FF), BidiClass.r);
    });

    test('brackets mirror and letters do not', () {
      expect(Bidi.mirror('('.codeUnitAt(0)), ')'.codeUnitAt(0));
      expect(Bidi.mirror('»'.codeUnitAt(0)), '«'.codeUnitAt(0));
      expect(Bidi.mirror('a'.codeUnitAt(0)), 'a'.codeUnitAt(0));
    });
  });

  group('Bidi levels and order', () {
    test('right-to-left text alone reverses; left-to-right does not', () {
      expect(Bidi.levels('אבג', TextDirection.auto), [1, 1, 1]);
      expect(visual('אבג'), 'גבא');
      expect(Bidi.levels('abc', TextDirection.auto), [0, 0, 0]);
      expect(visual('abc'), 'abc');
    });

    test('the first strong character sets an automatic direction', () {
      expect(Bidi.paragraph('123 אב abc', TextDirection.auto), 1);
      expect(Bidi.paragraph('123 abc אב', TextDirection.auto), 0);
      expect(Bidi.paragraph('123', TextDirection.auto), 0);
      expect(Bidi.paragraph('abc', TextDirection.rtl), 1);
    });

    test('a right-to-left run keeps its numbers left to right', () {
      expect(visual('abc אבג 123 דה', TextDirection.ltr), 'abc הד 123 גבא');
    });

    test('digits after Arabic letters are Arabic numbers (W2)', () {
      expect(Bidi.levels('ب 12', TextDirection.auto), [1, 1, 2, 2]);
      expect(visual('ب 12'), '12 ب');
      // As Arabic numbers they do not take a terminator after them (W5)
      expect(visual('ب 12%'), '%12 ب');
    });

    test('terminators join the numbers beside them (W5)', () {
      expect(visual('א \$12'), '\$12 א');
      expect(visual('א 12%'), '12% א');
    });

    test('a separator between numbers joins them (W4)', () {
      expect(visual('א 1,234'), '1,234 א');
      expect(visual('א 1+2'), '1+2 א');
    });

    test('neutrals take their neighbours\' direction or the paragraph\'s', () {
      // N1: a space between two right-to-left words is right to left
      expect(visual('אב גד', TextDirection.ltr), 'דג בא');
      // N2: between directions it takes the paragraph's
      expect(Bidi.levels('abc אב', TextDirection.ltr), [0, 0, 0, 0, 1, 1]);
      expect(Bidi.levels('abc אב', TextDirection.rtl), [2, 2, 2, 1, 1, 1]);
      expect(visual('abc אב', TextDirection.rtl), 'בא abc');
    });

    test('a mark takes its letter\'s direction (W1)', () {
      expect(Bidi.levels('בַּ', TextDirection.ltr), [1, 1, 1]);
    });

    test('trailing whitespace takes the paragraph level (L1)', () {
      expect(Bidi.levels('אב ', TextDirection.ltr), [1, 1, 0]);
    });

    test('both units of a surrogate pair share a level', () {
      expect(Bidi.levels('א\u{1D400}', TextDirection.rtl), [1, 2, 2]);
    });

    test('runs reverse from the highest level down (L2)', () {
      expect(Bidi.order([0, 1, 1, 0]), [0, 2, 1, 3]);
      expect(Bidi.order([1, 2, 2, 1]), [3, 1, 2, 0]);
      expect(Bidi.order([]), isEmpty);
    });
  });
}
