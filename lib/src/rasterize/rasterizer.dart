import '../paths/path.dart';
import '../spans/span.dart';

/// Abstract interface for rasterizer implementations
abstract class Rasterizer {
  /// Rasterize a path into spans
  List<Span> rasterize(Path path);
}
