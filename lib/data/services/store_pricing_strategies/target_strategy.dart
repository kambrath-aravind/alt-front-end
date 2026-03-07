import 'dart:math';
import 'store_pricing_strategy.dart';

class TargetStrategy implements StorePricingStrategy {
  @override
  Future<Map<String, dynamic>?> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final rng = Random();
    // Sometimes out of stock
    if (rng.nextBool()) return null;
    return {
      'storeName': 'Target',
      'price': 4.10 + rng.nextDouble(),
      'distance': '${(rng.nextDouble() * 3).toStringAsFixed(1)} mi'
    };
  }
}
