import 'text_types.dart' show TextDirection;
import 'unicode_tables.dart';

/// A simplified Unicode bidirectional algorithm (UAX #9) for one paragraph:
/// rules P2-P3, W1-W7, N1-N2, I1-I2, L1 and L2. Explicit embeddings,
/// overrides and isolates (X1-X10) and bracket pairs (N0) are not applied.
class Bidi {
  /// The bidi class of [codePoint]
  static BidiClass type(final int codePoint) {
    var low = 0;
    var high = bidiStarts.length - 1;
    while (low < high) {
      final middle = (low + high + 1) >> 1;
      if (bidiStarts[middle] <= codePoint) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return BidiClass.values[bidiClasses[low]];
  }

  /// The mirror of [codePoint] in right-to-left text (L4), or [codePoint]
  /// when it has none
  static int mirror(final int codePoint) => mirrors[codePoint] ?? codePoint;

  /// The paragraph level of [text]: 1 for [TextDirection.rtl], 0 for
  /// [TextDirection.ltr], and for [TextDirection.auto] 1 when the first
  /// strong character is right to left (P2-P3)
  static int paragraph(final String text, final TextDirection direction) {
    switch (direction) {
      case TextDirection.ltr:
        return 0;
      case TextDirection.rtl:
        return 1;
      case TextDirection.auto:
        for (final rune in text.runes) {
          final kind = type(rune);
          if (kind == BidiClass.l) return 0;
          if (kind == BidiClass.r || kind == BidiClass.al) return 1;
        }
        return 0;
    }
  }

  /// The embedding level of each UTF-16 code unit of [text]; both units of
  /// a surrogate pair share their character's level
  static List<int> levels(final String text, final TextDirection direction) {
    final base = paragraph(text, direction);
    final runes = text.runes.toList();
    final original = [for (final rune in runes) type(rune)];
    final types = _weak(original, base);
    _neutral(types, base);

    // I1-I2
    final levels = [
      for (final kind in types)
        base.isEven
            ? (kind == BidiClass.r
                  ? base + 1
                  : kind == BidiClass.an || kind == BidiClass.en
                  ? base + 2
                  : base)
            : (kind == BidiClass.l ||
                      kind == BidiClass.an ||
                      kind == BidiClass.en
                  ? base + 1
                  : base),
    ];

    // L1: separators, and whitespace before them or at the end, take the
    // paragraph level
    var trailing = true;
    for (var i = runes.length - 1; i >= 0; i--) {
      final kind = original[i];
      if (kind == BidiClass.s || kind == BidiClass.b) {
        levels[i] = base;
        trailing = true;
      } else if (trailing && (kind == BidiClass.ws || kind == BidiClass.bn)) {
        levels[i] = base;
      } else {
        trailing = false;
      }
    }

    // Spread each character's level over its code units
    final units = <int>[];
    for (var i = 0; i < runes.length; i++) {
      units.add(levels[i]);
      if (runes[i] > 0xFFFF) units.add(levels[i]);
    }
    return units;
  }

  /// The indices of [levels] in visual order: from the highest level down
  /// to the lowest odd level, each run at that level or above is reversed
  /// (L2)
  static List<int> order(final List<int> levels) {
    final indices = List.generate(levels.length, (index) => index);
    if (levels.isEmpty) return indices;
    var highest = 0;
    var lowest = 1 << 30;
    for (final level in levels) {
      if (level > highest) highest = level;
      if (level.isOdd && level < lowest) lowest = level;
    }
    for (var level = highest; level >= lowest; level--) {
      var start = 0;
      while (start < levels.length) {
        if (levels[indices[start]] < level) {
          start++;
          continue;
        }
        var end = start;
        while (end < levels.length && levels[indices[end]] >= level) {
          end++;
        }
        final reversed = indices.sublist(start, end).reversed.toList();
        indices.setRange(start, end, reversed);
        start = end;
      }
    }
    return indices;
  }

  /// Resolves weak types (W1-W7) for one run whose start and end of
  /// sequence take the paragraph direction
  static List<BidiClass> _weak(final List<BidiClass> original, final int base) {
    final edge = base.isOdd ? BidiClass.r : BidiClass.l;
    final types = List.of(original);
    final count = types.length;

    // W1: marks (and boundary neutrals, which X9 would remove) take the
    // type of the character before them
    for (var i = 0; i < count; i++) {
      if (types[i] == BidiClass.nsm || types[i] == BidiClass.bn) {
        types[i] = i == 0 ? edge : types[i - 1];
      }
    }

    // W2: European numbers after Arabic letters are Arabic numbers; W3:
    // Arabic letters are right to left
    var strong = edge;
    for (var i = 0; i < count; i++) {
      final kind = types[i];
      if (kind == BidiClass.l || kind == BidiClass.r || kind == BidiClass.al) {
        strong = kind;
      } else if (kind == BidiClass.en && strong == BidiClass.al) {
        types[i] = BidiClass.an;
      }
    }
    for (var i = 0; i < count; i++) {
      if (types[i] == BidiClass.al) types[i] = BidiClass.r;
    }

    // W4: one separator between two numbers of a kind joins them
    for (var i = 1; i < count - 1; i++) {
      final before = types[i - 1];
      final after = types[i + 1];
      if (types[i] == BidiClass.es &&
          before == BidiClass.en &&
          after == BidiClass.en) {
        types[i] = BidiClass.en;
      } else if (types[i] == BidiClass.cs &&
          before == after &&
          (before == BidiClass.en || before == BidiClass.an)) {
        types[i] = before;
      }
    }

    // W5: terminators next to European numbers join them
    for (var i = 0; i < count; i++) {
      if (types[i] != BidiClass.et) continue;
      var end = i;
      while (end < count && types[end] == BidiClass.et) {
        end++;
      }
      final touches =
          (i > 0 && types[i - 1] == BidiClass.en) ||
          (end < count && types[end] == BidiClass.en);
      if (touches) types.fillRange(i, end, BidiClass.en);
      i = end - 1;
    }

    // W6: remaining separators and terminators are neutral
    for (var i = 0; i < count; i++) {
      final kind = types[i];
      if (kind == BidiClass.es ||
          kind == BidiClass.et ||
          kind == BidiClass.cs) {
        types[i] = BidiClass.on;
      }
    }

    // W7: European numbers after left-to-right text are left to right
    strong = edge;
    for (var i = 0; i < count; i++) {
      final kind = types[i];
      if (kind == BidiClass.l || kind == BidiClass.r) {
        strong = kind;
      } else if (kind == BidiClass.en && strong == BidiClass.l) {
        types[i] = BidiClass.l;
      }
    }
    return types;
  }

  /// Resolves neutrals (N1-N2) in place: a run of neutrals between two
  /// characters of one direction takes it, numbers counting as right to
  /// left; otherwise it takes the paragraph direction
  static void _neutral(final List<BidiClass> types, final int base) {
    final edge = base.isOdd ? BidiClass.r : BidiClass.l;
    BidiClass direction(final BidiClass kind) =>
        kind == BidiClass.l ? BidiClass.l : BidiClass.r;
    bool neutral(final BidiClass kind) =>
        kind == BidiClass.b ||
        kind == BidiClass.s ||
        kind == BidiClass.ws ||
        kind == BidiClass.on;

    final count = types.length;
    var i = 0;
    while (i < count) {
      if (!neutral(types[i])) {
        i++;
        continue;
      }
      var end = i;
      while (end < count && neutral(types[end])) {
        end++;
      }
      final before = i == 0 ? edge : direction(types[i - 1]);
      final after = end == count ? edge : direction(types[end]);
      types.fillRange(i, end, before == after ? before : edge);
      i = end;
    }
  }
}
