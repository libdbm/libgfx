import 'dart:math' show max;
import 'dart:typed_data';

import '../../errors.dart';

import '../../limits.dart';
import '../../logging.dart';
import '../../matrix.dart';
import '../../paths/path.dart';
import '../../point.dart';
import '../../result.dart';
import '../../text/text_types.dart' show TextMetrics;
import '../font.dart';
import '../font_error_messages.dart';
import 'gsub.dart';
import 'ttf_parser.dart';
import 'ttf_tables.dart';
import '../../io/file_system.dart';

/// TrueType font implementation
class TTFFont extends Font {
  final TTFParser _parser;
  late final TtfHeadTable _head;
  late final TtfHheaTable _hhea;
  late final TtfMaxpTable _maxp;
  late final TtfNameTable _names;
  late final TtfCmapTable _cmap;
  late final List<TtfHorizontalMetric> _hmtx;
  TtfLocaTable? _loca;
  TtfKernTable? _kern;

  /// The `ccmp` and `liga` ligatures, or null when the font has no GSUB or
  /// its GSUB could not be read
  Gsub? _gsub;

  /// Outlines in font units, indexed by glyph, decoded on first use.
  late final List<Path?> _outlines = List.filled(_maxp.numGlyphs, null);
  int _decodes = 0;

  TTFFont._(this._parser, final Limits limits) {
    _loadTables();
    _validate(limits);
    _substitutions(limits);
  }

  @override
  List<(int, int)> ligate(final List<int> glyphs) =>
      _gsub?.apply(glyphs) ?? super.ligate(glyphs);

  /// Reads the GSUB ligatures. A GSUB that is malformed or over [limits]
  /// is logged and ignored: the font draws without ligatures.
  void _substitutions(final Limits limits) {
    if (!_parser.hasTable('GSUB')) return;
    try {
      _gsub = Gsub.parse(
        _parser.table('GSUB'),
        const {'ccmp', 'liga'},
        _maxp.numGlyphs,
        limits,
      );
    } on Object catch (error) {
      if (error is! RangeError &&
          error is! FormatException &&
          error is! ResourceLimitException) {
        rethrow;
      }
      logger.warning('Ignoring the GSUB table of $name: $error');
    }
  }

  /// Load a TrueType font from file using the injected [GraphicsFileSystem].
  static Future<Result<TTFFont, ErrorDetails>> load(
    String path, {
    required GraphicsFileSystem filesystem,
    Limits limits = const Limits(),
  }) async {
    final Uint8List? bytes;
    try {
      bytes = await filesystem.read(path);
    } on Exception catch (error) {
      return Err(ErrorDetails(ErrorKind.io, 'Cannot read $path', error));
    }
    if (bytes == null) {
      return Err(
        ErrorDetails(
          ErrorKind.io,
          '${FontErrorMessages.fontFileNotFound}$path',
        ),
      );
    }
    return TTFFont.fromBytes(bytes, limits: limits);
  }

  /// Load a TrueType font from bytes. Exceptions raised by malformed or
  /// truncated data become an [Err]; any other exception is a programming
  /// error and propagates. A file larger than [Limits.font] is rejected
  /// before parsing.
  static Result<TTFFont, ErrorDetails> fromBytes(
    Uint8List bytes, {
    final Limits limits = const Limits(),
  }) {
    if (bytes.length > limits.font) {
      return Err(
        ErrorDetails(
          ErrorKind.limit,
          'Font of ${bytes.length} bytes exceeds the limit of '
          '${limits.font} bytes',
        ),
      );
    }
    try {
      return Ok(TTFFont._(TTFParser(bytes), limits));
    } on RangeError catch (error) {
      return Err(
        ErrorDetails(ErrorKind.truncated, 'Font data ended early', error),
      );
    } on FormatException catch (error) {
      return Err(ErrorDetails(ErrorKind.malformed, error.message, error));
    } on ResourceLimitException catch (error) {
      return Err(ErrorDetails(ErrorKind.limit, error.message, error));
    }
  }

  void _loadTables() {
    // Load required tables
    _head = _parser.readHeadTable();
    _hhea = _parser.readHheaTable();
    _maxp = _parser.readMaxpTable();
    _names = _parser.readNameTable();
    _cmap = _parser.readCmapTable();
    _hmtx = _parser.readHmtxTable(_hhea.numberOfHMetrics, _maxp.numGlyphs);

    // Load optional tables
    if (_parser.hasTable('loca')) {
      _loca = _readLocaTable();
    }

    if (_parser.hasTable('kern')) {
      _kern = _readKernTable();
    }
  }

