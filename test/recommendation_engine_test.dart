import 'package:flutter_test/flutter_test.dart';
import 'package:alt/domain/models/product.dart';
import 'package:alt/domain/logic/recommendation_engine.dart';

void main() {
  group('RecommendationEngine', () {
    group('jaccardSimilarity', () {
      test('returns 1.0 for identical ingredient lists', () {
        final a = ['cocoa', 'sugar', 'salt'];
        final b = ['cocoa', 'sugar', 'salt'];

        expect(RecommendationEngine.jaccardSimilarity(a, b), 1.0);
      });

      test('returns 0.0 for completely different ingredients', () {
        final a = ['cocoa', 'sugar'];
        final b = ['milk', 'water'];

        expect(RecommendationEngine.jaccardSimilarity(a, b), 0.0);
      });

      test('returns correct value for partial overlap', () {
        // Intersection: {cocoa, sugar} = 2
        // Union: {cocoa, sugar, salt, vanilla} = 4
        // Jaccard = 2/4 = 0.5
        final a = ['cocoa', 'sugar', 'salt'];
        final b = ['cocoa', 'sugar', 'vanilla'];

        expect(RecommendationEngine.jaccardSimilarity(a, b), 0.5);
      });

      test('handles case insensitivity', () {
        final a = ['Cocoa', 'SUGAR'];
        final b = ['cocoa', 'sugar'];

        expect(RecommendationEngine.jaccardSimilarity(a, b), 1.0);
      });

      test('handles whitespace trimming', () {
        final a = ['  cocoa  ', 'sugar'];
        final b = ['cocoa', '  sugar  '];

        expect(RecommendationEngine.jaccardSimilarity(a, b), 1.0);
      });

      test('returns 1.0 for both empty lists', () {
        expect(RecommendationEngine.jaccardSimilarity([], []), 1.0);
      });

      test('returns 0.0 when one list is empty', () {
        expect(RecommendationEngine.jaccardSimilarity(['cocoa'], []), 0.0);
        expect(RecommendationEngine.jaccardSimilarity([], ['cocoa']), 0.0);
      });
    });

    group('Use-case matching', () {
      test('cocoa powder should not match chocolate bar based on leaf category',
          () {
        // This test validates that products with different leaf categories
        // won't be recommended to each other.
        final cocoaPowder = Product(
          id: '1',
          name: 'Ghirardelli Cocoa Powder',
          brand: 'Ghirardelli',
          categoryTags: [
            'en:cocoa-and-its-products',
            'en:cocoas',
            'en:unsweetened-cocoa-powders',
          ],
          ingredients: ['cocoa', 'alkali'],
          nutriScore: 'b',
        );

        final chocolateBar = Product(
          id: '2',
          name: 'Lindt Dark Chocolate',
          brand: 'Lindt',
          categoryTags: [
            'en:cocoa-and-its-products',
            'en:chocolates',
            'en:dark-chocolates',
          ],
          ingredients: ['cocoa butter', 'sugar', 'milk', 'vanilla'],
          nutriScore: 'a',
        );

        // Their ingredient similarity should be low
        final similarity = RecommendationEngine.jaccardSimilarity(
          cocoaPowder.ingredients,
          chocolateBar.ingredients,
        );

        // Cocoa powder ingredients: {cocoa, alkali}
        // Chocolate bar ingredients: {cocoa butter, sugar, milk, vanilla}
        // No exact match (cocoa != cocoa butter)
        expect(similarity, 0.0);
      });

      test('similar cocoa powders should have high ingredient similarity', () {
        final ghirardelli = Product(
          id: '1',
          name: 'Ghirardelli Cocoa Powder',
          brand: 'Ghirardelli',
          categoryTags: ['en:unsweetened-cocoa-powders'],
          ingredients: ['cocoa', 'alkali'],
          nutriScore: 'b',
        );

        final hersheys = Product(
          id: '2',
          name: 'Hersheys Cocoa',
          brand: 'Hersheys',
          categoryTags: ['en:unsweetened-cocoa-powders'],
          ingredients: ['cocoa', 'alkali', 'salt'],
          nutriScore: 'a',
        );

        final similarity = RecommendationEngine.jaccardSimilarity(
          ghirardelli.ingredients,
          hersheys.ingredients,
        );

        // Intersection: {cocoa, alkali} = 2
        // Union: {cocoa, alkali, salt} = 3
        // Jaccard = 2/3 ≈ 0.67
        expect(similarity, closeTo(0.67, 0.01));
      });
    });
  });
}
