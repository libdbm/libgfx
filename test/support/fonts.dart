import 'dart:typed_data';

/// A minimal TrueType font with [glyphs] glyphs. [cmap], when given, is the
/// font's one cmap subtable, registered as Windows Unicode full repertoire;
/// [cmaps] instead lists subtables with their platform and encoding, in
/// order. [outlines] are the glyph data of the first glyphs in a
/// long-format `loca`/`glyf`; the remaining glyphs are empty. There is no
/// `glyf` table if [outlines] is empty.
Uint8List font({
  final Uint8List? cmap,
  final List<(int, int, Uint8List)>? cmaps,
  final List<Uint8List> outlines = const [],
  final int glyphs = 1000,
}) {
  final subtables = cmaps ?? [if (cmap != null) (3, 10, cmap)];
  final header = ByteData(4 + subtables.length * 8)
    ..setUint16(2, subtables.length);
  var start = header.lengthInBytes;
  for (var i = 0; i < subtables.length; i++) {
    final (platform, encoding, subtable) = subtables[i];
    header
      ..setUint16(4 + i * 8, platform)
      ..setUint16(6 + i * 8, encoding)
      ..setUint32(8 + i * 8, start);
    start += subtable.length;
  }
  final tables = {
    'cmap': Uint8List.fromList([
      ...header.buffer.asUint8List(),
      for (final (_, _, subtable) in subtables) ...subtable,
    ]),
    'head':
        (ByteData(54)
              ..setUint16(18, 1000)
              ..setInt16(50, 1))
            .buffer
            .asUint8List(),
    'hhea': (ByteData(36)..setUint16(34, 1)).buffer.asUint8List(),
    'hmtx': Uint8List(4 + (glyphs - 1) * 2),
    'maxp':
        (ByteData(6)
              ..setUint32(0, 0x00005000)
              ..setUint16(4, glyphs))
            .buffer
            .asUint8List(),
    'name': (ByteData(6)..setUint16(4, 6)).buffer.asUint8List(),
    if (outlines.isNotEmpty) ..._glyf(outlines, glyphs),
  };
  final directory = ByteData(12 + tables.length * 16)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, tables.length);
  final body = BytesBuilder();
  var offset = directory.lengthInBytes;
  var index = 0;
  for (final MapEntry(key: tag, value: table) in tables.entries) {
    final record = 12 + index++ * 16;
    for (var i = 0; i < 4; i++) {
      directory.setUint8(record + i, tag.codeUnitAt(i));
    }
    directory
      ..setUint32(record + 8, offset)
      ..setUint32(record + 12, table.length);
    body.add(table);
    offset += table.length;
  }
  return Uint8List.fromList([
    ...directory.buffer.asUint8List(),
    ...body.takeBytes(),
  ]);
}

/// A simple glyph with one contour of [points] on-curve points at the
/// origin.
Uint8List simple(final int points) {
  final data = ByteData(14 + points)
    ..setInt16(0, 1)
    ..setUint16(10, points - 1);
  for (var i = 0; i < points; i++) {
    // On curve, x and y repeat the previous coordinate
    data.setUint8(14 + i, 0x31);
  }
  return data.buffer.asUint8List();
}

/// A composite glyph made of [components], each placed at offset ([dx], 0).
Uint8List composite(final List<int> components, {final int dx = 0}) {
  final data = ByteData(10 + components.length * 6)..setInt16(0, -1);
  for (var i = 0; i < components.length; i++) {
    final more = i < components.length - 1 ? 0x0020 : 0;
    data
      ..setUint16(10 + i * 6, 0x0002 | more)
      ..setUint16(12 + i * 6, components[i])
      ..setInt8(14 + i * 6, dx);
  }
  return data.buffer.asUint8List();
}

/// A simple glyph with one contour through the on-curve [points].
Uint8List polygon(final List<(int, int)> points) {
  final count = points.length;
  final data = ByteData(14 + count * 5)
    ..setInt16(0, 1)
    ..setUint16(10, count - 1);
  var position = 14;
  for (var i = 0; i < count; i++) {
    // On curve, x and y as 16-bit deltas
    data.setUint8(position++, 0x01);
  }
  // All the x coordinates, then all the y coordinates
  for (final vertical in [false, true]) {
    var last = 0;
    for (final point in points) {
      final value = vertical ? point.$2 : point.$1;
      data.setInt16(position, value - last);
      position += 2;
      last = value;
    }
  }
  return data.buffer.asUint8List();
}

/// A component of a composite glyph: [glyph] moved by (x, y) or, when
/// [matched], placed so that its point y lies on the composite's point x.
/// [transform] is empty, one scale, x and y scales, or a 2x2 matrix in the
/// order TrueType stores it (xx, xy, yx, yy), each from -2 to under 2.
class Component {
  final int glyph;
  final int x;
  final int y;
  final bool matched;
  final List<double> transform;

  const Component(
    this.glyph, {
    this.x = 0,
    this.y = 0,
    this.matched = false,
    this.transform = const [],
  });
}

/// A composite glyph of [components], with 16-bit arguments.
Uint8List composed(final List<Component> components) {
  final data = BytesBuilder()
    ..add((ByteData(10)..setInt16(0, -1)).buffer.asUint8List());
  for (var i = 0; i < components.length; i++) {
    final component = components[i];
    final scale = switch (component.transform.length) {
      0 => 0,
      1 => 0x0008,
      2 => 0x0040,
      4 => 0x0080,
      _ => throw ArgumentError('transform of ${component.transform.length}'),
    };
    final flags =
        0x0001 |
        (component.matched ? 0 : 0x0002) |
        (i < components.length - 1 ? 0x0020 : 0) |
        scale;
    final record = ByteData(8 + component.transform.length * 2)
      ..setUint16(0, flags)
      ..setUint16(2, component.glyph);
    if (component.matched) {
      record
        ..setUint16(4, component.x)
        ..setUint16(6, component.y);
    } else {
      record
        ..setInt16(4, component.x)
        ..setInt16(6, component.y);
    }
    for (var j = 0; j < component.transform.length; j++) {
      // F2Dot14
      record.setInt16(8 + j * 2, (component.transform[j] * 16384).round());
    }
    data.add(record.buffer.asUint8List());
  }
  return data.takeBytes();
}

Map<String, Uint8List> _glyf(final List<Uint8List> outlines, final int glyphs) {
  final loca = ByteData((glyphs + 1) * 4);
  final glyf = BytesBuilder();
  for (var i = 0; i <= glyphs; i++) {
    loca.setUint32(i * 4, glyf.length);
    if (i < outlines.length) glyf.add(outlines[i]);
  }
  return {'glyf': glyf.takeBytes(), 'loca': loca.buffer.asUint8List()};
}
