import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/exceptions.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';

void main() {
  group('Exceptions Tests', () {
    test('ServerException holds message and statusCode', () {
      final exception = ServerException('Internal Server Error', statusCode: 500);
      expect(exception.message, 'Internal Server Error');
      expect(exception.statusCode, 500);
      expect(exception.toString(), contains('500'));
    });

    test('CacheException holds message', () {
      final exception = CacheException('Cache read failure');
      expect(exception.message, 'Cache read failure');
      expect(exception.toString(), contains('Cache read failure'));
    });

    test('NetworkException holds message', () {
      final exception = NetworkException('No connection');
      expect(exception.message, 'No connection');
      expect(exception.toString(), contains('No connection'));
    });

    test('BiometricException holds message', () {
      final exception = BiometricException('Biometrics cancelled');
      expect(exception.message, 'Biometrics cancelled');
      expect(exception.toString(), contains('Biometrics cancelled'));
    });

    test('HardwareSimulationException holds message', () {
      final exception = HardwareSimulationException('Camera sensor unavailable');
      expect(exception.message, 'Camera sensor unavailable');
      expect(exception.toString(), contains('Camera sensor unavailable'));
    });
  });

  group('Failures Tests (Equatable)', () {
    test('ServerFailure supports value equality with message and statusCode', () {
      const f1 = ServerFailure('Server error', statusCode: 502);
      const f2 = ServerFailure('Server error', statusCode: 502);
      const f3 = ServerFailure('Different', statusCode: 500);

      expect(f1, equals(f2));
      expect(f1, isNot(equals(f3)));
      expect(f1.props, ['Server error', 502]);
    });

    test('CacheFailure supports value equality', () {
      const f1 = CacheFailure('Disk full');
      const f2 = CacheFailure('Disk full');
      const f3 = CacheFailure('Corrupt entry');

      expect(f1, equals(f2));
      expect(f1, isNot(equals(f3)));
    });

    test('NetworkFailure supports default message and equality', () {
      const f1 = NetworkFailure();
      const f2 = NetworkFailure('No network connectivity available.');
      expect(f1, equals(f2));
    });

    test('BiometricFailure supports value equality', () {
      const f1 = BiometricFailure('User cancelled TouchID');
      const f2 = BiometricFailure('User cancelled TouchID');
      const f3 = BiometricFailure('Hardware not available');

      expect(f1, equals(f2));
      expect(f1, isNot(equals(f3)));
    });
  });

  group('Result<S, F> Monad Tests', () {
    test('Result.success returns data, isSuccess is true, isFailure is false', () {
      final result = Result<int, Failure>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Result.failure returns failure, isFailure is true, isSuccess is false', () {
      const failure = ServerFailure('Timeout', statusCode: 408);
      final result = Result<int, Failure>.failure(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('when pattern matching executes correct branch', () {
      final successResult = Result<String, Failure>.success('hello');
      final failureResult = Result<String, Failure>.failure(const NetworkFailure());

      final successMapped = successResult.when(
        success: (val) => 'Received $val',
        failure: (f) => 'Failed with ${f.message}',
      );
      final failureMapped = failureResult.when(
        success: (val) => 'Received $val',
        failure: (f) => 'Failed with ${f.message}',
      );

      expect(successMapped, 'Received hello');
      expect(failureMapped, 'Failed with No network connectivity available.');
    });

    test('map transforms success value and leaves failure untouched', () {
      final success = Result<int, Failure>.success(10);
      final failure = Result<int, Failure>.failure(const CacheFailure('error'));

      final mappedSuccess = success.map((x) => x * 2);
      final mappedFailure = failure.map((x) => x * 2);

      expect(mappedSuccess.dataOrNull, 20);
      expect(mappedFailure.failureOrNull, const CacheFailure('error'));
    });

    test('flatMap chains Results together', () {
      final success = Result<int, Failure>.success(10);
      final failure = Result<int, Failure>.failure(const CacheFailure('error'));

      final flatMappedSuccess = success.flatMap((x) => Result.success('Value: $x'));
      final flatMappedFailure = failure.flatMap((x) => Result.success('Value: $x'));

      expect(flatMappedSuccess.dataOrNull, 'Value: 10');
      expect(flatMappedFailure.failureOrNull, const CacheFailure('error'));
    });

    test('Result supports Equatable equality', () {
      final r1 = Result<String, Failure>.success('abc');
      final r2 = Result<String, Failure>.success('abc');
      final r3 = Result<String, Failure>.failure(const NetworkFailure());

      expect(r1, equals(r2));
      expect(r1, isNot(equals(r3)));
    });
  });
}
