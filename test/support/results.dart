import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

/// Expects [result] to be [Ok] and returns its value.
T ok<T>(final Result<T, ErrorDetails> result) {
  expect(result, isA<Ok<T, ErrorDetails>>(), reason: '$result');
  return (result as Ok<T, ErrorDetails>).value;
}

/// Expects [result] to be [Err] of [kind] and returns its details.
ErrorDetails err<T>(
  final Result<T, ErrorDetails> result,
  final ErrorKind kind,
) {
  expect(result, isA<Err<T, ErrorDetails>>(), reason: '$result');
  final details = (result as Err<T, ErrorDetails>).error;
  expect(details.kind, equals(kind), reason: details.message);
  return details;
}
