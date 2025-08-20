import 'dart:math' as math;

import '../utils/math_utils.dart';
import 'path.dart';

/// Utility class for creating common path shapes
class PathUtils {
  // Prevent instantiation
  PathUtils._();

  /// Create a rectangle path
  static Path createRectangle(double x, double y, double width, double height) {
    final builder = PathBuilder()
      ..moveTo(x, y)
      ..lineTo(x + width, y)
      ..lineTo(x + width, y + height)
      ..lineTo(x, y + height)
      ..close();
    return builder.build();
  }

  /// Create a rounded rectangle path
  static Path createRoundedRectangle(
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) {
    // Clamp radius to half of smallest dimension
    radius = radius.clamp(0, math.min(width, height) / 2);

    // If radius is zero or effectively zero, just create a regular rectangle
    if (radius < 1e-9) {
      return createRectangle(x, y, width, height);
    }

    final builder = PathBuilder();

    // Start at top-left corner after radius
    builder.moveTo(x + radius, y);

    // Top edge
    builder.lineTo(x + width - radius, y);

    // Top-right corner
    builder.arc(
      x + width - radius,
      y + radius,
      radius,
      -MathUtils.piOver2,
      MathUtils.piOver2,
    );

    // Right edge
    builder.lineTo(x + width, y + height - radius);

    // Bottom-right corner
    builder.arc(
      x + width - radius,
      y + height - radius,
      radius,
      0,
      MathUtils.piOver2,
    );

    // Bottom edge
    builder.lineTo(x + radius, y + height);

    // Bottom-left corner
    builder.arc(
      x + radius,
      y + height - radius,
      radius,
      MathUtils.piOver2,
      MathUtils.piOver2,
    );

    // Left edge
    builder.lineTo(x, y + radius);

    // Top-left corner
    builder.arc(x + radius, y + radius, radius, math.pi, MathUtils.piOver2);

    builder.close();
    return builder.build();
  }

  /// Create a circle path using bezier curves
  static Path createCircle(double cx, double cy, double radius) {
    final builder = PathBuilder();
    final k = MathUtils.circleKappa * radius;

    // Add tiny epsilon to avoid curves meeting at exact integer y-coordinates
    // This prevents gaps in rasterization at curve junctions
    final epsilon = MathUtils.rasterTolerance;

    builder.moveTo(cx + radius, cy + epsilon);
    builder.curveTo(
      cx + radius,
      cy + k,
      cx + k,
      cy + radius,
      cx + epsilon,
      cy + radius,
    );
    builder.curveTo(
      cx - k,
      cy + radius,
      cx - radius,
      cy + k,
      cx - radius,
      cy + epsilon,
    );
    builder.curveTo(
      cx - radius,
      cy - k,
      cx - k,
      cy - radius,
      cx + epsilon,
      cy - radius,
    );
    builder.curveTo(
      cx + k,
      cy - radius,
      cx + radius,
      cy - k,
      cx + radius,
      cy + epsilon,
    );
    builder.close();

    return builder.build();
  }

  /// Create an ellipse path
  static Path createEllipse(double cx, double cy, double rx, double ry) {
    final builder = PathBuilder();
    final kx = MathUtils.circleKappa * rx;
    final ky = MathUtils.circleKappa * ry;

    builder.moveTo(cx + rx, cy);
    builder.curveTo(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry);
    builder.curveTo(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy);
    builder.curveTo(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry);
    builder.curveTo(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy);
    builder.close();

    return builder.build();
  }

  /// Create a regular polygon path
  static Path createPolygon(double cx, double cy, double radius, int sides) {
    if (sides < 3) {
      throw ArgumentError('Polygon must have at least 3 sides');
    }

    final builder = PathBuilder();
    final angleStep = MathUtils.pi2 / sides;

    for (int i = 0; i <= sides; i++) {
      // Changed to <= sides to include closing lineTo
      final angle = i * angleStep - MathUtils.piOver2; // Start at top
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);

      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }

    return builder
        .build(); // Don't call close() as we've already created the closing line
  }

  /// Create a star path
  static Path createStar(
    double cx,
    double cy,
    double outerRadius,
    double innerRadius,
    int points,
  ) {
    if (points < 3) {
      throw ArgumentError('Star must have at least 3 points');
    }

    final builder = PathBuilder();
    final angleStep = math.pi / points;

    for (int i = 0; i <= points * 2; i++) {
      // Changed to <= to include closing lineTo
      final angle = i * angleStep - MathUtils.piOver2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);

      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }

    return builder
        .build(); // Don't call close() as we've already created the closing line
  }

  /// Create an arc path
  static Path createArc(
    double cx,
    double cy,
    double radius,
    double startAngle,
    double endAngle,
    bool clockwise,
  ) {
    final builder = PathBuilder();
    final sweep = clockwise ? endAngle - startAngle : startAngle - endAngle;

    builder.arc(cx, cy, radius, startAngle, sweep, !clockwise);
    return builder.build();
  }
}
