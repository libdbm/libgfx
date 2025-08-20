import 'dart:io';
import 'dart:typed_data';

import '../../matrix.dart';
import '../../paths/path.dart';
import '../../point.dart';
import '../../text/text_types.dart' show TextMetrics;
import '../font.dart';
import 'ttf_parser.dart';
import 'ttf_tables.dart';

/// TrueType font implementation
class TTFFont extends Font {
  final TTFParser _parser;
  late final TtfHeadTable _headTable;
  late final TtfHheaTable _hheaTable;
  late final TtfMaxpTable _maxpTable;
  late final TtfNameTable _nameTable;
  late final TtfCmapTable _cmapTable;
  late final List<TtfHorizontalMetric> _hmtxTable;
  TtfLocaTable? _locaTable;
  TtfKernTable? _kernTable;

  TTFFont._(this._parser) {
    _loadTables();
  }

  /// Load a TrueType font from file
  static Future<TTFFont> loadFromFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return TTFFont.fromBytes(bytes);
  }

  /// Load a TrueType font from bytes
  static TTFFont fromBytes(Uint8List bytes) {
    final parser = TTFParser(bytes);
    return TTFFont._(parser);
  }

  void _loadTables() {
    // Load required tables
    _headTable = _parser.readHeadTable();
    _hheaTable = _parser.readHheaTable();
    _maxpTable = _parser.readMaxpTable();
    _nameTable = _parser.readNameTable();
    _cmapTable = _parser.readCmapTable();
    _hmtxTable = _parser.readHmtxTable(
      _hheaTable.numberOfHMetrics,
      _maxpTable.numGlyphs,
    );

    // Load optional tables
    if (_parser.hasTable('loca')) {
      _locaTable = _readLocaTable();
    }

    if (_parser.hasTable('kern')) {
      _kernTable = _readKernTable();
    }
  }

  TtfLocaTable _readLocaTable() {
    final table = _parser.getTable('loca')!;
    final isShortFormat = _headTable.isShortLocaFormat;
    final count = _maxpTable.numGlyphs;
    final offsets = <int>[];

    var offset = table.offset;

    if (isShortFormat) {
      // Short format: offsets are stored as uint16 * 2
      for (int i = 0; i <= count; i++) {
        final shortOffset = _parser.readUint16(offset);
        offsets.add(shortOffset * 2);
        offset += 2;
      }
    } else {
      // Long format: offsets are stored as uint32
      for (int i = 0; i <= count; i++) {
        final longOffset = _parser.readUint32(offset);
        offsets.add(longOffset);
        offset += 4;
      }
    }

    return TtfLocaTable(offsets: offsets, isShortFormat: isShortFormat);
  }

  TtfKernTable? _readKernTable() {
    final table = _parser.getTable('kern');
    if (table == null) return null;

    var offset = table.offset;
    final version = _parser.readUint16(offset);
    final numTables = _parser.readUint16(offset + 2);
    offset += 4;

    final subtables = <TtfKernSubtable>[];

    for (int i = 0; i < numTables; i++) {
      final subtableVersion = _parser.readUint16(offset);
      final length = _parser.readUint16(offset + 2);
      final format = _parser.readUint8(offset + 4);
      final coverage = _parser.readUint8(offset + 5);

      Map<int, int> kerningPairs = {};

      if (format == 0) {
        // Format 0: ordered list of kerning pairs
        final numPairs = _parser.readUint16(offset + 6);
        var pairOffset = offset + 14; // Skip header

        for (int p = 0; p < numPairs; p++) {
          final left = _parser.readUint16(pairOffset);
          final right = _parser.readUint16(pairOffset + 2);
          final value = _parser.readInt16(pairOffset + 4);

          final pairKey = (left << 16) | right;
          kerningPairs[pairKey] = value;

          pairOffset += 6;
        }
      }

      subtables.add(
        TtfKernSubtable(
          version: subtableVersion,
          length: length,
          format: format,
          coverage: coverage,
          kerningPairs: kerningPairs,
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
  String get familyName => _nameTable.fontFamily ?? 'Unknown';

  @override
  String get styleName => _nameTable.fontSubfamily ?? 'Regular';

  @override
  int get unitsPerEm => _headTable.unitsPerEm;

  @override
  FontMetrics get metrics => FontMetrics(
    ascender: _hheaTable.ascender,
    descender: _hheaTable.descender,
    lineGap: _hheaTable.lineGap,
    maxAdvanceWidth: _hheaTable.advanceWidthMax,
    maxAdvanceHeight: 0,
    // Not available in TrueType
    underlineThickness: 50,
    // Default value
    underlinePosition: -100, // Default value
  );

  @override
  bool hasGlyph(int codePoint) {
    return _cmapTable.getGlyphIndex(codePoint) != 0;
  }

  @override
  int getGlyphIndex(int codePoint) {
    return _cmapTable.getGlyphIndex(codePoint);
  }

  @override
  GlyphMetrics getGlyphMetrics(int glyphIndex) {
    if (glyphIndex < 0 || glyphIndex >= _hmtxTable.length) {
      return const GlyphMetrics(
        advanceWidth: 0,
        advanceHeight: 0,
        leftSideBearing: 0,
        topSideBearing: 0,
        boundingBox: GlyphBoundingBox(xMin: 0, yMin: 0, xMax: 0, yMax: 0),
      );
    }

    final metric = _hmtxTable[glyphIndex];

    // Get bounding box from glyph data if available
    GlyphBoundingBox boundingBox = const GlyphBoundingBox(
      xMin: 0,
      yMin: 0,
      xMax: 0,
      yMax: 0,
    );

    if (_locaTable != null && _parser.hasTable('glyf')) {
      final glyphData = _readGlyphData(glyphIndex);
      if (glyphData != null) {
        boundingBox = GlyphBoundingBox(
          xMin: glyphData.xMin,
          yMin: glyphData.yMin,
          xMax: glyphData.xMax,
          yMax: glyphData.yMax,
        );
      }
    }

    return GlyphMetrics(
      advanceWidth: metric.advanceWidth,
      advanceHeight: 0,
      leftSideBearing: metric.leftSideBearing,
      topSideBearing: 0,
      boundingBox: boundingBox,
    );
  }

  @override
  Path getGlyphPath(int glyphIndex, double fontSize) {
    final glyphData = _readGlyphData(glyphIndex);
    if (glyphData == null) {
      return Path(); // Return empty path for missing glyphs
    }

    // Handle composite glyphs
    if (!glyphData.isSimpleGlyph) {
      return _getCompositeGlyphPath(glyphIndex, fontSize);
    }

    final scale = fontSize / unitsPerEm;
    final path = Path();

    // Sort contours by area to ensure proper nesting order (largest first)
    final sortedContours = List.from(glyphData.contours);
    sortedContours.sort((a, b) {
      final areaA = _calculateContourArea(a.points).abs();
      final areaB = _calculateContourArea(b.points).abs();
      return areaB.compareTo(areaA); // Descending order (largest first)
    });

    for (final contour in sortedContours) {
      if (contour.points.isEmpty) continue;

      final points = contour.points;
      var currentPoint = 0;

      // Start the contour
      final firstPoint = points[0];
      path.addCommand(
        PathCommand(PathCommandType.moveTo, [
          Point(firstPoint.x * scale, firstPoint.y * scale),
        ]),
      );

      currentPoint = 1;

      while (currentPoint < points.length) {
        final point = points[currentPoint];

        if (point.onCurve) {
          // Straight line to on-curve point
          path.addCommand(
            PathCommand(PathCommandType.lineTo, [
              Point(point.x * scale, point.y * scale),
            ]),
          );
          currentPoint++;
        } else {
          // Quadratic Bézier curve
          final controlPoint = point;
          late Point endPoint;

          if (currentPoint + 1 < points.length &&
              points[currentPoint + 1].onCurve) {
            // Next point is on-curve, use it as end point
            final nextPoint = points[currentPoint + 1];
            endPoint = Point(nextPoint.x.toDouble(), nextPoint.y.toDouble());
            currentPoint += 2;
          } else {
            // Next point is also off-curve, interpolate between them
            final nextControlPoint = points[(currentPoint + 1) % points.length];
            endPoint = Point.midpoint(
              Point(controlPoint.x.toDouble(), controlPoint.y.toDouble()),
              Point(
                nextControlPoint.x.toDouble(),
                nextControlPoint.y.toDouble(),
              ),
            );
            currentPoint += 1;
          }

          // Convert quadratic to cubic Bézier
          final lastCmd = path.commands.isNotEmpty ? path.commands.last : null;
          Point startPoint;

          if (lastCmd != null && lastCmd.points.isNotEmpty) {
            final lastPoint = lastCmd.points.last;
            startPoint = Point(lastPoint.x / scale, lastPoint.y / scale);
          } else {
            startPoint = Point(
              firstPoint.x.toDouble(),
              firstPoint.y.toDouble(),
            );
          }

          // Convert quadratic (P0, P1, P2) to cubic (P0, C1, C2, P2)
          final cp1x =
              startPoint.x + 2.0 / 3.0 * (controlPoint.x - startPoint.x);
          final cp1y =
              startPoint.y + 2.0 / 3.0 * (controlPoint.y - startPoint.y);
          final cp2x = endPoint.x + 2.0 / 3.0 * (controlPoint.x - endPoint.x);
          final cp2y = endPoint.y + 2.0 / 3.0 * (controlPoint.y - endPoint.y);

          path.addCommand(
            PathCommand(PathCommandType.cubicCurveTo, [
              Point(cp1x * scale, cp1y * scale),
              Point(cp2x * scale, cp2y * scale),
              Point(endPoint.x * scale, endPoint.y * scale),
            ]),
          );
        }
      }

      path.addCommand(PathCommand(PathCommandType.close, []));
    }

    return path;
  }

  /// Calculate the signed area of a contour using the shoelace formula
  /// Positive area = clockwise, negative area = counter-clockwise
  double _calculateContourArea(List<TtfGlyphPoint> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      area += (points[j].x - points[i].x) * (points[j].y + points[i].y);
    }
    return area / 2.0;
  }

  @override
  double getKerning(int leftGlyphIndex, int rightGlyphIndex, double fontSize) {
    if (_kernTable == null) return 0.0;

    final kerningValue = _kernTable!.getKerning(
      leftGlyphIndex,
      rightGlyphIndex,
    );
    return (kerningValue * fontSize) / unitsPerEm;
  }

  @override
  TextMetrics measureText(String text, double fontSize) {
    double totalWidth = 0.0;
    final scale = fontSize / unitsPerEm;
    final scaledMetrics = metrics.scale(fontSize, unitsPerEm);

    final codeUnits = text.runes.toList();

    for (int i = 0; i < codeUnits.length; i++) {
      final codePoint = codeUnits[i];
      final glyphIndex = getGlyphIndex(codePoint);
      final glyphMetrics = getGlyphMetrics(glyphIndex);

      totalWidth += glyphMetrics.advanceWidth * scale;

      // Add kerning if not the last character
      if (i < codeUnits.length - 1) {
        final nextCodePoint = codeUnits[i + 1];
        final nextGlyphIndex = getGlyphIndex(nextCodePoint);
        totalWidth += getKerning(glyphIndex, nextGlyphIndex, fontSize);
      }
    }

    return TextMetrics(
      width: totalWidth,
      height: scaledMetrics.lineHeight.toDouble(),
      ascent: scaledMetrics.ascender.toDouble(),
      descent: -scaledMetrics.descender.toDouble(),
      lineHeight: scaledMetrics.lineHeight.toDouble(),
    );
  }

  @override
  Path getTextPath(String text, double x, double y, double fontSize) {
    final path = Path();
    double currentX = x;
    final codeUnits = text.runes.toList();

    for (int i = 0; i < codeUnits.length; i++) {
      final codePoint = codeUnits[i];
      final glyphIndex = getGlyphIndex(codePoint);
      final glyphPath = getGlyphPath(glyphIndex, fontSize);

      // Transform glyph path to current position
      if (glyphPath.commands.isNotEmpty) {
        final transform = Matrix2D.translation(currentX, y);
        final transformedPath = glyphPath.transform(transform);

        // Add transformed glyph to text path
        for (final command in transformedPath.commands) {
          path.addCommand(command);
        }
      }

      // Advance position
      final glyphMetrics = getGlyphMetrics(glyphIndex);
      final scale = fontSize / unitsPerEm;
      currentX += glyphMetrics.advanceWidth * scale;

      // Add kerning
      if (i < codeUnits.length - 1) {
        final nextCodePoint = codeUnits[i + 1];
        final nextGlyphIndex = getGlyphIndex(nextCodePoint);
        currentX += getKerning(glyphIndex, nextGlyphIndex, fontSize);
      }
    }

    return path;
  }

  /// Get path for a composite glyph
  Path _getCompositeGlyphPath(int glyphIndex, double fontSize) {
    if (_locaTable == null || !_parser.hasTable('glyf')) return Path();

    final glyphOffset = _locaTable!.getGlyphOffset(glyphIndex);
    final glyphLength = _locaTable!.getGlyphLength(glyphIndex);

    if (glyphLength == 0) return Path();

    final table = _parser.getTable('glyf')!;
    final offset = table.offset + glyphOffset;

    // Skip bounding box
    var currentOffset = offset + 10;

    final scale = fontSize / unitsPerEm;
    final path = Path();

    // Parse composite glyph components
    var moreComponents = true;

    while (moreComponents) {
      final flags = _parser.readUint16(currentOffset);
      final componentGlyphIndex = _parser.readUint16(currentOffset + 2);
      currentOffset += 4;

      // Get component glyph path
      final componentPath = getGlyphPath(componentGlyphIndex, fontSize);

      // Parse transformation
      const ARG_1_AND_2_ARE_WORDS = 0x0001;
      const ARGS_ARE_XY_VALUES = 0x0002;
      const WE_HAVE_A_SCALE = 0x0008;
      const MORE_COMPONENTS = 0x0020;
      const WE_HAVE_AN_X_AND_Y_SCALE = 0x0040;
      const WE_HAVE_A_TWO_BY_TWO = 0x0080;

      double dx = 0, dy = 0;
      double scaleX = 1, scaleY = 1;

      // Read arguments
      if (flags & ARG_1_AND_2_ARE_WORDS != 0) {
        if (flags & ARGS_ARE_XY_VALUES != 0) {
          dx = _parser.readInt16(currentOffset).toDouble();
          dy = _parser.readInt16(currentOffset + 2).toDouble();
        }
        currentOffset += 4;
      } else {
        if (flags & ARGS_ARE_XY_VALUES != 0) {
          dx = _parser.readInt8(currentOffset).toDouble();
          dy = _parser.readInt8(currentOffset + 1).toDouble();
        }
        currentOffset += 2;
      }

      // Read scale if present
      if (flags & WE_HAVE_A_SCALE != 0) {
        scaleX = scaleY = _parser.readInt16(currentOffset) / 16384.0;
        currentOffset += 2;
      } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE != 0) {
        scaleX = _parser.readInt16(currentOffset) / 16384.0;
        scaleY = _parser.readInt16(currentOffset + 2) / 16384.0;
        currentOffset += 4;
      } else if (flags & WE_HAVE_A_TWO_BY_TWO != 0) {
        // Skip 2x2 transform for now (complex)
        currentOffset += 8;
      }

      // Apply transformation and merge component path
      dx *= scale;
      dy *= scale;

      for (final command in componentPath.commands) {
        if (command.type == PathCommandType.moveTo &&
            command.points.isNotEmpty) {
          path.addCommand(
            PathCommand(PathCommandType.moveTo, [
              Point(
                command.points[0].x * scaleX + dx,
                command.points[0].y * scaleY + dy,
              ),
            ]),
          );
        } else if (command.type == PathCommandType.lineTo &&
            command.points.isNotEmpty) {
          path.addCommand(
            PathCommand(PathCommandType.lineTo, [
              Point(
                command.points[0].x * scaleX + dx,
                command.points[0].y * scaleY + dy,
              ),
            ]),
          );
        } else if (command.type == PathCommandType.cubicCurveTo &&
            command.points.length >= 3) {
          path.addCommand(
            PathCommand(PathCommandType.cubicCurveTo, [
              Point(
                command.points[0].x * scaleX + dx,
                command.points[0].y * scaleY + dy,
              ),
              Point(
                command.points[1].x * scaleX + dx,
                command.points[1].y * scaleY + dy,
              ),
              Point(
                command.points[2].x * scaleX + dx,
                command.points[2].y * scaleY + dy,
              ),
            ]),
          );
        } else if (command.type == PathCommandType.close) {
          path.addCommand(PathCommand(PathCommandType.close, []));
        }
      }

      moreComponents = (flags & MORE_COMPONENTS) != 0;
    }

    return path;
  }

  TtfGlyphData? _readGlyphData(int glyphIndex) {
    if (_locaTable == null || !_parser.hasTable('glyf')) return null;

    final glyphOffset = _locaTable!.getGlyphOffset(glyphIndex);
    final glyphLength = _locaTable!.getGlyphLength(glyphIndex);

    if (glyphLength == 0) return null; // Empty glyph

    final table = _parser.getTable('glyf')!;
    final offset = table.offset + glyphOffset;

    final numberOfContours = _parser.readInt16(offset);
    final xMin = _parser.readInt16(offset + 2);
    final yMin = _parser.readInt16(offset + 4);
    final xMax = _parser.readInt16(offset + 6);
    final yMax = _parser.readInt16(offset + 8);

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
    var currentOffset = offset + 10;

    // Read contour end points
    final endPtsOfContours = <int>[];
    for (int i = 0; i < numberOfContours; i++) {
      endPtsOfContours.add(_parser.readUint16(currentOffset));
      currentOffset += 2;
    }

    // Read instruction length and instructions
    final instructionLength = _parser.readUint16(currentOffset);
    currentOffset += 2;

    final instructions = <int>[];
    for (int i = 0; i < instructionLength; i++) {
      instructions.add(_parser.readUint8(currentOffset));
      currentOffset += 1;
    }

    // Read coordinates
    final numPoints = endPtsOfContours.isNotEmpty
        ? endPtsOfContours.last + 1
        : 0;
    final points = <TtfGlyphPoint>[];

    if (numPoints > 0) {
      // Read flags
      final flags = <int>[];
      for (int i = 0; i < numPoints; i++) {
        final flag = _parser.readUint8(currentOffset);
        flags.add(flag);
        currentOffset += 1;

        // Handle repeat flag
        if ((flag & 0x08) != 0) {
          final repeatCount = _parser.readUint8(currentOffset);
          currentOffset += 1;
          for (int r = 0; r < repeatCount; r++) {
            flags.add(flag);
            i++;
          }
        }
      }

      // Read x coordinates
      final xCoordinates = <int>[];
      int currentX = 0;
      for (int i = 0; i < numPoints; i++) {
        final flag = flags[i];

        if ((flag & 0x02) != 0) {
          // x-coordinate is a uint8
          final delta = _parser.readUint8(currentOffset);
          currentOffset += 1;
          currentX += (flag & 0x10) != 0 ? delta : -delta;
        } else if ((flag & 0x10) == 0) {
          // x-coordinate is a int16
          final delta = _parser.readInt16(currentOffset);
          currentOffset += 2;
          currentX += delta;
        }
        // else x-coordinate is the same as previous

        xCoordinates.add(currentX);
      }

      // Read y coordinates
      final yCoordinates = <int>[];
      int currentY = 0;
      for (int i = 0; i < numPoints; i++) {
        final flag = flags[i];

        if ((flag & 0x04) != 0) {
          // y-coordinate is a uint8
          final delta = _parser.readUint8(currentOffset);
          currentOffset += 1;
          currentY += (flag & 0x20) != 0 ? delta : -delta;
        } else if ((flag & 0x20) == 0) {
          // y-coordinate is a int16
          final delta = _parser.readInt16(currentOffset);
          currentOffset += 2;
          currentY += delta;
        }
        // else y-coordinate is the same as previous

        yCoordinates.add(currentY);
      }

      // Create points
      for (int i = 0; i < numPoints; i++) {
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
    int startIndex = 0;

    for (final endIndex in endPtsOfContours) {
      final contourPoints = points.sublist(startIndex, endIndex + 1);
      contours.add(TtfGlyphContour(points: contourPoints));
      startIndex = endIndex + 1;
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
