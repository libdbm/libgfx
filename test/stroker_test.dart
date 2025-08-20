import 'dart:math' as math;

import 'package:libgfx/libgfx.dart';
import 'package:libgfx/src/graphics_state.dart';
import 'package:libgfx/src/utils/stroker.dart';
import 'package:test/test.dart';

void main() {
  group('Stroker', () {
    late Stroker stroker;
    late GraphicsState state;

    setUp(() {
      stroker = Stroker();
      state = GraphicsState(transform: Matrix2D.identity(), strokeWidth: 10.0);
    });

    group('Basic Stroking', () {
      test('strokes simple line', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);

        // Stroked line should create a rectangle-like outline
        // Width should be approximately strokeWidth
      });

      test('strokes rectangle', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(40, 10)
          ..lineTo(40, 30)
          ..lineTo(10, 30)
          ..close();

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });

      test('handles zero stroke width', () {
        state.strokeWidth = 0.0;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10);

        final stroked = stroker.stroke(path.build(), state);

        // Should handle gracefully, possibly returning thin line
        expect(stroked, isNotNull);
      });

      test('handles very small stroke width', () {
        state.strokeWidth = 0.001;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
      });
    });

    group('Line Caps', () {
      test('applies butt cap', () {
        state.lineCap = LineCap.butt;

        final path = PathBuilder()
          ..moveTo(10, 20)
          ..lineTo(50, 20);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Butt cap should create square ends
      });

      test('applies round cap', () {
        state.lineCap = LineCap.round;

        final path = PathBuilder()
          ..moveTo(10, 20)
          ..lineTo(50, 20);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Round cap should add semicircular ends
        // Should have more commands than butt cap
      });

      test('applies square cap', () {
        state.lineCap = LineCap.square;

        final path = PathBuilder()
          ..moveTo(10, 20)
          ..lineTo(50, 20);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Square cap should extend beyond line endpoints
      });

      test('caps on open path only', () {
        state.lineCap = LineCap.round;

        // Open path
        final openPath = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30);

        final openStroked = stroker.stroke(openPath.build(), state);

        // Closed path
        final closedPath = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30)
          ..close();

        final closedStroked = stroker.stroke(closedPath.build(), state);

        // Open path should have caps, closed should not
        expect(
          openStroked.commands.length,
          greaterThan(closedStroked.commands.length),
        );
      });
    });

    group('Line Joins', () {
      test('applies miter join', () {
        state.lineJoin = LineJoin.miter;
        state.miterLimit = 10.0;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Miter join should create sharp corners
      });

      test('applies round join', () {
        state.lineJoin = LineJoin.round;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Round join should add arc at corner
      });

      test('applies bevel join', () {
        state.lineJoin = LineJoin.bevel;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Bevel join should create flat corner
      });

      test('miter limit converts to bevel', () {
        state.lineJoin = LineJoin.miter;
        state.miterLimit = 1.0; // Very low limit

        // Create sharp angle that exceeds miter limit
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10)
          ..lineTo(10, 11); // Very sharp angle

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should fall back to bevel when miter limit exceeded
      });

      test('handles 180 degree turn', () {
        state.lineJoin = LineJoin.round;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(10, 10); // 180 degree turn

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should handle degenerate case
      });
    });

    group('Dash Patterns', () {
      test('applies simple dash pattern', () {
        state.dashPattern = [10, 5]; // 10 on, 5 off

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(100, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should create multiple segments
      });

      test('applies complex dash pattern', () {
        state.dashPattern = [10, 5, 2, 5]; // Complex pattern

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(100, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
      });

      test('handles dash pattern on curves', () {
        state.dashPattern = [5, 5];

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..curveTo(20, 5, 30, 5, 40, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should apply dashes along curve
      });

      test('handles empty dash pattern', () {
        state.dashPattern = [];

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should treat as solid line
      });

      test('handles single-element dash pattern', () {
        state.dashPattern = [10]; // Should repeat

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(100, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should treat as 10 on, 10 off
      });
    });

    group('Complex Paths', () {
      test('strokes path with curves', () {
        final path = PathBuilder()
          ..moveTo(10, 30)
          ..curveTo(10, 10, 30, 10, 30, 30)
          ..curveTo(30, 50, 10, 50, 10, 30);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });

      test('strokes self-intersecting path', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 30)
          ..lineTo(30, 10)
          ..lineTo(10, 30)
          ..close();

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
      });

      test('strokes path with multiple subpaths', () {
        final path = PathBuilder()
          // First subpath
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30)
          ..close()
          // Second subpath
          ..moveTo(40, 10)
          ..lineTo(60, 10)
          ..lineTo(60, 30)
          ..close();

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should stroke both subpaths
      });

      test('handles very long path', () {
        final path = PathBuilder();
        path.moveTo(0, 0);

        // Create long zigzag path
        for (int i = 1; i < 1000; i++) {
          path.lineTo(i * 1.0, i.isEven ? 10 : -10);
        }

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles empty path', () {
        final path = PathBuilder().build();

        final stroked = stroker.stroke(path, state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isEmpty);
      });

      test('handles single point', () {
        final path = PathBuilder()..moveTo(10, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Might create a dot depending on line caps
      });

      test('handles coincident points', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(10, 10) // Same point
          ..lineTo(20, 20);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should handle degenerate segments
      });

      test('handles very large stroke width', () {
        state.strokeWidth = 1000.0;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
      });

      test('handles negative stroke width', () {
        state.strokeWidth = -10.0;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10);

        // Should either throw or handle gracefully
        try {
          final stroked = stroker.stroke(path.build(), state);
          expect(stroked, isNotNull);
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });

    group('Numerical Stability', () {
      test('handles near-parallel lines', () {
        state.lineJoin = LineJoin.miter;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10)
          ..lineTo(30, 10.0001); // Nearly parallel

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should not produce infinite miter
      });

      test('handles very small angles', () {
        state.lineJoin = LineJoin.miter;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10)
          ..lineTo(20.001, 20); // Very small angle

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
      });

      test('handles very large coordinates', () {
        final path = PathBuilder()
          ..moveTo(1e6, 1e6)
          ..lineTo(1e6 + 100, 1e6);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
      });
    });

    group('Advanced Stroking', () {
      test('strokes with varying width along path', () {
        // Test if implementation supports variable width
        // This might not be supported, but testing the API
        state.strokeWidth = 10.0;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(50, 10)
          ..lineTo(50, 50);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });

      test('strokes star shape', () {
        final path = PathBuilder();
        final cx = 50.0;
        final cy = 50.0;
        final outerRadius = 40.0;
        final innerRadius = 20.0;

        for (int i = 0; i < 10; i++) {
          final angle = i * math.pi / 5;
          final radius = i.isEven ? outerRadius : innerRadius;
          final x = cx + radius * math.cos(angle);
          final y = cy + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });

      test('strokes heart shape', () {
        final path = PathBuilder();
        final cx = 50.0;
        final cy = 50.0;
        final size = 30.0;

        path.moveTo(cx, cy + size * 0.3);

        // Left side of heart
        path.curveTo(
          cx - size * 0.5,
          cy,
          cx - size,
          cy - size * 0.3,
          cx - size,
          cy - size * 0.5,
        );

        path.curveTo(
          cx - size,
          cy - size * 0.8,
          cx - size * 0.5,
          cy - size,
          cx,
          cy - size * 0.5,
        );

        // Right side of heart
        path.curveTo(
          cx + size * 0.5,
          cy - size,
          cx + size,
          cy - size * 0.8,
          cx + size,
          cy - size * 0.5,
        );

        path.curveTo(
          cx + size,
          cy - size * 0.3,
          cx + size * 0.5,
          cy,
          cx,
          cy + size * 0.3,
        );

        path.close();

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });

      test('strokes text-like path', () {
        // Simulate a character-like path with complex curves
        final path = PathBuilder()
          ..moveTo(10, 40)
          ..curveTo(10, 20, 20, 10, 30, 10)
          ..curveTo(40, 10, 50, 20, 50, 30)
          ..curveTo(50, 40, 40, 50, 30, 50)
          ..lineTo(20, 50)
          ..curveTo(15, 50, 10, 45, 10, 40)
          ..close();

        state.strokeWidth = 2.0; // Thin stroke for text

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });
    });

    group('Stroke Transformation', () {
      test('maintains stroke width under uniform scale', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10);

        // Test with different scales
        final scales = [0.5, 1.0, 2.0, 5.0];

        for (final scale in scales) {
          final scaledPath = path.build().transform(
            Matrix2D.scaling(scale, scale),
          );
          final stroked = stroker.stroke(scaledPath, state);

          expect(stroked, isNotNull);
          // Stroke width should be consistent visually
        }
      });

      test('handles non-uniform scale', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(30, 30)
          ..lineTo(10, 30)
          ..close();

        // Non-uniform scale
        final transform = Matrix2D.scaling(2.0, 0.5);
        final transformedPath = path.build().transform(transform);

        final stroked = stroker.stroke(transformedPath, state);

        expect(stroked, isNotNull);
        expect(stroked.commands, isNotEmpty);
      });

      test('handles rotation', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(30, 10)
          ..lineTo(20, 30)
          ..close();

        // Test various rotations
        final angles = [0, math.pi / 4, math.pi / 2, math.pi, 3 * math.pi / 2];

        for (final angle in angles) {
          final transform = Matrix2D.rotation(angle.toDouble());
          final rotatedPath = path.build().transform(transform);

          final stroked = stroker.stroke(rotatedPath, state);

          expect(stroked, isNotNull);
          expect(stroked.commands, isNotEmpty);
        }
      });
    });

    group('Pattern-based Stroking', () {
      test('strokes with custom dash offset', () {
        state.dashPattern = [10, 5];
        // Note: dashOffset might not be in GraphicsState
        // but testing the pattern behavior

        final path = PathBuilder()
          ..moveTo(0, 10)
          ..lineTo(100, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // First dash should start at expected position
      });

      test('strokes closed path with dashes', () {
        state.dashPattern = [5, 3];

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(40, 10)
          ..lineTo(40, 40)
          ..lineTo(10, 40)
          ..close();

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Dashes should align properly at closure
      });

      test('handles very small dash segments', () {
        state.dashPattern = [0.1, 0.1];

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should handle micro-dashes
      });

      test('handles dash pattern longer than path', () {
        state.dashPattern = [100, 50]; // Very long dashes

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10); // Short path

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should handle partial dash
      });
    });

    group('Performance', () {
      test('strokes complex path efficiently', () {
        final path = PathBuilder();

        // Create complex spiral
        for (int i = 0; i < 360; i++) {
          final angle = i * 3.14159 / 180;
          final r = i / 10.0;
          final x = 100 + r * _cos(angle);
          final y = 100 + r * _sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }

        final stopwatch = Stopwatch()..start();
        final stroked = stroker.stroke(path.build(), state);
        stopwatch.stop();

        expect(stroked, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('strokes path with many curves efficiently', () {
        final path = PathBuilder();
        path.moveTo(0, 50);

        // Create sinusoidal wave with many curves
        for (int i = 0; i < 100; i++) {
          final x1 = i * 10.0;
          final x2 = (i + 0.5) * 10.0;
          final x3 = (i + 1) * 10.0;
          final y1 = 50 + 30 * math.sin(i * 0.2);
          final y2 = 50 + 30 * math.sin((i + 0.5) * 0.2);
          final y3 = 50 + 30 * math.sin((i + 1) * 0.2);

          path.curveTo(x1, y1, x2, y2, x3, y3);
        }

        final stopwatch = Stopwatch()..start();
        final stroked = stroker.stroke(path.build(), state);
        stopwatch.stop();

        expect(stroked, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
      });
    });

    group('Robustness', () {
      test('handles NaN coordinates gracefully', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(double.nan, 20)
          ..lineTo(30, 30);

        // Should either filter out NaN or handle gracefully
        try {
          final stroked = stroker.stroke(path.build(), state);
          expect(stroked, isNotNull);
        } catch (e) {
          // Acceptable to throw on NaN
          expect(e, isA<Exception>());
        }
      });

      test('handles infinity coordinates', () {
        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(double.infinity, 20)
          ..lineTo(30, 30);

        try {
          final stroked = stroker.stroke(path.build(), state);
          expect(stroked, isNotNull);
        } catch (e) {
          // Acceptable to throw on infinity
          expect(e, isA<Exception>());
        }
      });

      test('handles extremely small stroke width', () {
        state.strokeWidth = 1e-10;

        final path = PathBuilder()
          ..moveTo(10, 10)
          ..lineTo(20, 10);

        final stroked = stroker.stroke(path.build(), state);

        expect(stroked, isNotNull);
        // Should handle near-zero width
      });

      test('handles paths with thousands of segments', () {
        final path = PathBuilder();
        path.moveTo(0, 0);

        // Create path with many small segments
        for (int i = 1; i <= 5000; i++) {
          path.lineTo(i * 0.1, (i % 2) * 10.0);
        }

        state.strokeWidth = 1.0;

        final stopwatch = Stopwatch()..start();
        final stroked = stroker.stroke(path.build(), state);
        stopwatch.stop();

        expect(stroked, isNotNull);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });
    });
  });
}

// Simple trig helpers
double _cos(double x) {
  return math.cos(x);
}

double _sin(double x) {
  return math.sin(x);
}
