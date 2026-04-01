import 'package:flutter_test/flutter_test.dart';
import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/logic/pricing/comparison_gate.dart';

Product _makeProduct(String name, {List<String>? categoryTags}) {
  return Product(
    id: '123',
    name: name,
    brand: 'TestBrand',
    ingredients: [],
    categoryTags: categoryTags ?? [],
  );
}

void main() {
  group('ComparisonGate Tests', () {
    test('Allows valid volume comparison and computes savings', () {
      final original = _makeProduct('Coke 2 liter', categoryTags: ['en:soda']);
      final alternative = _makeProduct('Pepsi 1 liter', categoryTags: ['en:soda']);
      
      // Original 2 liters = $4.00 (unit price: $2.00 per liter)
      // Alternative 1 liter = $1.50 (unit price: $1.50 per liter)
      // Equivalent Alternative Cost for 2 liters = $1.50 * 2 = $3.00
      // Difference = $3.00 - $4.00 = -$1.00 (Savings)

      final result = ComparisonGate.canCompareProducts(
        original: original,
        alternative: alternative,
        originalPrice: 4.00,
        alternativePrice: 1.50,
      );

      expect(result.comparisonAvailable, isTrue);
      expect(result.comparisonBasis, equals('volume'));
      expect(result.equivalentAlternativeCost, closeTo(3.00, 0.01));
      expect(result.difference, closeTo(-1.00, 0.01));
      expect(result.direction, equals('savings'));
    });

    test('Rejects if basis types differ', () {
      // Coke 2 liter is volume, Lays 10 oz is weight
      final original = _makeProduct('Coke 2 liter', categoryTags: ['en:soda']);
      final alternative = _makeProduct('Lays 10 oz', categoryTags: ['en:chips']);
      
      final result = ComparisonGate.canCompareProducts(
        original: original,
        alternative: alternative,
        originalPrice: 4.00,
        alternativePrice: 2.00,
      );

      expect(result.comparisonAvailable, isFalse);
      expect(result.reason, contains('could not be matched fairly'));
    });

    test('Rejects if original is a multipack and alternative is a single that cant easily compare basis', () {
      final original = _makeProduct('Variety Pack Chips 24 count', categoryTags: ['en:chips']);
      final alternative = _makeProduct('Doritos 2 oz', categoryTags: ['en:chips']);
      
      final result = ComparisonGate.canCompareProducts(
        original: original,
        alternative: alternative,
        originalPrice: 10.00,
        alternativePrice: 1.50,
      );

      expect(result.comparisonAvailable, isFalse);
      expect(result.reason, contains('could not be determined'));
    });

    test('Computes loss correctly', () {
      final original = _makeProduct('Generic Milk 128 fl oz', categoryTags: ['en:milk']);
      final alternative = _makeProduct('Organic Milk 64 fl oz', categoryTags: ['en:milk']);
      
      // Original 128oz = $3.00 (unit $0.0234)
      // Alternative 64oz = $4.00 (unit $0.0625)
      // Equivalent Alt Cost for 128oz = $8.00
      // Difference = $8.00 - $3.00 = +$5.00 (Loss)

      final result = ComparisonGate.canCompareProducts(
        original: original,
        alternative: alternative,
        originalPrice: 3.00,
        alternativePrice: 4.00,
      );

      expect(result.comparisonAvailable, isTrue);
      expect(result.equivalentAlternativeCost, closeTo(8.00, 0.01));
      expect(result.difference, closeTo(5.00, 0.01));
      expect(result.direction, equals('loss'));
    });
  });
}
