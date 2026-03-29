import 'dart:math';
import 'store_pricing_strategy.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';
import 'package:alt/core/domain/models/pricing_result.dart';

class TargetStrategy implements StorePricingStrategy {
  @override
  Future<PricingResult<Map<String, dynamic>>> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final rng = Random();
    // Stub: sometimes out of stock
    if (rng.nextBool()) {
      return const PricingFailureResult(PricingFailure.productNotFound,
          detail: 'Target stub: randomly out of stock');
    }
    return PricingSuccess({
      'storeName': 'Target',
      'price': 4.10 + rng.nextDouble(),
      'distance': '${(rng.nextDouble() * 3).toStringAsFixed(1)} mi',
    });
  }
}
