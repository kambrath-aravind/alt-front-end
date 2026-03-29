import 'package:alt/core/data/services/store_pricing_strategies/store_match_util.dart';
import 'package:alt/core/domain/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

StoreCatalogCandidate _candidate({
  required String title,
  String? brand,
  String? upc,
  String? packageText,
  required double price,
  bool inStock = true,
}) {
  return StoreCatalogCandidate(
    title: title,
    brand: brand,
    upc: upc,
    packageText: packageText,
    price: price,
    inStock: inStock,
    pricingPayload: {
      'storeName': 'Test Store',
      'storeAddress': '123 Test Ave',
      'price': price,
      'distance': '1.0 mi',
      'inStock': inStock,
    },
  );
}

void main() {
  group('StoreMatchUtil', () {
    test('exact UPC beats a cheaper fuzzy name hit', () {
      final target = StoreMatchTarget.fromProduct(
        const Product(
          id: '0012345678905',
          name: 'Sparkling Water Lemon 12 fl oz',
          brand: 'Polar',
          ingredients: [],
          categoryTags: ['en:sparkling-waters'],
        ),
      );

      final best = StoreMatchUtil.pickBestCandidate(
        target: target,
        minConfidence: StoreMatchUtil.nameSearchThreshold,
        candidates: [
          _candidate(
            title: 'Sparkling Water Lemon 12 fl oz',
            brand: 'Polar',
            upc: '0012345678905',
            price: 4.99,
          ),
          _candidate(
            title: 'Sparkling Water Lemon 12 fl oz',
            brand: 'Store Brand',
            upc: '0099999999999',
            price: 2.99,
          ),
        ],
      );

      expect(best, isNotNull);
      expect(best!.exactBarcodeMatch, isTrue);
      expect(best.candidate.upc, equals('0012345678905'));
    });

    test('same brand but wrong size is rejected or downgraded', () {
      final target = StoreMatchTarget.fromProduct(
        const Product(
          id: '12345',
          name: 'Trail Mix 10 oz',
          brand: 'Acme',
          ingredients: [],
          categoryTags: ['en:trail-mixes'],
        ),
      );

      final wrongSize = _candidate(
        title: 'Trail Mix 20 oz',
        brand: 'Acme',
        price: 2.49,
      );
      final rightSize = _candidate(
        title: 'Trail Mix 10 oz',
        brand: 'Acme',
        price: 3.49,
      );

      final wrongSizeScore = StoreMatchUtil.scoreCandidate(
        target: target,
        candidate: wrongSize,
      );
      final best = StoreMatchUtil.pickBestCandidate(
        target: target,
        minConfidence: StoreMatchUtil.nameSearchThreshold,
        candidates: [wrongSize, rightSize],
      );

      expect(wrongSizeScore, lessThan(StoreMatchUtil.nameSearchThreshold));
      expect(best, isNotNull);
      expect(best!.candidate.title, equals('Trail Mix 10 oz'));
    });

    test('same category but wrong variant does not win', () {
      final target = StoreMatchTarget.fromProduct(
        const Product(
          id: 'abc',
          name: 'Greek Yogurt Plain 32 oz',
          brand: 'Fage',
          ingredients: [],
          categoryTags: ['en:yogurts'],
        ),
      );

      final best = StoreMatchUtil.pickBestCandidate(
        target: target,
        minConfidence: StoreMatchUtil.nameSearchThreshold,
        candidates: [
          _candidate(
            title: 'Greek Yogurt Vanilla 32 oz',
            brand: 'Fage',
            price: 3.29,
          ),
          _candidate(
            title: 'Greek Yogurt Plain 32 oz',
            brand: 'Fage',
            price: 3.79,
          ),
        ],
      );

      expect(best, isNotNull);
      expect(best!.candidate.title, equals('Greek Yogurt Plain 32 oz'));
    });

    test('multiple acceptable matches choose the cheapest in-stock option', () {
      final target = StoreMatchTarget.fromProduct(
        const Product(
          id: '555',
          name: 'Protein Bars Chocolate 6 ct',
          brand: 'FitCo',
          ingredients: [],
          categoryTags: ['en:protein-bars'],
        ),
      );

      final best = StoreMatchUtil.pickBestCandidate(
        target: target,
        minConfidence: StoreMatchUtil.nameSearchThreshold,
        candidates: [
          _candidate(
            title: 'Protein Bars Chocolate 6 ct',
            brand: 'FitCo',
            price: 4.99,
          ),
          _candidate(
            title: 'Protein Bars Chocolate 6 ct',
            brand: 'FitCo',
            price: 3.99,
          ),
          _candidate(
            title: 'Protein Bars Chocolate 6 ct',
            brand: 'FitCo',
            price: 1.99,
            inStock: false,
          ),
        ],
      );

      expect(best, isNotNull);
      expect(best!.candidate.price, equals(3.99));
      expect(best.candidate.inStock, isTrue);
    });

    test('weak name-search results are rejected', () {
      final target = StoreMatchTarget.fromProduct(
        const Product(
          id: '777',
          name: 'Organic Tomato Soup 18 oz',
          brand: 'Pacific Foods',
          ingredients: [],
          categoryTags: ['en:soups'],
        ),
      );

      final best = StoreMatchUtil.pickBestCandidate(
        target: target,
        minConfidence: StoreMatchUtil.nameSearchThreshold,
        candidates: [
          _candidate(
            title: 'Chicken Broth 32 oz',
            brand: 'Store Brand',
            price: 1.99,
          ),
          _candidate(
            title: 'Vegetable Stock 32 oz',
            brand: 'Store Brand',
            price: 2.19,
          ),
        ],
      );

      expect(best, isNull);
    });
  });
}
