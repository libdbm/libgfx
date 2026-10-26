/// Base class for all TrueType tables
class TtfTable {
  final String tag;
  final int checkSum;
  final int offset;
  final int length;

  const TtfTable({
    required this.tag,
    required this.checkSum,
    required this.offset,
    required this.length,
  });
}

/// Font header table (head)
class TtfHeadTable {
  final int majorVersion;
  final int minorVersion;
  final double fontRevision;
  final int checkSumAdjustment;
  final int magicNumber;
  final int flags;
  final int unitsPerEm;
  final DateTime created;
  final DateTime modified;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int macStyle;
  final int lowestRecPPEM;
  final int fontDirectionHint;
  final int indexToLocFormat;
  final int glyphDataFormat;

  const TtfHeadTable({
    required this.majorVersion,
    required this.minorVersion,
    required this.fontRevision,
    required this.checkSumAdjustment,
    required this.magicNumber,
    required this.flags,
    required this.unitsPerEm,
    required this.created,
    required this.modified,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.macStyle,
    required this.lowestRecPPEM,
    required this.fontDirectionHint,
    required this.indexToLocFormat,
    required this.glyphDataFormat,
  });

  /// Check if the font uses short loca format
  bool get isShortLocaFormat => indexToLocFormat == 0;
}

/// Horizontal header table (hhea)
class TtfHheaTable {
  final int majorVersion;
  final int minorVersion;
  final int ascender;
  final int descender;
  final int lineGap;
  final int advanceWidthMax;
  final int minLeftSideBearing;
  final int minRightSideBearing;
  final int xMaxExtent;
  final int caretSlopeRise;
  final int caretSlopeRun;
  final int caretOffset;
  final int metricDataFormat;
  final int numberOfHMetrics;

  const TtfHheaTable({
    required this.majorVersion,
    required this.minorVersion,
    required this.ascender,
    required this.descender,
    required this.lineGap,
    required this.advanceWidthMax,
    required this.minLeftSideBearing,
    required this.minRightSideBearing,
    required this.xMaxExtent,
    required this.caretSlopeRise,
    required this.caretSlopeRun,
    required this.caretOffset,
    required this.metricDataFormat,
    required this.numberOfHMetrics,
  });
}

/// Maximum profile table (maxp)
class TtfMaxpTable {
  final double version;
  final int numGlyphs;
  final int maxPoints;
  final int maxContours;
  final int maxCompositePoints;
  final int maxCompositeContours;
  final int maxZones;
  final int maxTwilightPoints;
  final int maxStorage;
  final int maxFunctionDefs;
  final int maxInstructionDefs;
  final int maxStackElements;
  final int maxSizeOfInstructions;
  final int maxComponentElements;
  final int maxComponentDepth;

  const TtfMaxpTable({
    required this.version,
    required this.numGlyphs,
    required this.maxPoints,
    required this.maxContours,
    required this.maxCompositePoints,
    required this.maxCompositeContours,
    required this.maxZones,
    required this.maxTwilightPoints,
    required this.maxStorage,
    required this.maxFunctionDefs,
    required this.maxInstructionDefs,
    required this.maxStackElements,
    required this.maxSizeOfInstructions,
    required this.maxComponentElements,
    required this.maxComponentDepth,
  });
}

/// Naming table (name)
class TtfNameTable {
  final int format;
  final int count;
  final int stringOffset;
  final List<TtfNameRecord> records;

  const TtfNameTable({
    required this.format,
    required this.count,
    required this.stringOffset,
    required this.records,
  });

  /// Get name by ID (e.g., 1 = font family, 2 = font subfamily)
  String? getNameById(int nameID) {
    // Prefer Unicode platform (0) or Microsoft platform (3)
    for (final record in records) {
      if (record.nameID == nameID &&
          (record.platformID == 0 || record.platformID == 3)) {
        return record.name;
      }
    }

    // Fallback to any matching name ID
    for (final record in records) {
      if (record.nameID == nameID) {
        return record.name;
      }
    }

    return null;
  }

  String? get fontFamily => getNameById(1);

  String? get fontSubfamily => getNameById(2);

  String? get fullName => getNameById(4);

  String? get version => getNameById(5);
}

/// Name record in the naming table
class TtfNameRecord {
  final int platformID;
  final int encodingID;
  final int languageID;
  final int nameID;
  final int length;
  final int offset;
  final String name;

  const TtfNameRecord({
    required this.platformID,
    required this.encodingID,
    required this.languageID,
    required this.nameID,
    required this.length,
    required this.offset,
    required this.name,
  });
}

/// Character to glyph mapping table (cmap)
class TtfCmapTable {
  final int version;
  final int numTables;
  final List<TtfCmapSubtable> subtables;