  /// Expands the size of every glyph once, so that drawing a composite
  /// glyph cannot recurse without bound. A composite that refers to itself,
  /// or matches a point that it or its component does not have, throws
  /// [FormatException]; nesting deeper than [Limits.depth] or a glyph larger
  /// than [Limits.points] throws [ResourceLimitException].
  void _validate(final Limits limits) {
    if (_loca == null || !_parser.hasTable('glyf')) return;
    final sizes = <int, int>{};
    final heights = <int, int>{};
    final counts = <int, int>{}; // points of each glyph
    final active = <int>{};

    void exceed(final int glyph) => throw ResourceLimitException(
      'Glyph $glyph exceeds the limits of ${limits.depth} nested composites '
      'and ${limits.points} points',
    );

    // Returns the expanded size of glyph, reached at depth nested composites
    int expand(final int glyph, final int depth) {
      final known = sizes[glyph];
      if (known != null) return known;
      if (depth > limits.depth) exceed(glyph);
      if (!active.add(glyph)) {
        throw FormatException('Composite glyph $glyph refers to itself');
      }
      final data = _record(glyph);
      var size = 0;
      var height = 0;
      var count = 0;
      if (data != null) {
        final contours = data.getInt16(0);
        if (contours >= 0) {
          size = count = _check(data, contours);
        } else {
          for (final component in _components(data)) {
            size += 1 + expand(component.glyph, depth + 1);
            height = max(height, heights[component.glyph]! + 1);
            if (size > limits.points) exceed(glyph);
            final points = counts[component.glyph]!;
            if (component.matched &&
                (component.first >= count || component.second >= points)) {
              throw FormatException(
                'Composite glyph $glyph matches a point it does not have',
              );
            }
            count += points;
          }
        }
      }
      if (size > limits.points || height > limits.depth) exceed(glyph);
      active.remove(glyph);
      heights[glyph] = height;
      counts[glyph] = count;
      return sizes[glyph] = size;
    }

    for (var glyph = 0; glyph < _maxp.numGlyphs; glyph++) {
      expand(glyph, 0);
    }
  }

  /// Checks that the simple glyph record [data] with [contours] contours
  /// holds everything `_read` reads, and returns its number of
  /// points. Flags are walked a run at a time, so the cost follows the
  /// record's length rather than the points it declares. Throws
  /// [FormatException] for end points that do not increase or flags that
  /// repeat past the last point, and [RangeError] for a record that ends
  /// early.
  static int _check(final ByteData data, final int contours) {
    var last = -1;
    for (var i = 0; i < contours; i++) {
      final end = data.getUint16(10 + i * 2);
      if (end <= last) {
        throw FormatException('Glyph contour end points do not increase');
      }
      last = end;
    }
    final points = last + 1;
    var position = 10 + contours * 2;
    position += 2 + data.getUint16(position);

    // Bytes of x and y coordinates the flags call for
    var bytes = 0;
    var count = 0;
    while (count < points) {
      final flag = data.getUint8(position++);
      final run = flag & 0x08 != 0 ? 1 + data.getUint8(position++) : 1;
      count += run;
      if (count > points) {
        throw FormatException('Glyph flags repeat past the last point');
      }
      final x = flag & 0x02 != 0 ? 1 : (flag & 0x10 != 0 ? 0 : 2);
      final y = flag & 0x04 != 0 ? 1 : (flag & 0x20 != 0 ? 0 : 2);
      bytes += run * (x + y);
    }
    if (position + bytes > data.lengthInBytes) {
      throw RangeError('Glyph coordinates end early');
    }
    return points;
  }

  TtfLocaTable _readLocaTable() {
    final data = _parser.table('loca');
    final short = _head.isShortLocaFormat;
    final count = _maxp.numGlyphs;
    final offsets = <int>[];

    var offset = 0;

    if (short) {
      // Short format: offsets are stored as uint16 * 2
      for (int i = 0; i <= count; i++) {
        final value = data.getUint16(offset);
        offsets.add(value * 2);
        offset += 2;
      }
    } else {
      // Long format: offsets are stored as uint32
      for (int i = 0; i <= count; i++) {
        final value = data.getUint32(offset);
        offsets.add(value);
        offset += 4;
      }
    }

    // Every glyph's range must lie within glyf and not end before it starts
    if (_parser.hasTable('glyf')) {
      final length = _parser.table('glyf').lengthInBytes;
      for (var i = 0; i <= count; i++) {
        if (offsets[i] > length || (i > 0 && offsets[i] < offsets[i - 1])) {
          throw FormatException('Glyph location $i is out of order or range');
        }
      }
    }

    return TtfLocaTable(offsets: offsets, isShortFormat: short);
  }

