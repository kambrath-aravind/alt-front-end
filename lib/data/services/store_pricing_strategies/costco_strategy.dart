import 'dart:math';
import 'store_pricing_strategy.dart';

class CostcoStrategy implements StorePricingStrategy {
  @override
  Future<Map<String, dynamic>?> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final rng = Random();
    // Costco often bulk, price/unit math needed in real life
    return {
      'storeName': 'Costco',
      'price': 12.99,
      'distance': '${(rng.nextDouble() * 10).toStringAsFixed(1)} mi'
    };
  }
}
