import '../../models/product.dart';
import 'dietary_filter.dart';

class CleanIngredientsFilter implements DietaryFilter {
  @override
  bool isViolation(Product product) {
    // 1. Check NutriScore
    if (product.nutriScore?.toLowerCase() == 'e') return true;

    // 2. Check raw text
    final ingredientsText = product.ingredients.join(' ').toLowerCase();

    // Comprehensive list of unclean/artificial ingredients
    final List<String> uncleanIngredients = [
      'msg',
      'monosodium glutamate',
      'artificial',
      'red 40',
      'yellow 5',
      'yellow 6',
      'blue 1',
      'blue 2',
      'canola',
      'soybean oil',
      'cottonseed',
      'high fructose corn syrup',
      'hfcs',
      'bht',
      'bha',
      'tbhq',
      'aspartame',
      'sucralose',
      'saccharin',
      'acesulfame',
      'carrageenan',
      'potassium bromate',
      'partially hydrogenated', // Trans fats
      'sodium nitrite',
      'sodium nitrate',
    ];

    for (final badIngredient in uncleanIngredients) {
      if (ingredientsText.contains(badIngredient)) {
        return true;
      }
    }

    // 3. Check standardized OpenFoodFacts ingredient tags (European formatting)
    final tagsText = product.ingredientsTags.join(' ').toLowerCase();
    final List<String> badTags = [
      'en:added-sugar', // Captures HFCS and other highly processed sugars
      'en:e150', // Caramel color (artificial dye)
      'en:e338', // Phosphoric acid (soda additive)
      'en:e211', // Sodium benzoate (preservative)
      'en:e951', // Aspartame
      'en:e955', // Sucralose
    ];

    for (final badTag in badTags) {
      if (tagsText.contains(badTag)) {
        return true;
      }
    }

    return false;
  }

  @override
  String violationReason(Product product) {
    if (product.nutriScore?.toLowerCase() == 'e')
      return 'Has a NutriScore of E (lowest nutritional quality).';
    return 'Contains artificial additives, dyes, added sugars, or industrial seed oils.';
  }

  @override
  String calculateBenefit(Product original, Product alternative) {
    return 'Cleaner Ingredients / Less Processed';
  }
}