  /// The record of [glyph] in `glyf`, bounded by its `loca` range so that it
  /// cannot be read past, or null if the glyph has no outline.
  ByteData? _record(final int glyph) {
    final loca = _loca;
    if (loca == null || !_parser.hasTable('glyf')) return null;
    final length = loca.getGlyphLength(glyph);
    if (length == 0) return null;
    final start = loca.getGlyphOffset(glyph);
    return ByteData.sublistView(_parser.table('glyf'), start, start + length);
  }

  TtfKernTable? _readKernTable() {
    if (!_parser.hasTable('kern')) return null;
    final data = _parser.table('kern');

    var offset = 0;
    final version = data.getUint16(offset);
    final numTables = data.getUint16(offset + 2);
    offset += 4;

    final subtables = <TtfKernSubtable>[];

    for (int i = 0; i < numTables; i++) {
      final subtableVersion = data.getUint16(offset);
      final length = data.getUint16(offset + 2);
      final format = data.getUint8(offset + 4);
      final coverage = data.getUint8(offset + 5);

      Map<int, int> pairs = {};

      if (format == 0) {
        // Format 0: ordered list of kerning pairs
        final count = data.getUint16(offset + 6);
        var position = offset + 14; // Skip header

        for (int p = 0; p < count; p++) {
          final left = data.getUint16(position);
          final right = data.getUint16(position + 2);
          final value = data.getInt16(position + 4);

          final key = (left << 16) | right;
          pairs[key] = value;

          position += 6;
        }
      }

      subtables.add(
        TtfKernSubtable(
          version: subtableVersion,
          length: length,
          format: format,
          coverage: coverage,
          kerningPairs: pairs,
        ),
      );

      offset += length;
    }

    return TtfKernTable(
      version: version,
      numTables: numTables,
      subtables: subtables,
    );
  }

  @override
  String get family => _names.fontFamily ?? 'Unknown';

  @override
  String get style => _names.fontSubfamily ?? 'Regular';

  @override
  int get unitsPerEm => _head.unitsPerEm;

  @override
  FontMetrics get metrics => FontMetrics(
    ascender: _hhea.ascender,
    descender: _hhea.descender,
    lineGap: _hhea.lineGap,
    maxAdvanceWidth: _hhea.advanceWidthMax,
    maxAdvanceHeight: 0,
    // Not available in TrueType
    underlineThickness: 50,
    // Default value
    underlinePosition: -100, // Default value
  );

  @override
  bool covers(int codePoint) {
    return glyph(codePoint) != 0;
  }

  @override
  int glyph(int codePoint) {
    // A glyph id outside the font is treated as missing
    final glyph = _cmap.getGlyphIndex(codePoint);
    return glyph < _maxp.numGlyphs ? glyph : 0;
  }

  @override
  GlyphMetrics dimensions(final int glyph) {
    if (glyph < 0 || glyph >= _hmtx.length) {
      return const GlyphMetrics(
        advanceWidth: 0,
        advanceHeight: 0,
        leftSideBearing: 0,
        topSideBearing: 0,
        boundingBox: GlyphBoundingBox(xMin: 0, yMin: 0, xMax: 0, yMax: 0),
      );
    }

    final metric = _hmtx[glyph];

    // Get bounding box from glyph data if available
    GlyphBoundingBox box = const GlyphBoundingBox(
      xMin: 0,
      yMin: 0,
      xMax: 0,
      yMax: 0,
    );

    // The bounding box is in the glyph header, so the outline is not read
    final data = _record(glyph);
    if (data != null) {
      box = GlyphBoundingBox(
        xMin: data.getInt16(2),
        yMin: data.getInt16(4),
        xMax: data.getInt16(6),
        yMax: data.getInt16(8),
      );
    }

    return GlyphMetrics(
      advanceWidth: metric.advanceWidth,
      advanceHeight: 0,
      leftSideBearing: metric.leftSideBearing,
      topSideBearing: 0,
      boundingBox: box,
    );
  }

  @override
  Path outline(final int glyph, final double size) {
    final scale = size / unitsPerEm;
    return _outline(glyph).transform(Matrix2D.scaling(scale, scale));
  }

