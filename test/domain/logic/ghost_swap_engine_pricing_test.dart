import 'package:alt/core/domain/logic/ghost_swap_engine.dart';
import 'package:alt/core/domain/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id, String name) => Product(
      id: id,
      name: name,
      brand: 'Brand',
      ingredients: const [],
      categoryTags: const ['en:bars'],
    );

void main() {
  test(
      'resolvePriceComparison rejects comparison when original price is missing',
      () {
    final result = GhostSwapEngine.resolvePriceComparison(
      original: _product('orig', 'Original Bars 10 ct'),
      alternative: _product('alt', 'Alternative Bars 8 ct'),
      originalPrice: null,
      alternativePrice: 3.49,
    );

    expect(result.comparisonAvailable, isFalse);
    expect(result.difference, isNull);
    expect(result.direction, equals('none'));
    expect(
      result.reason,
      contains('Original product pricing unavailable'),
    );
  });
}
