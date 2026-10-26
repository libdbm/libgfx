import '../paths/path.dart';
import '../rectangle.dart';
import '../spans/span.dart';

/// Fill rule for determining interior of a path
enum FillRule {
  /// Even-odd fill rule (alternating)
  evenOdd,

  /// Non-zero winding fill rule
  nonZero,
}

/// Abstract interface for rasterizer implementations
abstract class Rasterizer {
  /// Rasterize a path into spans, filling the interior given by [rule].
  /// When [viewport] is given, only spans inside it are produced, and the
  /// work done is bounded by the viewport rather than the path's extent.
  List<Span> rasterize(
    Path path, {
    FillRule rule = FillRule.evenOdd,
    Rectangle<int>? viewport,
  });
}
