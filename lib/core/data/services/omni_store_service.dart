import 'store_pricing_strategies/store_pricing_strategy.dart';
import 'store_pricing_strategies/kroger_strategy.dart';
import 'store_pricing_strategies/walmart_strategy.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';
import 'package:alt/core/domain/models/pricing_result.dart';
import 'package:alt/utils/app_logger.dart';

class OmniStoreService {
  static const _tag = 'OmniStoreService';

  final List<StorePricingStrategy> _strategies;

  OmniStoreService({List<StorePricingStrategy>? strategies})
      : _strategies = strategies ??
            [
              KrogerStrategy(),
              WalmartStrategy(),
            ];

  /// Queries all registered store strategies concurrently and returns the
  /// lowest found price wrapped in a [PricingResult].
  ///
  /// Returns [PricingSuccess] with the cheapest result when at least one
  /// strategy succeeds.  Returns the most actionable [PricingFailureResult]
  /// when every strategy fails (prefers `authFailure` → `timeout` → `networkError`
  /// → `noStoreNearby` → `productNotFound`).
  Future<PricingResult<Map<String, dynamic>>> findLowestPriceNearby(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    AppLogger.info(_tag, '===== findLowestPriceNearby START =====');
    AppLogger.debug(_tag, 'Product: $queryName (barcode: $productBarcode)');
    AppLogger.debug(
        _tag, 'Location: zipCode=$zipCode, radius=${radiusInMiles}mi');
    AppLogger.debug(_tag, 'Querying ${_strategies.length} strategies…');

    // Fan-out requests to all active strategies
    final results = await Future.wait(
      _strategies.map((strategy) {
        final name = strategy.runtimeType.toString();
        AppLogger.debug(_tag, '>> Calling $name…');
        return strategy
            .getLowestPrice(productBarcode, queryName, zipCode, radiusInMiles)
            .then((result) {
          if (result.isSuccess) {
            final v = result.valueOrNull!;
            AppLogger.info(_tag,
                '<< $name → price=${v['price']}, store=${v['storeName']}');
          } else {
            AppLogger.warning(
                _tag, '<< $name → FAILED: ${result.failureOrNull}');
          }
          return result;
        }).catchError((Object e) {
          AppLogger.error(_tag, '<< $name → EXCEPTION', e);
          return PricingFailureResult<Map<String, dynamic>>(
              PricingFailure.networkError,
              detail: e.toString());
        });
      }),
    );

    // Collect successes
    final successes = results
        .whereType<PricingSuccess<Map<String, dynamic>>>()
        .map((s) => s.value)
        .where((value) => value['inStock'] != false)
        .toList();
    final hadOutOfStockSuccess = results
        .whereType<PricingSuccess<Map<String, dynamic>>>()
        .map((s) => s.value)
        .any((value) => value['inStock'] == false);

    AppLogger.info(
        _tag, 'Valid results: ${successes.length} / ${results.length}');

    if (successes.isNotEmpty) {
      successes.sort(
          (a, b) => (a['price'] as double).compareTo(b['price'] as double));
      AppLogger.info(_tag,
          'Best price: \$${successes.first['price']} at ${successes.first['storeName']}');
      AppLogger.info(_tag, '===== findLowestPriceNearby END =====');
      return PricingSuccess(successes.first);
    }

    if (hadOutOfStockSuccess) {
      AppLogger.warning(_tag,
          '===== findLowestPriceNearby END (only out-of-stock results) =====');
      return const PricingFailureResult(
        PricingFailure.productNotFound,
        detail: 'Only out-of-stock results were returned',
      );
    }

    // All failed — pick the most actionable failure
    final failures = results
        .whereType<PricingFailureResult<Map<String, dynamic>>>()
        .map((f) => f.failure)
        .toList();

    final bestFailure = _mostActionableFailure(failures);
    AppLogger.warning(_tag,
        '===== findLowestPriceNearby END (no results: $bestFailure) =====');
    return PricingFailureResult(bestFailure);
  }

  /// Returns the failure that is most useful to surface to the user.
  ///
  /// Priority: authFailure > timeout > networkError > noStoreNearby > productNotFound
  PricingFailure _mostActionableFailure(List<PricingFailure> failures) {
    const priority = [
      PricingFailure.authFailure,
      PricingFailure.timeout,
      PricingFailure.networkError,
      PricingFailure.noStoreNearby,
      PricingFailure.productNotFound,
    ];
    for (final f in priority) {
      if (failures.contains(f)) return f;
    }
    return PricingFailure.productNotFound;
  }
}