  /// Number of glyph outlines decoded so far. Outlines are cached, so each
  /// glyph is decoded at most once.
  int get decodes => _decodes;

  /// The outline of [glyph] in font units, decoded on first use.
  Path _outline(final int glyph) {
    if (glyph < 0 || glyph >= _outlines.length) return Path();
    return _outlines[glyph] ??= _decode(glyph);
  }

  /// Decodes the outline of [glyph] in font units.
  Path _decode(final int glyph) {
    _decodes++;
    final data = _read(glyph);
    if (data == null) {
      return Path(); // Return empty path for missing glyphs
    }

    // Handle composite glyphs
    if (!data.isSimpleGlyph) {
      return _composite(glyph);
    }

    final path = Path();

    // Sort contours by area to ensure proper nesting order (largest first)
    final sorted = List.from(data.contours);
    sorted.sort((a, b) {
      final areaA = _area(a.points).abs();
      final areaB = _area(b.points).abs();
      return areaB.compareTo(areaA); // Descending order (largest first)
    });

    for (final contour in sorted) {
      if (contour.points.isEmpty) continue;

      final points = contour.points;
      var index = 0;

      // Start the contour
      final first = points[0];
      path.add(
        PathCommand(PathCommandType.moveTo, [
          Point(first.x.toDouble(), first.y.toDouble()),
        ]),
      );

      index = 1;

      while (index < points.length) {
        final point = points[index];

        if (point.onCurve) {
          // Straight line to on-curve point
          path.add(
            PathCommand(PathCommandType.lineTo, [
              Point(point.x.toDouble(), point.y.toDouble()),
            ]),
          );
          index++;
        } else {
          // Quadratic Bézier curve
          final control = point;
          late Point end;

          if (index + 1 < points.length && points[index + 1].onCurve) {
            // Next point is on-curve, use it as end point
            final next = points[index + 1];
            end = Point(next.x.toDouble(), next.y.toDouble());
            index += 2;
          } else {
            // Next point is also off-curve, interpolate between them
            final following = points[(index + 1) % points.length];
            end = Point.midpoint(
              Point(control.x.toDouble(), control.y.toDouble()),
              Point(following.x.toDouble(), following.y.toDouble()),
            );
            index += 1;
          }

          // Convert quadratic to cubic Bézier
          final last = path.commands.isNotEmpty ? path.commands.last : null;
          Point start;

          if (last != null && last.points.isNotEmpty) {
            start = last.points.last;
          } else {
            start = Point(first.x.toDouble(), first.y.toDouble());
          }

          // Convert quadratic (P0, P1, P2) to cubic (P0, C1, C2, P2)
          final cp1x = start.x + 2.0 / 3.0 * (control.x - start.x);
          final cp1y = start.y + 2.0 / 3.0 * (control.y - start.y);
          final cp2x = end.x + 2.0 / 3.0 * (control.x - end.x);
          final cp2y = end.y + 2.0 / 3.0 * (control.y - end.y);

          path.add(
            PathCommand(PathCommandType.cubicCurveTo, [
              Point(cp1x, cp1y),
              Point(cp2x, cp2y),
              end,
            ]),
          );
        }
      }

      path.add(PathCommand(PathCommandType.close, []));
    }

    return path;
  }

