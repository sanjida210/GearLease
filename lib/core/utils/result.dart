import 'package:equatable/equatable.dart';

/// A strongly typed functional Result monad representing either success ([S]) or failure ([F]).
class Result<S, F> extends Equatable {
  final S? dataOrNull;
  final F? failureOrNull;
  final bool isSuccess;

  const Result._({
    this.dataOrNull,
    this.failureOrNull,
    required this.isSuccess,
  });

  /// Creates a successful Result containing [data].
  factory Result.success(S data) => Result._(
        dataOrNull: data,
        isSuccess: true,
      );

  /// Creates a failed Result containing [failure].
  factory Result.failure(F failure) => Result._(
        failureOrNull: failure,
        isSuccess: false,
      );

  /// Whether this result represents a failed operation.
  bool get isFailure => !isSuccess;

  /// Pattern-matching callback execution.
  T when<T>({
    required T Function(S data) success,
    required T Function(F failure) failure,
  }) {
    if (isSuccess) {
      return success(dataOrNull as S);
    } else {
      return failure(failureOrNull as F);
    }
  }

  /// Transforms the success value using [transform], leaving failure untouched.
  Result<T, F> map<T>(T Function(S data) transform) {
    if (isSuccess) {
      return Result<T, F>.success(transform(dataOrNull as S));
    } else {
      return Result<T, F>.failure(failureOrNull as F);
    }
  }

  /// Chains another Result-returning computation if this Result is successful.
  Result<T, F> flatMap<T>(Result<T, F> Function(S data) transform) {
    if (isSuccess) {
      return transform(dataOrNull as S);
    } else {
      return Result<T, F>.failure(failureOrNull as F);
    }
  }

  @override
  List<Object?> get props => [dataOrNull, failureOrNull, isSuccess];

  @override
  String toString() {
    return isSuccess ? 'Result.success($dataOrNull)' : 'Result.failure($failureOrNull)';
  }
}
