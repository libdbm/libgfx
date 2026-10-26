import 'dart:typed_data';

import '../../errors.dart';
import '../../limits.dart';

/// A ligature: the glyphs after the first, and the glyph that replaces them
class _Ligature {
  final List<int> components;
  final int glyph;

  _Ligature(this.components, this.glyph);
}

/// The ligature lookups (type 4, and type 7 extensions of type 4) of a
/// font's GSUB table for some features of its default script and language.
/// Other lookup types are skipped.
class Gsub {
  /// Each lookup, in lookup list order, as ligatures by first glyph, longest
  /// first
  final List<Map<int, List<_Ligature>>> _lookups;

  Gsub._(this._lookups);

  /// Reads the lookups of [features] from the GSUB table [data] of a font
  /// with [glyphs] glyphs. The default script is `DFLT`, else `latn`, else
  /// the first; its default language is used. Throws [RangeError] for
  /// offsets or counts beyond the table, [FormatException] for a ligature
  /// glyph the font does not have, and [ResourceLimitException] when more
  /// than [Limits.ligatures] coverage entries and ligatures would be read.
  static Gsub parse(
    final ByteData data,
    final Set<String> features,
    final int glyphs,
    final Limits limits,
  ) {
    var budget = limits.ligatures;
    void spend(final int count) {
      budget -= count;
      if (budget < 0) {
        throw ResourceLimitException(
          'GSUB exceeds the limit of ${limits.ligatures} ligatures',
        );
      }
    }

    String tag(final int offset) => String.fromCharCodes([
      for (var i = 0; i < 4; i++) data.getUint8(offset + i),
    ]);

    final scripts = data.getUint16(4);
    final featureList = data.getUint16(6);
    final lookupList = data.getUint16(8);

    // The default script
    final count = data.getUint16(scripts);
    if (count == 0) return Gsub._(const []);
    var script = -1;
    for (final wanted in ['DFLT', 'latn']) {
      for (var i = 0; i < count && script < 0; i++) {
        if (tag(scripts + 2 + i * 6) == wanted) {
          script = scripts + data.getUint16(scripts + 6 + i * 6);
        }
      }
    }
    if (script < 0) script = scripts + data.getUint16(scripts + 6);

    // Its default language: the features it lists
    final language = data.getUint16(script);
    if (language == 0) return Gsub._(const []);
    final system = script + language;
    final indices = <int>{};
    final required = data.getUint16(system + 2);
    if (required != 0xFFFF) indices.add(required);
    final listed = data.getUint16(system + 4);
    spend(listed);
    for (var i = 0; i < listed; i++) {
      indices.add(data.getUint16(system + 6 + i * 2));
    }

    // The lookups of the wanted features
    final total = data.getUint16(featureList);
    final lookups = <int>{};
    for (final index in indices) {
      if (index >= total) continue;
      final record = featureList + 2 + index * 6;
      if (!features.contains(tag(record))) continue;
      final feature = featureList + data.getUint16(record + 4);
      final references = data.getUint16(feature + 2);
      spend(references);
      for (var i = 0; i < references; i++) {
        lookups.add(data.getUint16(feature + 4 + i * 2));
      }
    }

    final available = data.getUint16(lookupList);
    final result = <Map<int, List<_Ligature>>>[];
    for (final index in lookups.toList()..sort()) {
      if (index >= available) continue;
      final lookup = lookupList + data.getUint16(lookupList + 2 + index * 2);
      final type = data.getUint16(lookup);
      final subtables = data.getUint16(lookup + 4);
      spend(subtables);
      final ligatures = <int, List<_Ligature>>{};
      for (var i = 0; i < subtables; i++) {
        var subtable = lookup + data.getUint16(lookup + 6 + i * 2);
        var kind = type;
        if (kind == 7) {
          // Extension: format, the lookup type it holds, a 32-bit offset
          kind = data.getUint16(subtable + 2);
          subtable += data.getUint32(subtable + 4);
        }
        if (kind == 4) _ligatures(data, subtable, glyphs, ligatures, spend);
      }
      for (final list in ligatures.values) {
        list.sort((a, b) => b.components.length - a.components.length);
      }
      result.add(ligatures);
    }
    return Gsub._(result);
  }

  /// Reads the ligature substitution subtable at [subtable] into [ligatures]
  static void _ligatures(
    final ByteData data,
    final int subtable,
    final int glyphs,
    final Map<int, List<_Ligature>> ligatures,
    final void Function(int) spend,
  ) {
    if (data.getUint16(subtable) != 1) return; // only format 1 exists
    final coverage = _coverage(
      data,
      subtable + data.getUint16(subtable + 2),
      spend,
    );
    final sets = data.getUint16(subtable + 4);
    for (var index = 0; index < sets && index < coverage.length; index++) {
      final set = subtable + data.getUint16(subtable + 6 + index * 2);
      final count = data.getUint16(set);
      spend(count);
      for (var i = 0; i < count; i++) {
        final ligature = set + data.getUint16(set + 2 + i * 2);
        final glyph = data.getUint16(ligature);
        final length = data.getUint16(ligature + 2);
        if (length == 0) continue;
        spend(length);
        if (glyph >= glyphs) {
          throw FormatException('GSUB ligature glyph $glyph is out of range');
        }
        final components = [
          for (var k = 1; k < length; k++) data.getUint16(ligature + 2 + k * 2),
        ];
        (ligatures[coverage[index]] ??= []).add(_Ligature(components, glyph));
      }
    }
  }

  /// The glyphs of the coverage table at [offset], in coverage index order
  static List<int> _coverage(
    final ByteData data,
    final int offset,
    final void Function(int) spend,
  ) {
    final format = data.getUint16(offset);
    final count = data.getUint16(offset + 2);
    final glyphs = <int>[];
    if (format == 1) {
      spend(count);
      for (var i = 0; i < count; i++) {
        glyphs.add(data.getUint16(offset + 4 + i * 2));
      }
    } else if (format == 2) {
      for (var i = 0; i < count; i++) {
        final record = offset + 4 + i * 6;
        final start = data.getUint16(record);
        final end = data.getUint16(record + 2);
        if (end < start) continue;
        spend(end - start + 1);
        for (var glyph = start; glyph <= end; glyph++) {
          glyphs.add(glyph);
        }
      }
    }
    return glyphs;
  }

  /// [glyphs] with the ligatures applied, lookup by lookup: each result is a
  /// glyph and the number of [glyphs] it stands for
  List<(int, int)> apply(final List<int> glyphs) {
    var run = [for (final glyph in glyphs) (glyph, 1)];
    for (final lookup in _lookups) {
      if (lookup.isEmpty) continue;
      final next = <(int, int)>[];
      var i = 0;
      while (i < run.length) {
        final (first, length) = run[i];
        _Ligature? match;
        for (final ligature in lookup[first] ?? const <_Ligature>[]) {
          final components = ligature.components;
          if (i + components.length >= run.length) continue;
          var same = true;
          for (var k = 0; k < components.length && same; k++) {
            same = run[i + 1 + k].$1 == components[k];
          }
          if (same) {
            match = ligature;
            break;
          }
        }
        if (match == null) {
          next.add((first, length));
          i++;
        } else {
          var covered = length;
          for (var k = 1; k <= match.components.length; k++) {
            covered += run[i + k].$2;
          }
          next.add((match.glyph, covered));
          i += 1 + match.components.length;
        }
      }
      run = next;
    }
    return run;
  }
}
