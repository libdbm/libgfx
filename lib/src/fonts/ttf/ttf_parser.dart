import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../font_error_messages.dart';
import 'ttf_tables.dart';

/// TrueType font parser for reading TTF/OTF font files
class TTFParser {
  late final ByteData _data;
  late final Map<String, TtfTable> _tables;

  TTFParser(final Uint8List bytes) {
    _data = ByteData.sublistView(bytes);
    _tables = {};
    _parseTables();
  }

  /// Parse the font directory and table directory
  void _parseTables() {
    // Read sfnt version (offset 0)
    final sfntVersion = _readUint32(0);

    // Verify it's a valid TrueType font
    if (sfntVersion != 0x00010000 && sfntVersion != 0x4F54544F) {
      // 1.0 or 'OTTO'
      throw FormatException(FontErrorMessages.invalidTrueTypeFormat);
    }

    // Read number of tables (offset 4)
    final numTables = _readUint16(4);
    if (12 + numTables * 16 > _data.lengthInBytes) {
      throw FormatException(
        'Table directory of $numTables tables exceeds the font data',
      );
    }

    // Parse table directory (starts at offset 12)
    var offset = 12;
    for (int i = 0; i < numTables; i++) {
      final tag = _readString(offset, 4);
      final checkSum = _readUint32(offset + 4);
      final start = _readUint32(offset + 8);
      final length = _readUint32(offset + 12);
      if (start + length > _data.lengthInBytes) {
        throw RangeError('Table $tag extends past the end of the font data');
      }

      _tables[tag] = TtfTable(
        tag: tag,
        checkSum: checkSum,
        offset: start,
        length: length,
      );

      offset += 16;
    }
  }

  /// Get a specific table by tag
  TtfTable? getTable(String tag) => _tables[tag];

  /// Check if a table exists
  bool hasTable(String tag) => _tables.containsKey(tag);

  /// A view of table [tag] that cannot read outside the table. Throws
  /// [FormatException] if the font has no such table.
  ByteData table(String tag) {
    final entry = getTable(tag);
    if (entry == null) throw FormatException('Missing $tag table');
    return ByteData.sublistView(
      _data,
      entry.offset,
      entry.offset + entry.length,
    );
  }

  /// Read font header (head table)
  TtfHeadTable readHeadTable() {
    final data = table('head');
    return TtfHeadTable(
      majorVersion: data.getUint16(0),
      minorVersion: data.getUint16(2),
      fontRevision: _readFixed(data, 4),
      checkSumAdjustment: data.getUint32(8),
      magicNumber: data.getUint32(12),
      flags: data.getUint16(16),
      unitsPerEm: data.getUint16(18),
      created: _readLongDateTime(data, 20),
      modified: _readLongDateTime(data, 28),
      xMin: data.getInt16(36),
      yMin: data.getInt16(38),
      xMax: data.getInt16(40),
      yMax: data.getInt16(42),
      macStyle: data.getUint16(44),
      lowestRecPPEM: data.getUint16(46),
      fontDirectionHint: data.getInt16(48),
      indexToLocFormat: data.getInt16(50),
      glyphDataFormat: data.getInt16(52),
    );
  }

  /// Read horizontal header (hhea table)
  TtfHheaTable readHheaTable() {
    final data = table('hhea');
    return TtfHheaTable(
      majorVersion: data.getUint16(0),
      minorVersion: data.getUint16(2),
      ascender: data.getInt16(4),
      descender: data.getInt16(6),
      lineGap: data.getInt16(8),
      advanceWidthMax: data.getUint16(10),
      minLeftSideBearing: data.getInt16(12),
      minRightSideBearing: data.getInt16(14),
      xMaxExtent: data.getInt16(16),
      caretSlopeRise: data.getInt16(18),
      caretSlopeRun: data.getInt16(20),
      caretOffset: data.getInt16(22),
      metricDataFormat: data.getInt16(32),
      numberOfHMetrics: data.getUint16(34),
    );
  }

  /// Read maximum profile (maxp table)
  TtfMaxpTable readMaxpTable() {
    final data = table('maxp');
    final version = _readFixed(data, 0);

    return TtfMaxpTable(
      version: version,
      numGlyphs: data.getUint16(4),
      maxPoints: version >= 1.0 ? data.getUint16(6) : 0,
      maxContours: version >= 1.0 ? data.getUint16(8) : 0,
      maxCompositePoints: version >= 1.0 ? data.getUint16(10) : 0,
      maxCompositeContours: version >= 1.0 ? data.getUint16(12) : 0,
      maxZones: version >= 1.0 ? data.getUint16(14) : 0,
      maxTwilightPoints: version >= 1.0 ? data.getUint16(16) : 0,
      maxStorage: version >= 1.0 ? data.getUint16(18) : 0,
      maxFunctionDefs: version >= 1.0 ? data.getUint16(20) : 0,
      maxInstructionDefs: version >= 1.0 ? data.getUint16(22) : 0,
      maxStackElements: version >= 1.0 ? data.getUint16(24) : 0,
      maxSizeOfInstructions: version >= 1.0 ? data.getUint16(26) : 0,
      maxComponentElements: version >= 1.0 ? data.getUint16(28) : 0,
      maxComponentDepth: version >= 1.0 ? data.getUint16(30) : 0,
    );
  }

