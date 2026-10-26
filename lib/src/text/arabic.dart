import 'unicode_tables.dart';
import 'bidi.dart';

/// How a character joins its neighbours (Unicode joining types)
enum _Joining { dual, right, causing, transparent, none }

/// Arabic joining by presentation forms: each letter is drawn with the
/// isolated, final, initial or medial form its neighbours call for, and lam
/// followed by alef with their ligature.
class Arabic {
  static const _lam = 0x0644;
  static const _tatweel = 0x0640;
  static const _joiner = 0x200D;

  /// The code points to draw for [points], one for each: the presentation
  /// form of each Arabic letter, the lam-alef ligature in place of a lam
  /// followed by alef (with -1 for the alef it absorbs), and every other
  /// code point as given. A form or ligature for which [covers] is false is
  /// not used, so the font's glyph for the letter itself is drawn instead.
  static List<int> join(
    final List<int> points,
    final bool Function(int) covers,
  ) {
    final joinings = [for (final point in points) _joining(point)];
    final result = List.of(points);

    // The nearest neighbour on each side that is not transparent
    int neighbour(final int index, final int step) {
      var i = index + step;
      while (i >= 0 &&
          i < points.length &&
          joinings[i] == _Joining.transparent) {
        i += step;
      }
      return i >= 0 && i < points.length ? i : -1;
    }

    bool forward(final _Joining joining) =>
        joining == _Joining.dual || joining == _Joining.causing;
    bool backward(final _Joining joining) =>
        forward(joining) || joining == _Joining.right;

    for (var i = 0; i < points.length; i++) {
      final joining = joinings[i];
      final forms = arabicForms[points[i]];
      if (forms == null || result[i] == -1) continue;

      final previous = neighbour(i, -1);
      final next = neighbour(i, 1);
      final before =
          backward(joining) && previous >= 0 && forward(joinings[previous]);

      // Lam with the alef after it
      final ligature = points[i] == _lam && next >= 0
          ? lamAlef[points[next]]
          : null;
      if (ligature != null) {
        final code = ligature[before ? 1 : 0];
        if (covers(code)) {
          result[i] = code;
          result[next] = -1;
          continue;
        }
      }

      final after = forward(joining) && next >= 0 && backward(joinings[next]);
      final code = forms[before ? (after ? 3 : 1) : (after ? 2 : 0)];
      if (code != 0 && covers(code)) result[i] = code;
    }
    return result;
  }

  static _Joining _joining(final int point) {
    if (point == _tatweel || point == _joiner) return _Joining.causing;
    final forms = arabicForms[point];
    if (forms != null) {
      if (forms[2] != 0 || forms[3] != 0) return _Joining.dual;
      if (forms[1] != 0) return _Joining.right;
      return _Joining.none;
    }
    return Bidi.type(point) == BidiClass.nsm
        ? _Joining.transparent
        : _Joining.none;
  }
}
