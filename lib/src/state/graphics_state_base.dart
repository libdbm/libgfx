/// Base class for graphics state components providing common functionality
abstract class GraphicsStateBase<T extends GraphicsStateBase<T>> {
  /// Creates a deep copy of this state
  T clone();

  /// Validates a numeric value is within acceptable range
  static double validatePositive(
    double value,
    String name, [
    double defaultValue = 1.0,
  ]) {
    if (value.isNaN || value.isInfinite || value < 0) {
      return defaultValue;
    }
    return value;
  }
}
