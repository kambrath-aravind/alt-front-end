import 'package:alt/core/data/services/omni_store_service.dart';
import 'package:alt/core/data/services/store_pricing_strategies/store_pricing_strategy.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';
import 'package:alt/core/domain/models/pricing_result.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStrategy implements StorePricingStrategy {
  _FakeStrategy(this.result);

  final PricingResult<Map<String, dynamic>> result;

  @override
  Future<PricingResult<Map<String, dynamic>>> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    return result;
  }
}

void main() {
  group('OmniStoreService', () {
    test('ignores out-of-stock results when selecting the best price',
        () async {
      final service = OmniStoreService(
        strategies: [
          _FakeStrategy(
            const PricingSuccess({
              'storeName': 'Cheapest But OOS',
              'price': 1.99,
              'distance': '1.0 mi',
              'inStock': false,
            }),
          ),
          _FakeStrategy(
            const PricingSuccess({
              'storeName': 'Available Option',
              'price': 2.49,
              'distance': '2.0 mi',
              'inStock': true,
            }),
          ),
        ],
      );

      final result = await service.findLowestPriceNearby(
          '123', 'Granola Bars', '80202', 5);

      expect(result, isA<PricingSuccess<Map<String, dynamic>>>());
      expect(result.valueOrNull!['storeName'], equals('Available Option'));
      expect(result.valueOrNull!['price'], equals(2.49));
    });

    test('returns failure when every successful hit is out of stock', () async {
      final service = OmniStoreService(
        strategies: [
          _FakeStrategy(
            const PricingSuccess({
              'storeName': 'Out of Stock Only',
              'price': 1.99,
              'distance': '1.0 mi',
              'inStock': false,
            }),
          ),
          _FakeStrategy(
            const PricingFailureResult<Map<String, dynamic>>(
              PricingFailure.timeout,
            ),
          ),
        ],
      );

      final result = await service.findLowestPriceNearby(
          '123', 'Granola Bars', '80202', 5);

      expect(result, isA<PricingFailureResult<Map<String, dynamic>>>());
      expect(result.failureOrNull, equals(PricingFailure.productNotFound));
    });
  });
}
