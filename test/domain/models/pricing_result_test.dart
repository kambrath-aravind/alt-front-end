import 'package:flutter_test/flutter_test.dart';
import 'package:alt/core/domain/models/pricing_result.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';

void main() {
  group('PricingFailure', () {
    test('each variant has a non-empty userMessage', () {
      for (final failure in PricingFailure.values) {
        expect(
          failure.userMessage.isNotEmpty,
          isTrue,
          reason: '$failure.userMessage must not be empty',
        );
      }
    });

    test('authFailure message does not mention "connection"', () {
      // Auth failures are a server-side issue, not a network issue
      expect(
        PricingFailure.authFailure.userMessage
            .toLowerCase()
            .contains('connection'),
        isFalse,
        reason: 'Auth failure should not blame the connection',
      );
    });

    test('timeout and networkError messages mention connection', () {
      for (final f in [PricingFailure.timeout, PricingFailure.networkError]) {
        expect(
          f.userMessage.toLowerCase().contains('connection'),
          isTrue,
          reason: '$f should mention a connection issue',
        );
      }
    });
  });

  group('PricingResult', () {
    test('PricingSuccess.isSuccess is true', () {
      const result = PricingSuccess({'price': 3.99, 'storeName': 'Kroger'});
      expect(result.isSuccess, isTrue);
      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull, isNotNull);
      expect(result.valueOrNull!['price'], equals(3.99));
    });

    test('PricingFailureResult.isSuccess is false', () {
      const result = PricingFailureResult<Map<String, dynamic>>(
        PricingFailure.timeout,
        detail: 'Request timed out after 10s',
      );
      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, equals(PricingFailure.timeout));
    });

    test('PricingFailureResult.detail is accessible', () {
      const detail = 'HTTP 401 from auth endpoint';
      const result = PricingFailureResult<Map<String, dynamic>>(
        PricingFailure.authFailure,
        detail: detail,
      );
      expect(result.detail, equals(detail));
    });

    test('PricingSuccess can hold any type', () {
      const intResult = PricingSuccess(42);
      expect(intResult.isSuccess, isTrue);
      expect(intResult.valueOrNull, equals(42));
    });

    test('PricingFailureResult with no detail has null detail', () {
      const result = PricingFailureResult<int>(PricingFailure.noStoreNearby);
      expect(result.detail, isNull);
      expect(result.failure, equals(PricingFailure.noStoreNearby));
    });
  });
}
