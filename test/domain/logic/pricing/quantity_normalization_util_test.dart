import 'package:flutter_test/flutter_test.dart';
import 'package:alt/domain/models/product.dart';
import 'package:alt/domain/logic/pricing/quantity_normalization_util.dart';

Product _makeProduct(String name, {List<String>? categoryTags, String? comparedToCategory}) {
  return Product(
    id: '123',
    name: name,
    brand: 'TestBrand',
    ingredients: [],
    categoryTags: categoryTags ?? [],
    comparedToCategory: comparedToCategory,
  );
}

void main() {
  group('QuantityNormalizationUtil Tests', () {
    test('Normalizes simple volume', () {
      final product = _makeProduct('Coca-Cola 16 fl oz', categoryTags: ['en:soda']);
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isTrue);
      expect(result.basis, equals('volume'));
      // 16 * 29.5735 = 473.176
      expect(result.normalizedTotal, closeTo(473.176, 0.01));
      expect(result.normalizedUnit, equals('ml'));
    });

    test('Normalizes simple weight (g)', () {
      final product = _makeProduct('Lays Potato Chips 500g', categoryTags: ['en:chips']);
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isTrue);
      expect(result.basis, equals('weight'));
      expect(result.normalizedTotal, equals(500));
      expect(result.normalizedUnit, equals('g'));
    });

    test('Normalizes weight (oz_weight resolved from ambiguous oz)', () {
      final product = _makeProduct('Hershey Chocolate Bar 1.5 oz', categoryTags: ['en:candy']);
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isTrue);
      expect(result.basis, equals('weight'));
      expect(result.normalizedUnit, equals('g'));
      // 1.5 * 28.3495 = 42.52425
      expect(result.normalizedTotal, closeTo(42.524, 0.01));
    });

    test('Normalizes fluid oz resolved from ambiguous oz based on liquid keyword', () {
      final product = _makeProduct('Orange Juice 12 oz');
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isTrue);
      expect(result.basis, equals('volume'));
      expect(result.normalizedUnit, equals('ml'));
      // 12 * 29.5735
      expect(result.normalizedTotal, closeTo(354.88, 0.01));
    });

    test('Fails on ambiguous oz if no hint is available', () {
      final product = _makeProduct('Unknown Item 10 oz');
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isFalse);
      expect(result.parseReason, contains('Ambiguous'));
    });

    test('Handles multipack parsing safely', () {
      final product = _makeProduct('Coca-Cola 12 pack 12 fl oz');
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isTrue);
      expect(result.basis, equals('volume'));
      // 12 * 12 * 29.5735 = 4258.584
      expect(result.normalizedTotal, closeTo(4258.584, 0.01));
    });

    test('Rejects ambiguous "family size" without specific units', () {
      final product = _makeProduct('Doritos Family Size');
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isFalse);
      expect(result.parseReason, contains('ambiguous quantity phrases'));
    });

    test('Falls back to count if no weight/volume', () {
      final product = _makeProduct('Eggs 12 count');
      final result = QuantityNormalizationUtil.normalizeComparableQuantity(product);
      
      expect(result.success, isTrue);
      expect(result.basis, equals('count'));
      expect(result.normalizedTotal, equals(12));
    });
  });
}