  /// Calculate the signed area of a contour using the shoelace formula
  /// Positive area = clockwise, negative area = counter-clockwise
  double _area(List<TtfGlyphPoint> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += (points[j].x - points[i].x) * (points[j].y + points[i].y);
    }
    return area / 2.0;
  }

  @override
  double kerning(final int left, final int right, final double size) {
    if (_kern == null) return 0.0;

    final value = _kern!.getKerning(left, right);
    return (value * size) / unitsPerEm;
  }

  @override
  TextMetrics measure(String text, final double size) {
    double width = 0.0;
    final scale = size / unitsPerEm;
    final scaled = metrics.scale(size, unitsPerEm);

    final points = text.runes.toList();

    for (int i = 0; i < points.length; i++) {
      final codePoint = points[i];
      final index = glyph(codePoint);
      final metric = dimensions(index);

      width += metric.advanceWidth * scale;

      // Add kerning if not the last character
      if (i < points.length - 1) {
        final next = points[i + 1];
        final neighbor = glyph(next);
        width += kerning(index, neighbor, size);
      }
    }

    return TextMetrics(
      width: width,
      height: scaled.lineHeight.toDouble(),
      ascent: scaled.ascender.toDouble(),
      descent: -scaled.descender.toDouble(),
      lineHeight: scaled.lineHeight.toDouble(),
    );
  }

  @override
  Path path(String text, double x, double y, final double size) {
    final path = Path();
    double cursor = x;
    final points = text.runes.toList();

    for (int i = 0; i < points.length; i++) {
      final codePoint = points[i];
      final index = glyph(codePoint);
      final shape = outline(index, size);

      // Transform glyph path to current position
      if (shape.commands.isNotEmpty) {
        final transform = Matrix2D.translation(cursor, y);
        final transformed = shape.transform(transform);

        // Add transformed glyph to text path
        for (final command in transformed.commands) {
          path.add(command);
        }
      }

      // Advance position
      final metric = dimensions(index);
      final scale = size / unitsPerEm;
      cursor += metric.advanceWidth * scale;

      // Add kerning
      if (i < points.length - 1) {
        final next = points[i + 1];
        final neighbor = glyph(next);
        cursor += kerning(index, neighbor, size);
      }
    }

    return path;
  }

  /// Get path for a composite glyph, in font units
  Path _composite(final int glyph) {
    final data = _record(glyph);
    if (data == null) return Path();

    final path = Path();
    final points = <Point>[];
    for (final component in _components(data)) {
      final transform = component.transform;
      final child = _points(component.glyph).map(transform.transform).toList();
      final offset = _offset(component, points, child);
      final placed = _outline(component.glyph).transform(
        Matrix2D(
          transform.a,
          transform.b,
          transform.c,
          transform.d,
          offset.x,
          offset.y,
        ),
      );
      for (final command in placed.commands) {
        path.add(command);
      }
      points.addAll(child.map((point) => point + offset));
    }
    return path;
  }

  /// The points of [glyph] in font units, numbered as point matching
  /// numbers them: a simple glyph's points in order, then each component's
  /// points as placed
  List<Point> _points(final int glyph) {
    final data = _record(glyph);
    if (data == null) return const [];
    if (data.getInt16(0) >= 0) {
      return [
        for (final contour in _read(glyph)!.contours)
          for (final point in contour.points)
            Point(point.x.toDouble(), point.y.toDouble()),
      ];
    }
    final points = <Point>[];
    for (final component in _components(data)) {
      final child = _points(
        component.glyph,
      ).map(component.transform.transform).toList();
      final offset = _offset(component, points, child);
      points.addAll(child.map((point) => point + offset));
    }
    return points;
  }

  /// Where [component] goes: its own offset or, when matched, the offset
  /// that puts point `second` of its transformed points [child] on point
  /// `first` of the composite's [points] so far
  static Point _offset(
    final _Component component,
    final List<Point> points,
    final List<Point> child,
  ) {
    if (component.matched) {
      return points[component.first] - child[component.second];
    }
    final offset = Point(
      component.first.toDouble(),
      component.second.toDouble(),
    );
    // SCALED_COMPONENT_OFFSET without UNSCALED_COMPONENT_OFFSET
    final scaled =
        component.flags & 0x0800 != 0 && component.flags & 0x1000 == 0;
    return scaled ? component.transform.transform(offset) : offset;
  }

  /// The components of the composite glyph record [data]. Throws
  /// [RangeError] for a record that ends early.
  static List<_Component> _components(final ByteData data) {
    final components = <_Component>[];
    var position = 10;
    var more = true;
    while (more) {
      final flags = data.getUint16(position);
      final glyph = data.getUint16(position + 2);
      position += 4;

      // Offsets are signed, matched point numbers unsigned
      final matched = flags & 0x0002 == 0;
      final int first;
      final int second;
      if (flags & 0x0001 != 0) {
        first = matched ? data.getUint16(position) : data.getInt16(position);
        second = matched
            ? data.getUint16(position + 2)
            : data.getInt16(position + 2);
        position += 4;
      } else {
        first = matched ? data.getUint8(position) : data.getInt8(position);
        second = matched
            ? data.getUint8(position + 1)
            : data.getInt8(position + 1);
        position += 2;
      }

      // F2Dot14 scale, x and y scales, or 2x2 transform
      double fixed() {
        final value = data.getInt16(position) / 16384;
        position += 2;
        return value;
      }

      var a = 1.0, b = 0.0, c = 0.0, d = 1.0;
      if (flags & 0x0008 != 0) {
        a = d = fixed();
      } else if (flags & 0x0040 != 0) {
        a = fixed();
        d = fixed();
      } else if (flags & 0x0080 != 0) {
        a = fixed();
        b = fixed();
        c = fixed();
        d = fixed();
      }

      components.add(
        _Component(glyph, flags, first, second, Matrix2D(a, b, c, d, 0, 0)),
      );
      more = flags & 0x0020 != 0;
    }
    return components;
  }

  TtfGlyphData? _read(final int glyph) {
    final data = _record(glyph);
    if (data == null) return null; // Empty glyph

    final numberOfContours = data.getInt16(0);
    final xMin = data.getInt16(2);
    final yMin = data.getInt16(4);
    final xMax = data.getInt16(6);
    final yMax = data.getInt16(8);

    if (numberOfContours < 0) {
      // Composite glyph - not implemented yet
      return TtfGlyphData(
        numberOfContours: numberOfContours,
        xMin: xMin,
        yMin: yMin,
        xMax: xMax,
        yMax: yMax,
        contours: [],
        instructions: [],
      );
    }

    // Simple glyph
    var position = 10;

    // Read contour end points
    final endPtsOfContours = <int>[];
    for (int i = 0; i < numberOfContours; i++) {
      endPtsOfContours.add(data.getUint16(position));
      position += 2;
    }

    // Read instruction length and instructions
    final instructionLength = data.getUint16(position);
    position += 2;

    final instructions = <int>[];
    for (int i = 0; i < instructionLength; i++) {
      instructions.add(data.getUint8(position));
      position += 1;
    }

    // Read coordinates
    final count = endPtsOfContours.isNotEmpty ? endPtsOfContours.last + 1 : 0;
    final points = <TtfGlyphPoint>[];

    if (count > 0) {
      // Read flags
      final flags = <int>[];
      for (int i = 0; i < count; i++) {
        final flag = data.getUint8(position);
        flags.add(flag);
        position += 1;

        // Handle repeat flag
        if ((flag & 0x08) != 0) {
          final repeats = data.getUint8(position);
          position += 1;
          for (int r = 0; r < repeats; r++) {
            flags.add(flag);
            i++;
          }
        }
      }

      // Read x coordinates
      final xCoordinates = <int>[];
      int x = 0;
      for (int i = 0; i < count; i++) {
        final flag = flags[i];

        if ((flag & 0x02) != 0) {
          // x-coordinate is a uint8
          final delta = data.getUint8(position);
          position += 1;
          x += (flag & 0x10) != 0 ? delta : -delta;
        } else if ((flag & 0x10) == 0) {
          // x-coordinate is a int16
          final delta = data.getInt16(position);
          position += 2;
          x += delta;
        }
        // else x-coordinate is the same as previous

        xCoordinates.add(x);
      }

      // Read y coordinates
      final yCoordinates = <int>[];
      int y = 0;
      for (int i = 0; i < count; i++) {
        final flag = flags[i];

        if ((flag & 0x04) != 0) {
          // y-coordinate is a uint8
          final delta = data.getUint8(position);
          position += 1;
          y += (flag & 0x20) != 0 ? delta : -delta;
        } else if ((flag & 0x20) == 0) {
          // y-coordinate is a int16
          final delta = data.getInt16(position);
          position += 2;
          y += delta;
        }
        // else y-coordinate is the same as previous

        yCoordinates.add(y);
      }

      // Create points
      for (int i = 0; i < count; i++) {
        points.add(
          TtfGlyphPoint(
            x: xCoordinates[i],
            y: yCoordinates[i],
            onCurve: (flags[i] & 0x01) != 0,
          ),
        );
      }
    }

    // Group points into contours
    final contours = <TtfGlyphContour>[];
    int start = 0;

    for (final end in endPtsOfContours) {
      final segment = points.sublist(start, end + 1);
      contours.add(TtfGlyphContour(points: segment));
      start = end + 1;
    }

    return TtfGlyphData(
      numberOfContours: numberOfContours,
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
      contours: contours,
      instructions: instructions,
    );
  }
}

/// One component of a composite glyph: [glyph] placed by the offset
/// ([first], [second]) or, when [matched], by putting its point [second] on
/// the composite's point [first], after [transform]
class _Component {
  final int glyph;
  final int flags;
  final int first;
  final int second;
  final Matrix2D transform;

  _Component(this.glyph, this.flags, this.first, this.second, this.transform);

  bool get matched => flags & 0x0002 == 0;
}
