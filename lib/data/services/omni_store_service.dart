import 'store_pricing_strategies/store_pricing_strategy.dart';
import 'store_pricing_strategies/kroger_strategy.dart';
import 'store_pricing_strategies/walmart_strategy.dart';
import 'package:flutter/foundation.dart';

class OmniStoreService {
  final List<StorePricingStrategy> _strategies;

  OmniStoreService({List<StorePricingStrategy>? strategies})
      : _strategies = strategies ??
            [
              KrogerStrategy(),
              WalmartStrategy(),
            ];

  /// Queries all registered store strategies concurrently and returns
  /// the lowest found price for a product.
  Future<Map<String, dynamic>?> findLowestPriceNearby(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    debugPrint('[OmniStore] ===== findLowestPriceNearby START =====');
    debugPrint('[OmniStore] Product: $queryName (barcode: $productBarcode)');
    debugPrint(
        '[OmniStore] Location: zipCode=$zipCode, radius=${radiusInMiles}mi');
    debugPrint('[OmniStore] Querying ${_strategies.length} strategies...');

    // 1. Fan-out requests to all active strategies
    final results = await Future.wait(
      _strategies.map((strategy) {
        final strategyName = strategy.runtimeType.toString();
        debugPrint('[OmniStore] >> Calling $strategyName...');
        return strategy
            .getLowestPrice(
          productBarcode,
          queryName,
          zipCode,
          radiusInMiles,
        )
            .then((result) {
          debugPrint(
              '[OmniStore] << $strategyName returned: ${result != null ? "price=${result['price']}, store=${result['storeName']}" : "null (no result)"}');
          return result;
        }).catchError((e) {
          debugPrint('[OmniStore] << $strategyName EXCEPTION: $e');
          return null;
        });
      }),
    );

    // 2. Filter out nulls
    final validResults = results.whereType<Map<String, dynamic>>().toList();

    debugPrint(
        '[OmniStore] Total valid results: ${validResults.length} / ${results.length}');

    if (validResults.isEmpty) {
      debugPrint(
          '[OmniStore] ===== findLowestPriceNearby END (no results) =====');
      return null;
    }

    // 3. Find the lowest price
    validResults
        .sort((a, b) => (a['price'] as double).compareTo(b['price'] as double));
    debugPrint(
        '[OmniStore] Best price: \$${validResults.first['price']} at ${validResults.first['storeName']}');
    debugPrint('[OmniStore] ===== findLowestPriceNearby END =====');
    return validResults.first;
  }
}