  /// Read naming table (name table)
  TtfNameTable readNameTable() {
    final data = table('name');
    final format = data.getUint16(0);
    final count = data.getUint16(2);
    final stringOffset = data.getUint16(4);

    final records = <TtfNameRecord>[];
    var position = 6;

    for (int i = 0; i < count; i++) {
      final platformID = data.getUint16(position);
      final encodingID = data.getUint16(position + 2);
      final languageID = data.getUint16(position + 4);
      final nameID = data.getUint16(position + 6);
      final length = data.getUint16(position + 8);
      final offset = data.getUint16(position + 10);

      // Read the actual string
      final start = stringOffset + offset;
      String name;

      if (platformID == 0 || platformID == 3) {
        // Unicode platform - UTF-16BE
        name = _readUtf16BeString(data, start, length);
      } else if (platformID == 1) {
        // Macintosh platform - typically Mac Roman
        name = _readMacRomanString(data, start, length);
      } else {
        // Other platforms - treat as Latin-1
        name = _readLatin1String(data, start, length);
      }

      records.add(
        TtfNameRecord(
          platformID: platformID,
          encodingID: encodingID,
          languageID: languageID,
          nameID: nameID,
          length: length,
          offset: offset,
          name: name,
        ),
      );

      position += 12;
    }

    return TtfNameTable(
      format: format,
      count: count,
      stringOffset: stringOffset,
      records: records,
    );
  }

  /// Read character to glyph mapping (cmap table)
  TtfCmapTable readCmapTable() {
    final data = table('cmap');
    final version = data.getUint16(0);
    final numTables = data.getUint16(2);

    final subtables = <TtfCmapSubtable>[];
    var position = 4;

    for (int i = 0; i < numTables; i++) {
      final platformID = data.getUint16(position);
      final encodingID = data.getUint16(position + 2);
      final offset = data.getUint32(position + 4);

      // Read subtable format
      final start = offset;
      final format = data.getUint16(start);

      Map<int, int>? mapping;
      List<int> groups = const [];

      // Parse different cmap formats
      switch (format) {
        case 0:
          mapping = _parseCmapFormat0(data, start);
          break;
        case 4:
          mapping = _parseCmapFormat4(data, start);
          break;
        case 12:
          groups = _parseCmapFormat12(data, start);
          mapping = const {};
          break;
        default:
          // Unsupported format, skip
          break;
      }

      if (mapping != null) {
        subtables.add(
          TtfCmapSubtable(
            platformID: platformID,
            encodingID: encodingID,
            format: format,
            charMap: mapping,
            groups: groups,
          ),
        );
      }

      position += 8;
    }

    return TtfCmapTable(
      version: version,
      numTables: numTables,
      subtables: subtables,
    );
  }

  /// Read horizontal metrics (hmtx table)
  List<TtfHorizontalMetric> readHmtxTable(int numberOfHMetrics, int numGlyphs) {
    final data = table('hmtx');
    final metrics = <TtfHorizontalMetric>[];
    var offset = 0;

    // Read longHorMetric records
    for (int i = 0; i < numberOfHMetrics; i++) {
      final advanceWidth = data.getUint16(offset);
      final bearing = data.getInt16(offset + 2);
      metrics.add(
        TtfHorizontalMetric(
          advanceWidth: advanceWidth,
          leftSideBearing: bearing,
        ),
      );
      offset += 4;
    }

    // Read additional left side bearings
    final last = metrics.isNotEmpty ? metrics.last.advanceWidth : 0;
    for (int i = numberOfHMetrics; i < numGlyphs; i++) {
      final bearing = data.getInt16(offset);
      metrics.add(
        TtfHorizontalMetric(advanceWidth: last, leftSideBearing: bearing),
      );
      offset += 2;
    }

    return metrics;
  }

  // Helper methods for reading data types

  int _readUint8(int offset) => _data.getUint8(offset);

  int _readUint16(int offset) => _data.getUint16(offset);

  int _readUint32(int offset) => _data.getUint32(offset);

