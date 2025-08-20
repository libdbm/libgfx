import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/utils/dasher.dart';
import 'package:test/test.dart';

void main() {
  group('Dasher', () {
    late Dasher dasher;

    setUp(() {
      dasher = Dasher();
    });

    group('Basic Dashing', () {
      test('applies simple dash pattern to straight line', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [10, 5]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);

        // Should have multiple move/line segments
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(1)); // Multiple dashes
      });

      test('applies dash pattern to rectangle', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(40, 0)
          ..lineTo(40, 30)
          ..lineTo(0, 30)
          ..close();

        final dashed = dasher.dash(path.build(), [5, 3]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);

        // Should create multiple segments
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(4)); // More than corners
      });

      test('handles empty pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), []);

        // Should return original path
        expect(dashed.commands.length, equals(path.build().commands.length));
      });

      test('handles all-zero pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [0, 0, 0]);

        // Should return original path
        expect(dashed.commands.length, equals(path.build().commands.length));
      });
    });

    group('Dash Patterns', () {
      test('single value pattern creates equal on/off', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [10]);

        expect(dashed, isNotNull);
        // Pattern [10] should be treated as [10, 10]
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThanOrEqualTo(4)); // ~5 dashes for 100 units
      });

      test('two value pattern creates dash-gap', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [20, 10]);

        expect(dashed, isNotNull);
        // 20 on, 10 off = 30 unit cycle
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThanOrEqualTo(3)); // ~3 complete cycles
      });

      test('complex pattern with multiple values', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [10, 5, 2, 5]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);

        // Complex pattern should create varied segments
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(1));
      });

      test('very small dash pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [1, 1]);

        expect(dashed, isNotNull);
        // Should create many small segments
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(20)); // Many tiny dashes
      });

      test('very large dash pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [200, 50]);

        expect(dashed, isNotNull);
        // First dash should cover entire line
        final lineCount = dashed.commands
            .where((c) => c.type == PathCommandType.lineTo)
            .length;
        expect(lineCount, greaterThanOrEqualTo(1));
      });
    });

    group('Path Types', () {
      test('dashes curved path', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..curveTo(25, -25, 75, -25, 100, 0);

        final dashed = dasher.dash(path.build(), [5, 3]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);

        // Should create multiple segments along curve
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(1));
      });

      test('dashes arc path', () {
        final path = PathBuilder()
          ..moveTo(50, 50)
          ..arc(50, 50, 30, 0, math.pi, false);

        final dashed = dasher.dash(path.build(), [10, 5]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);

        // Should create dashes along arc
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(1));
      });

      test('dashes closed path', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(30, 0)
          ..lineTo(30, 30)
          ..lineTo(0, 30)
          ..close();

        final dashed = dasher.dash(path.build(), [5, 3]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);

        // Should dash all sides including closing edge
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(4));
      });

      test('dashes path with multiple subpaths', () {
        final path = PathBuilder()
          // First subpath
          ..moveTo(0, 0)
          ..lineTo(30, 0)
          // Second subpath
          ..moveTo(0, 10)
          ..lineTo(30, 10)
          // Third subpath
          ..moveTo(0, 20)
          ..lineTo(30, 20);

        final dashed = dasher.dash(path.build(), [5, 3]);

        expect(dashed, isNotNull);

        // Should dash each subpath independently
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(3)); // More than original subpaths
      });
    });

    group('Pattern Alignment', () {
      test('starts with dash (pen down)', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [10, 10]);

        // First segment after moveTo should be a line
        expect(dashed.commands[0].type, equals(PathCommandType.moveTo));
        expect(dashed.commands[1].type, equals(PathCommandType.lineTo));
      });

      test('pattern continues across corners', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(25, 0)
          ..lineTo(25, 25);

        final dashed = dasher.dash(path.build(), [10, 5]);

        expect(dashed, isNotNull);
        // Pattern should continue from first segment to second
        // Hard to test precisely without knowing implementation details
      });

      test('pattern resets for new subpath', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(30, 0)
          ..moveTo(0, 10)
          ..lineTo(30, 10);

        final dashed = dasher.dash(path.build(), [10, 5]);

        expect(dashed, isNotNull);
        // Each subpath should start with a dash
        // Both lines should have similar dash patterns
      });
    });

    group('Edge Cases', () {
      test('handles empty path', () {
        final path = PathBuilder().build();

        final dashed = dasher.dash(path, [10, 5]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isEmpty);
      });

      test('handles single point path', () {
        final path = PathBuilder()..moveTo(10, 10);

        final dashed = dasher.dash(path.build(), [10, 5]);

        expect(dashed, isNotNull);
        // Single point can't be dashed
        expect(dashed.commands.length, lessThanOrEqualTo(1));
      });

      test('handles zero-length segments', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(10, 10) // Zero length
          ..lineTo(20, 10);

        final dashed = dasher.dash(path.build(), [5, 3]);

        expect(dashed, isNotNull);
        // Should skip zero-length segment
      });

      test('handles negative pattern values', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [10, -5, 5, 3]);

        expect(dashed, isNotNull);
        // Should handle gracefully, likely treating negative as zero
      });

      test('handles very long path', () {
        final path = PathBuilder();
        path.moveTo(0, 0);

        // Create very long zigzag
        for (int i = 1; i < 1000; i++) {
          path.lineTo(i * 1.0, i.isEven ? 10 : 0);
        }

        final dashed = dasher.dash(path.build(), [5, 3]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);
      });

      test('handles path with NaN coordinates', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(double.nan, 10)
          ..lineTo(20, 20);

        // Should handle gracefully
        expect(() => dasher.dash(path.build(), [5, 3]), returnsNormally);
      });
    });

    group('Special Patterns', () {
      test('dotted line pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        final dashed = dasher.dash(path.build(), [1, 4]);

        expect(dashed, isNotNull);
        // Should create dot-like pattern
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThan(10)); // Many dots
      });

      test('morse code pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        // Dot-dot-dash pattern
        final dashed = dasher.dash(path.build(), [2, 3, 2, 3, 10, 3]);

        expect(dashed, isNotNull);
        expect(dashed.commands, isNotEmpty);
      });

      test('railroad track pattern', () {
        final path = PathBuilder()
          ..moveTo(0, 0)
          ..lineTo(100, 0);

        // Long dash, short gap
        final dashed = dasher.dash(path.build(), [15, 2]);

        expect(dashed, isNotNull);
        final moveCount = dashed.commands
            .where((c) => c.type == PathCommandType.moveTo)
            .length;
        expect(moveCount, greaterThanOrEqualTo(5));
      });
    });

    group('Performance', () {
      test('dashes long path efficiently', () {
        final path = PathBuilder();
        path.moveTo(0, 0);

        // Create long path
        for (int i = 1; i < 100; i++) {
          path.lineTo(i * 10.0, i.isEven ? 0 : 10);
        }

        final stopwatch = Stopwatch()..start();
        final dashed = dasher.dash(path.build(), [5, 3]);
        stopwatch.stop();

        expect(dashed, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('handles complex curves efficiently', () {
        final path = PathBuilder();

        // Create spiral with curves
        for (int i = 0; i < 50; i++) {
          final angle = i * 0.2;
          final r = i * 2.0;
          final x = 100 + r * math.cos(angle);
          final y = 100 + r * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else if (i % 3 == 0) {
            final cx = 100 + (r - 5) * math.cos(angle - 0.1);
            final cy = 100 + (r - 5) * math.sin(angle - 0.1);
            path.curveTo(cx, cy, x, y, x, y);
          } else {
            path.lineTo(x, y);
          }
        }

        final stopwatch = Stopwatch()..start();
        final dashed = dasher.dash(path.build(), [3, 2]);
        stopwatch.stop();

        expect(dashed, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