  const TtfCmapTable({
    required this.version,
    required this.numTables,
    required this.subtables,
  });

  /// Get the best Unicode subtable
  TtfCmapSubtable? get unicodeSubtable {
    // A full-repertoire subtable first, since a BMP one cannot map the
    // characters beyond it (emoji, for example)
    for (final subtable in subtables) {
      if (subtable.format == 12 &&
          ((subtable.platformID == 3 && subtable.encodingID == 10) ||
              (subtable.platformID == 0 &&
                  (subtable.encodingID == 4 || subtable.encodingID == 6)))) {
        return subtable;
      }
    }

    // Then platform 0 (Unicode) or platform 3 (Microsoft) with Unicode encoding
    for (final subtable in subtables) {
      if (subtable.platformID == 0 ||
          (subtable.platformID == 3 &&
              (subtable.encodingID == 1 || subtable.encodingID == 10))) {
        return subtable;
      }
    }

    // Fallback to first available subtable
    return subtables.isNotEmpty ? subtables.first : null;
  }

  /// Get glyph index for a character code
  int getGlyphIndex(final int code) {
    final subtable = unicodeSubtable;
    return subtable?.glyph(code) ?? 0;
  }
}

/// Character map subtable
class TtfCmapSubtable {
  final int platformID;
  final int encodingID;
  final int format;

  /// Mapping for formats 0 and 4; empty for format 12.
  final Map<int, int> charMap;

  /// Format 12 groups as (start, end, start glyph) triples, sorted by start;
  /// empty for other formats.
  final List<int> groups;

  const TtfCmapSubtable({
    required this.platformID,
    required this.encodingID,
    required this.format,
    this.charMap = const {},
    this.groups = const [],
  });

  /// Glyph index for character [code], or 0 if it is not mapped.
  int glyph(int code) {
    if (groups.isEmpty) return charMap[code] ?? 0;
    var low = 0;
    var high = groups.length ~/ 3 - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final start = groups[middle * 3];
      if (code < start) {
        high = middle - 1;
      } else if (code > groups[middle * 3 + 1]) {
        low = middle + 1;
      } else {
        return groups[middle * 3 + 2] + code - start;
      }
    }
    return 0;
  }
}

/// Horizontal metrics (hmtx)
class TtfHorizontalMetric {
  final int advanceWidth;
  final int leftSideBearing;

  const TtfHorizontalMetric({
    required this.advanceWidth,
    required this.leftSideBearing,
  });
}

/// Glyph location table (loca)
class TtfLocaTable {
  final List<int> offsets;
  final bool isShortFormat;

  const TtfLocaTable({required this.offsets, required this.isShortFormat});

  /// Get the offset for a specific glyph
  int getGlyphOffset(final int glyph) {
    if (glyph < 0 || glyph >= offsets.length) return 0;
    return offsets[glyph];
  }

  /// Get the length of glyph data
  int getGlyphLength(final int glyph) {
    if (glyph < 0 || glyph >= offsets.length - 1) return 0;
    return offsets[glyph + 1] - offsets[glyph];
  }
}

/// Glyph data table (glyf)
class TtfGlyphData {
  final int numberOfContours;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final List<TtfGlyphContour> contours;
  final List<int> instructions;

  const TtfGlyphData({
    required this.numberOfContours,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.contours,
    required this.instructions,
  });

  bool get isSimpleGlyph => numberOfContours >= 0;
}

/// A single contour in a glyph
class TtfGlyphContour {
  final List<TtfGlyphPoint> points;

  const TtfGlyphContour({required this.points});
}

/// A point in a glyph outline
class TtfGlyphPoint {
  final int x;
  final int y;
  final bool onCurve;

  const TtfGlyphPoint({
    required this.x,
    required this.y,
    required this.onCurve,
  });
}

/// Kerning table (kern)
class TtfKernTable {
  final int version;
  final int numTables;
  final List<TtfKernSubtable> subtables;

  const TtfKernTable({
    required this.version,
    required this.numTables,
    required this.subtables,
  });

  /// Get kerning value for a pair of glyphs
  int getKerning(final int left, final int right) {
    for (final subtable in subtables) {
      final kerning = subtable.getKerning(left, right);
      if (kerning != 0) return kerning;
    }
    return 0;
  }
}

/// Kerning subtable
class TtfKernSubtable {
  final int version;
  final int length;
  final int format;
  final int coverage;
  final Map<int, int> kerningPairs;

  const TtfKernSubtable({
    required this.version,
    required this.length,
    required this.format,
    required this.coverage,
    required this.kerningPairs,
  });

  /// Get kerning for a specific pair
  int getKerning(final int left, final int right) {
    final key = (left << 16) | right;
    return kerningPairs[key] ?? 0;
  }
}
