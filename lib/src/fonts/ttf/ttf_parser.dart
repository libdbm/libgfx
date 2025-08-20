import 'dart:convert';
import 'dart:typed_data';

import '../font_error_messages.dart';
import 'ttf_tables.dart';

/// TrueType font parser for reading TTF/OTF font files
class TTFParser {
  late final ByteData _data;
  late final Map<String, TtfTable> _tables;

  TTFParser(Uint8List fontData) {
    _data = ByteData.sublistView(fontData);
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

    // Parse table directory (starts at offset 12)
    var offset = 12;
    for (int i = 0; i < numTables; i++) {
      final tag = _readString(offset, 4);
      final checkSum = _readUint32(offset + 4);
      final tableOffset = _readUint32(offset + 8);
      final length = _readUint32(offset + 12);

      _tables[tag] = TtfTable(
        tag: tag,
        checkSum: checkSum,
        offset: tableOffset,
        length: length,
      );

      offset += 16;
    }
  }

  /// Get a specific table by tag
  TtfTable? getTable(String tag) => _tables[tag];

  /// Check if a table exists
  bool hasTable(String tag) => _tables.containsKey(tag);

  /// Get all table tags
  List<String> get tableTags => _tables.keys.toList();

  /// Read font header (head table)
  TtfHeadTable readHeadTable() {
    final table = getTable('head');
    if (table == null) throw FormatException('Missing head table');

    final offset = table.offset;
    return TtfHeadTable(
      majorVersion: _readUint16(offset),
      minorVersion: _readUint16(offset + 2),
      fontRevision: _readFixed(offset + 4),
      checkSumAdjustment: _readUint32(offset + 8),
      magicNumber: _readUint32(offset + 12),
      flags: _readUint16(offset + 16),
      unitsPerEm: _readUint16(offset + 18),
      created: _readLongDateTime(offset + 20),
      modified: _readLongDateTime(offset + 28),
      xMin: _readInt16(offset + 36),
      yMin: _readInt16(offset + 38),
      xMax: _readInt16(offset + 40),
      yMax: _readInt16(offset + 42),
      macStyle: _readUint16(offset + 44),
      lowestRecPPEM: _readUint16(offset + 46),
      fontDirectionHint: _readInt16(offset + 48),
      indexToLocFormat: _readInt16(offset + 50),
      glyphDataFormat: _readInt16(offset + 52),
    );
  }

  /// Read horizontal header (hhea table)
  TtfHheaTable readHheaTable() {
    final table = getTable('hhea');
    if (table == null) throw FormatException('Missing hhea table');

    final offset = table.offset;
    return TtfHheaTable(
      majorVersion: _readUint16(offset),
      minorVersion: _readUint16(offset + 2),
      ascender: _readInt16(offset + 4),
      descender: _readInt16(offset + 6),
      lineGap: _readInt16(offset + 8),
      advanceWidthMax: _readUint16(offset + 10),
      minLeftSideBearing: _readInt16(offset + 12),
      minRightSideBearing: _readInt16(offset + 14),
      xMaxExtent: _readInt16(offset + 16),
      caretSlopeRise: _readInt16(offset + 18),
      caretSlopeRun: _readInt16(offset + 20),
      caretOffset: _readInt16(offset + 22),
      metricDataFormat: _readInt16(offset + 32),
      numberOfHMetrics: _readUint16(offset + 34),
    );
  }

  /// Read maximum profile (maxp table)
  TtfMaxpTable readMaxpTable() {
    final table = getTable('maxp');
    if (table == null) throw FormatException('Missing maxp table');

    final offset = table.offset;
    final version = _readFixed(offset);

    return TtfMaxpTable(
      version: version,
      numGlyphs: _readUint16(offset + 4),
      maxPoints: version >= 1.0 ? _readUint16(offset + 6) : 0,
      maxContours: version >= 1.0 ? _readUint16(offset + 8) : 0,
      maxCompositePoints: version >= 1.0 ? _readUint16(offset + 10) : 0,
      maxCompositeContours: version >= 1.0 ? _readUint16(offset + 12) : 0,
      maxZones: version >= 1.0 ? _readUint16(offset + 14) : 0,
      maxTwilightPoints: version >= 1.0 ? _readUint16(offset + 16) : 0,
      maxStorage: version >= 1.0 ? _readUint16(offset + 18) : 0,
      maxFunctionDefs: version >= 1.0 ? _readUint16(offset + 20) : 0,
      maxInstructionDefs: version >= 1.0 ? _readUint16(offset + 22) : 0,
      maxStackElements: version >= 1.0 ? _readUint16(offset + 24) : 0,
      maxSizeOfInstructions: version >= 1.0 ? _readUint16(offset + 26) : 0,
      maxComponentElements: version >= 1.0 ? _readUint16(offset + 28) : 0,
      maxComponentDepth: version >= 1.0 ? _readUint16(offset + 30) : 0,
    );
  }

