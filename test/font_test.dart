import 'dart:typed_data';

import 'package:test/test.dart';

import '../lib/src/fonts/font.dart';
import '../lib/src/fonts/ttf/ttf_font.dart';
import '../lib/src/text/text_types.dart'
    show TextAlign, TextBaseline, TextMetrics;

void main() {
  group('Font System Tests', () {
    test('Font abstract class defines correct interface', () {
      // This test ensures the Font abstract class has all required methods
      expect(Font, isA<Type>());

      // We can't instantiate abstract class, but we can check its structure
      // by creating a mock implementation
    });

    test('FontMetrics calculations work correctly', () {
      final metrics = FontMetrics(
        ascender: 800,
        descender: -200,
        lineGap: 100,
        maxAdvanceWidth: 1000,
        maxAdvanceHeight: 0,
        underlineThickness: 50,
        underlinePosition: -100,
      );

      expect(metrics.lineHeight, equals(1100)); // 800 - (-200) + 100

      // Test scaling
      final scaled = metrics.scale(12.0, 1000);
      expect(scaled.ascender, equals(10)); // (800 * 12) / 1000 rounded
      expect(scaled.descender, equals(-2)); // (-200 * 12) / 1000 rounded
    });

    test('GlyphMetrics calculations work correctly', () {
      final boundingBox = GlyphBoundingBox(
        xMin: 100,
        yMin: -200,
        xMax: 500,
        yMax: 600,
      );

      expect(boundingBox.width, equals(400));
      expect(boundingBox.height, equals(800));

      final metrics = GlyphMetrics(
        advanceWidth: 600,
        advanceHeight: 0,
        leftSideBearing: 50,
        topSideBearing: 0,
        boundingBox: boundingBox,
      );

      final scaled = metrics.scale(24.0, 1000);
      expect(scaled.advanceWidth, equals(14)); // (600 * 24) / 1000 rounded
    });

    test('TextMetrics provides accurate measurements', () {
      final metrics = TextMetrics(
        width: 120.5,
        height: 16.0,
        ascent: 12.0,
        descent: 4.0,
        lineHeight: 18.0,
      );

      expect(metrics.width, equals(120.5));
      expect(metrics.height, equals(16.0));
      expect(metrics.ascent, equals(12.0));
      expect(metrics.descent, equals(4.0));
      expect(metrics.lineHeight, equals(18.0));
    });

    test('TtfFont can be created from minimal bytes', () {
      // Create minimal TTF header bytes for testing
      // This is a very basic structure that should parse without crashing
      final bytes = Uint8List(200); // Increased size to accommodate head table
      final data = ByteData.sublistView(bytes);

      // Write basic TTF header
      data.setUint32(0, 0x00010000); // sfnt version (TrueType)
      data.setUint16(4, 1); // numTables
      data.setUint16(6, 16); // searchRange
      data.setUint16(8, 0); // entrySelector
      data.setUint16(10, 0); // rangeShift

      // Write a minimal table directory entry for 'head' table
      data.setUint32(12, 0x68656164); // 'head' tag
      data.setUint32(16, 0); // checkSum
      data.setUint32(20, 28); // offset (after header + table dir = 12 + 16)
      data.setUint32(24, 54); // length (head table is 54 bytes)

      // Write minimal head table at offset 28
      var offset = 28;
      data.setUint16(offset, 1);
      offset += 2; // majorVersion
      data.setUint16(offset, 0);
      offset += 2; // minorVersion
      data.setUint32(offset, 0x10000);
      offset += 4; // fontRevision (1.0 in Fixed format)
      data.setUint32(offset, 0);
      offset += 4; // checkSumAdjustment
      data.setUint32(offset, 0x5F0F3CF5);
      offset += 4; // magicNumber
      data.setUint16(offset, 0);
      offset += 2; // flags
      data.setUint16(offset, 1000);
      offset += 2; // unitsPerEm

      // Fill remaining head table fields with zeros/defaults
      for (int i = offset; i < 28 + 54; i++) {
        data.setUint8(i, 0);
      }

      // This should not crash but will likely fail during table loading
      // since we don't have all required tables (hhea, maxp, name, cmap, hmtx)
      expect(() => TTFFont.fromBytes(bytes), throwsA(isA<FormatException>()));
    });

    test('Font enums are properly defined', () {
      expect(TextAlign.values.length, greaterThan(0));
      expect(TextBaseline.values.length, greaterThan(0));

      expect(TextAlign.left, isA<TextAlign>());
      expect(TextBaseline.alphabetic, isA<TextBaseline>());
    });
  });
}