  double _readFixed(ByteData data, int offset) {
    final value = data.getInt32(offset);
    return value / 65536.0;
  }

  DateTime _readLongDateTime(ByteData data, int offset) {
    final high = data.getUint32(offset);
    final low = data.getUint32(offset + 4);
    final seconds = (high << 32) | low;
    // Mac epoch (1904-01-01) to Unix epoch (1970-01-01) is 2082844800 seconds
    return DateTime.fromMillisecondsSinceEpoch((seconds - 2082844800) * 1000);
  }

  String _readString(int offset, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add(_readUint8(offset + i));
    }
    return String.fromCharCodes(bytes);
  }

  String _readUtf16BeString(ByteData data, int offset, int length) {
    final units = <int>[];
    for (int i = 0; i < length; i += 2) {
      final high = data.getUint8(offset + i);
      final low = data.getUint8(offset + i + 1);
      units.add((high << 8) | low);
    }
    return String.fromCharCodes(units);
  }

  String _readLatin1String(ByteData data, int offset, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add(data.getUint8(offset + i));
    }
    return latin1.decode(bytes);
  }

  String _readMacRomanString(ByteData data, int offset, int length) {
    // Simplified Mac Roman decoding - treat as Latin-1 for now
    return _readLatin1String(data, offset, length);
  }

  // Cmap format parsing methods

  Map<int, int> _parseCmapFormat0(ByteData data, int offset) {
    final mapping = <int, int>{};
    // Table length is not used

    for (int i = 0; i < 256; i++) {
      final glyph = data.getUint8(offset + 6 + i);
      if (glyph != 0) {
        mapping[i] = glyph;
      }
    }

    return mapping;
  }

  Map<int, int> _parseCmapFormat4(ByteData data, int offset) {
    final mapping = <int, int>{};
    // Table length is not used
    final segCount = data.getUint16(offset + 6) ~/ 2;

    final endCodes = <int>[];
    final startCodes = <int>[];
    final idDeltas = <int>[];
    final idRangeOffsets = <int>[];

    // Read endCode array
    var position = offset + 14;
    for (int i = 0; i < segCount; i++) {
      endCodes.add(data.getUint16(position));
      position += 2;
    }

    // Skip reserved pad
    position += 2;

    // Read startCode array
    for (int i = 0; i < segCount; i++) {
      startCodes.add(data.getUint16(position));
      position += 2;
    }

    // Read idDelta array
    for (int i = 0; i < segCount; i++) {
      idDeltas.add(data.getInt16(position));
      position += 2;
    }

    // Read idRangeOffset array
    final idRangeOffsetStart = position;
    for (int i = 0; i < segCount; i++) {
      idRangeOffsets.add(data.getUint16(position));
      position += 2;
    }

    // Process segments
    for (int i = 0; i < segCount; i++) {
      final startCode = startCodes[i];
      final endCode = endCodes[i];
      final idDelta = idDeltas[i];
      final idRangeOffset = idRangeOffsets[i];

      if (startCode <= endCode) {
        for (int c = startCode; c <= endCode; c++) {
          int glyph;

          if (idRangeOffset == 0) {
            glyph = (c + idDelta) & 0xFFFF;
          } else {
            final location =
                idRangeOffsetStart +
                i * 2 +
                idRangeOffset +
                (c - startCode) * 2;
            glyph = data.getUint16(location);
            if (glyph != 0) {
              glyph = (glyph + idDelta) & 0xFFFF;
            }
          }

          if (glyph != 0) {
            mapping[c] = glyph;
          }
        }
      }
    }

    return mapping;
  }

  /// Reads the groups of a format 12 subtable as sorted (start, end, start
  /// glyph) triples. The group count is clamped to the groups that fit in
  /// the subtable, and groups that end before they start are dropped.
  Uint32List _parseCmapFormat12(ByteData data, int offset) {
    final length = min(data.getUint32(offset + 4), data.lengthInBytes - offset);
    final count = min(data.getUint32(offset + 12), max(0, (length - 16) ~/ 12));

    final groups = <(int, int, int)>[];
    var position = offset + 16;
    for (int i = 0; i < count; i++) {
      final startCharCode = data.getUint32(position);
      final endCharCode = data.getUint32(position + 4);
      final startGlyphID = data.getUint32(position + 8);
      if (startCharCode <= endCharCode) {
        groups.add((startCharCode, endCharCode, startGlyphID));
      }
      position += 12;
    }
    groups.sort((a, b) => a.$1.compareTo(b.$1));

    return Uint32List.fromList([
      for (final (start, end, glyph) in groups) ...[start, end, glyph],
    ]);
  }
}