  /// Read naming table (name table)
  TtfNameTable readNameTable() {
    final table = getTable('name');
    if (table == null) throw FormatException('Missing name table');

    final offset = table.offset;
    final format = _readUint16(offset);
    final count = _readUint16(offset + 2);
    final stringOffset = _readUint16(offset + 4);

    final records = <TtfNameRecord>[];
    var recordOffset = offset + 6;

    for (int i = 0; i < count; i++) {
      final platformID = _readUint16(recordOffset);
      final encodingID = _readUint16(recordOffset + 2);
      final languageID = _readUint16(recordOffset + 4);
      final nameID = _readUint16(recordOffset + 6);
      final stringLength = _readUint16(recordOffset + 8);
      final nameOffset = _readUint16(recordOffset + 10);

      // Read the actual string
      final stringStart = offset + stringOffset + nameOffset;
      String nameString;

      if (platformID == 0 || platformID == 3) {
        // Unicode platform - UTF-16BE
        nameString = _readUtf16BeString(stringStart, stringLength);
      } else if (platformID == 1) {
        // Macintosh platform - typically Mac Roman
        nameString = _readMacRomanString(stringStart, stringLength);
      } else {
        // Other platforms - treat as Latin-1
        nameString = _readLatin1String(stringStart, stringLength);
      }

      records.add(
        TtfNameRecord(
          platformID: platformID,
          encodingID: encodingID,
          languageID: languageID,
          nameID: nameID,
          length: stringLength,
          offset: nameOffset,
          name: nameString,
        ),
      );

      recordOffset += 12;
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
    final table = getTable('cmap');
    if (table == null) throw FormatException('Missing cmap table');

    final offset = table.offset;
    final version = _readUint16(offset);
    final numTables = _readUint16(offset + 2);

    final subtables = <TtfCmapSubtable>[];
    var subtableOffset = offset + 4;

    for (int i = 0; i < numTables; i++) {
      final platformID = _readUint16(subtableOffset);
      final encodingID = _readUint16(subtableOffset + 2);
      final cmapOffset = _readUint32(subtableOffset + 4);

      // Read subtable format
      final subtableStart = offset + cmapOffset;
      final format = _readUint16(subtableStart);

      Map<int, int>? charMap;

      // Parse different cmap formats
      switch (format) {
        case 0:
          charMap = _parseCmapFormat0(subtableStart);
          break;
        case 4:
          charMap = _parseCmapFormat4(subtableStart);
          break;
        case 12:
          charMap = _parseCmapFormat12(subtableStart);
          break;
        default:
          // Unsupported format, skip
          break;
      }

      if (charMap != null) {
        subtables.add(
          TtfCmapSubtable(
            platformID: platformID,
            encodingID: encodingID,
            format: format,
            charMap: charMap,
          ),
        );
      }

      subtableOffset += 8;
    }

    return TtfCmapTable(
      version: version,
      numTables: numTables,
      subtables: subtables,
    );
  }

  /// Read horizontal metrics (hmtx table)
  List<TtfHorizontalMetric> readHmtxTable(int numberOfHMetrics, int numGlyphs) {
    final table = getTable('hmtx');
    if (table == null) throw FormatException('Missing hmtx table');

    final metrics = <TtfHorizontalMetric>[];
    var offset = table.offset;

    // Read longHorMetric records
    for (int i = 0; i < numberOfHMetrics; i++) {
      final advanceWidth = _readUint16(offset);
      final lsb = _readInt16(offset + 2);
      metrics.add(
        TtfHorizontalMetric(advanceWidth: advanceWidth, leftSideBearing: lsb),
      );
      offset += 4;
    }

    // Read additional left side bearings
    final lastAdvanceWidth = metrics.isNotEmpty ? metrics.last.advanceWidth : 0;
    for (int i = numberOfHMetrics; i < numGlyphs; i++) {
      final lsb = _readInt16(offset);
      metrics.add(
        TtfHorizontalMetric(
          advanceWidth: lastAdvanceWidth,
          leftSideBearing: lsb,
        ),
      );
      offset += 2;
    }

    return metrics;
  }

  // Helper methods for reading data types

  int readUint8(int offset) => _data.getUint8(offset);

  int readInt8(int offset) => _data.getInt8(offset);

  int readUint16(int offset) => _data.getUint16(offset);

  int readInt16(int offset) => _data.getInt16(offset);

  int readUint32(int offset) => _data.getUint32(offset);

  int readInt32(int offset) => _data.getInt32(offset);

  // Private aliases for internal use
  int _readUint8(int offset) => readUint8(offset);

  // _readInt8 was removed as it was unused

  int _readUint16(int offset) => readUint16(offset);

  int _readInt16(int offset) => readInt16(offset);

  int _readUint32(int offset) => readUint32(offset);

  int _readInt32(int offset) => readInt32(offset);

  double _readFixed(int offset) {
    final value = _readInt32(offset);
    return value / 65536.0;
  }

  DateTime _readLongDateTime(int offset) {
    final high = _readUint32(offset);
    final low = _readUint32(offset + 4);
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

  String _readUtf16BeString(int offset, int length) {
    final codeUnits = <int>[];
    for (int i = 0; i < length; i += 2) {
      final high = _readUint8(offset + i);
      final low = _readUint8(offset + i + 1);
      codeUnits.add((high << 8) | low);
    }
    return String.fromCharCodes(codeUnits);
  }

  String _readLatin1String(int offset, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add(_readUint8(offset + i));
    }
    return latin1.decode(bytes);
  }

  String _readMacRomanString(int offset, int length) {
    // Simplified Mac Roman decoding - treat as Latin-1 for now
    return _readLatin1String(offset, length);
  }

  // Cmap format parsing methods

  Map<int, int> _parseCmapFormat0(int offset) {
    final charMap = <int, int>{};
    // Table length is not used

    for (int i = 0; i < 256; i++) {
      final glyphIndex = _readUint8(offset + 6 + i);
      if (glyphIndex != 0) {
        charMap[i] = glyphIndex;
      }
    }

    return charMap;
  }

  Map<int, int> _parseCmapFormat4(int offset) {
    final charMap = <int, int>{};
    // Table length is not used
    final segCount = _readUint16(offset + 6) ~/ 2;

    final endCodes = <int>[];
    final startCodes = <int>[];
    final idDeltas = <int>[];
    final idRangeOffsets = <int>[];

    // Read endCode array
    var currentOffset = offset + 14;
    for (int i = 0; i < segCount; i++) {
      endCodes.add(_readUint16(currentOffset));
      currentOffset += 2;
    }

    // Skip reserved pad
    currentOffset += 2;

    // Read startCode array
    for (int i = 0; i < segCount; i++) {
      startCodes.add(_readUint16(currentOffset));
      currentOffset += 2;
    }

    // Read idDelta array
    for (int i = 0; i < segCount; i++) {
      idDeltas.add(_readInt16(currentOffset));
      currentOffset += 2;
    }

    // Read idRangeOffset array
    final idRangeOffsetStart = currentOffset;
    for (int i = 0; i < segCount; i++) {
      idRangeOffsets.add(_readUint16(currentOffset));
      currentOffset += 2;
    }

    // Process segments
    for (int i = 0; i < segCount; i++) {
      final startCode = startCodes[i];
      final endCode = endCodes[i];
      final idDelta = idDeltas[i];
      final idRangeOffset = idRangeOffsets[i];

      if (startCode <= endCode) {
        for (int c = startCode; c <= endCode; c++) {
          int glyphIndex;

          if (idRangeOffset == 0) {
            glyphIndex = (c + idDelta) & 0xFFFF;
          } else {
            final glyphOffset =
                idRangeOffsetStart +
                i * 2 +
                idRangeOffset +
                (c - startCode) * 2;
            glyphIndex = _readUint16(glyphOffset);
            if (glyphIndex != 0) {
              glyphIndex = (glyphIndex + idDelta) & 0xFFFF;
            }
          }

          if (glyphIndex != 0) {
            charMap[c] = glyphIndex;
          }
        }
      }
    }

    return charMap;
  }

  Map<int, int> _parseCmapFormat12(int offset) {
    final charMap = <int, int>{};
    // Table length is not used
    final numGroups = _readUint32(offset + 12);

    var groupOffset = offset + 16;
    for (int i = 0; i < numGroups; i++) {
      final startCharCode = _readUint32(groupOffset);
      final endCharCode = _readUint32(groupOffset + 4);
      final startGlyphID = _readUint32(groupOffset + 8);

      for (int c = startCharCode; c <= endCharCode; c++) {
        final glyphIndex = startGlyphID + (c - startCharCode);
        charMap[c] = glyphIndex;
      }

      groupOffset += 12;
    }

    return charMap;
  }
}
