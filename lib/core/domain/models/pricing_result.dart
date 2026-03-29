import 'pricing_failure.dart';

/// The result of a store-pricing lookup.
///
/// A successful lookup carries a typed [value].
/// A failed lookup carries a [PricingFailure] and an optional [detail] string
/// intended for logging (not user display — use [PricingFailure.userMessage] for that).
sealed class PricingResult<T> {
  const PricingResult();

  /// Returns `true` if this is a [PricingSuccess].
  bool get isSuccess => this is PricingSuccess<T>;

  /// Returns the value or `null` if this is a [PricingFailureResult].
  T? get valueOrNull =>
      this is PricingSuccess<T> ? (this as PricingSuccess<T>).value : null;

  /// Returns the failure or `null` if this is a [PricingSuccess].
  PricingFailure? get failureOrNull =>
      this is PricingFailureResult<T>
          ? (this as PricingFailureResult<T>).failure
          : null;
}

/// A successful pricing result carrying the store data [value].
final class PricingSuccess<T> extends PricingResult<T> {
  final T value;
  const PricingSuccess(this.value);
}

/// A failed pricing result with a typed [failure] reason and optional [detail].
final class PricingFailureResult<T> extends PricingResult<T> {
  final PricingFailure failure;

  /// Optional developer-facing detail (e.g. HTTP status code, exception message).
  /// Do NOT show this directly to users; use [failure.userMessage] instead.
  final String? detail;

  const PricingFailureResult(this.failure, {this.detail});
}
