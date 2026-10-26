/// Base class for graphics state components providing common functionality
abstract class StateBase<T extends StateBase<T>> {
  /// Creates a deep copy of this state
  T clone();

  /// Validates a numeric value is within acceptable range
  static double validatePositive(double value, [final double fallback = 1.0]) {
    if (value.isNaN || value.isInfinite || value < 0) {
      return fallback;
    }
    return value;
  }
}
