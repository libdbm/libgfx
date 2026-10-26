import 'package:libgfx/libgfx.dart';
import 'package:test/test.dart';

void main() {
  const failure = ErrorDetails(ErrorKind.truncated, 'too short');

  group('Result', () {
    test('switch over Ok and Err is exhaustive', () {
      String describe(final Result<int, ErrorDetails> result) =>
          switch (result) {
            Ok(:final value) => 'ok $value',
            Err(:final error) => 'err ${error.kind.name}',
          };

      expect(describe(const Ok(3)), equals('ok 3'));
      expect(describe(const Err(failure)), equals('err truncated'));
    });

    test('map transforms Ok and passes Err through', () {
      const Result<int, ErrorDetails> ok = Ok(3);
      const Result<int, ErrorDetails> err = Err(failure);

      expect(ok.map((value) => value * 2), isA<Ok<int, ErrorDetails>>());
      expect((ok.map((value) => value * 2) as Ok).value, equals(6));
      expect((err.map((value) => value * 2) as Err).error, same(failure));
    });

    test('flatMap chains Ok and short-circuits on Err', () {
      const Result<int, ErrorDetails> ok = Ok(3);
      const Result<int, ErrorDetails> err = Err(failure);
      var calls = 0;
      Result<String, ErrorDetails> next(final int value) {
        calls++;
        return Ok('v$value');
      }

      expect((ok.flatMap(next) as Ok).value, equals('v3'));
      expect((err.flatMap(next) as Err).error, same(failure));
      expect(calls, equals(1));
    });

    test('flatMap propagates an Err returned by the next step', () {
      const Result<int, ErrorDetails> ok = Ok(3);
      const other = ErrorDetails(ErrorKind.limit, 'too big');

      final result = ok.flatMap<int>((value) => const Err(other));

      expect((result as Err).error, same(other));
    });

    test('fold selects the matching branch', () {
      const Result<int, ErrorDetails> ok = Ok(3);
      const Result<int, ErrorDetails> err = Err(failure);

      expect(ok.fold((value) => value, (error) => -1), equals(3));
      expect(err.fold((value) => value, (error) => -1), equals(-1));
    });
  });

  group('ErrorDetails', () {
    test('keeps kind, message and cause', () {
      final cause = RangeError('index');
      final details = ErrorDetails(ErrorKind.malformed, 'bad table', cause);

      expect(details.kind, equals(ErrorKind.malformed));
      expect(details.message, equals('bad table'));
      expect(details.cause, same(cause));
      expect(details.toString(), contains('bad table'));
      expect(details.toString(), contains('index'));
    });
  });
}
