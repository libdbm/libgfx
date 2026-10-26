/// Result type for operations whose failure is an expected outcome, such as
/// decoding untrusted image or font data.
library;

/// Either a successful [Ok] value or an [Err] describing the failure.
sealed class Result<T, E> {
  const Result();

  /// Applies [transform] to an [Ok] value; an [Err] passes through unchanged.
  Result<U, E> map<U>(final U Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final error) => Err(error),
  };

  /// Chains a further fallible step onto an [Ok] value; an [Err] passes
  /// through without calling [transform].
  Result<U, E> flatMap<U>(final Result<U, E> Function(T value) transform) =>
      switch (this) {
        Ok(:final value) => transform(value),
        Err(:final error) => Err(error),
      };

  /// Reduces the result to a single value of type [R].
  R fold<R>(
    final R Function(T value) success,
    final R Function(E error) failure,
  ) => switch (this) {
    Ok(:final value) => success(value),
    Err(:final error) => failure(error),
  };
}

/// A successful result.
final class Ok<T, E> extends Result<T, E> {
  final T value;

  const Ok(this.value);
}

/// A failed result.
final class Err<T, E> extends Result<T, E> {
  final E error;

  const Err(this.error);
}

/// Category of an expected failure.
enum ErrorKind {
  /// Input ended before a complete record could be read.
  truncated,

  /// Input is structurally invalid.
  malformed,

  /// Input is valid but uses a feature this library does not support.
  unsupported,

  /// Input would exceed a configured resource limit.
  limit,

  /// Reading the input failed.
  io,

  /// A transform has no inverse.
  singular,
}

/// Describes why an operation returned [Err].
final class ErrorDetails {
  final ErrorKind kind;
  final String message;

  /// The underlying error or exception, when there is one.
  final Object? cause;

  const ErrorDetails(this.kind, this.message, [this.cause]);

  @override
  String toString() =>
      '${kind.name}: $message${cause != null ? ' (caused by: $cause)' : ''}';
}
