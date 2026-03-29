import 'package:alt/core/domain/models/product.dart';
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
  double score(Product product) {
    double currentScore = 1.0;

    if (product.nutriScore?.toLowerCase() == 'e') currentScore -= 0.4;

    final ingredientsText = product.ingredients.join(' ').toLowerCase();
    
    // Grouping triggers for more nuanced scoring
    final msgTriggers = ['msg', 'monosodium glutamate'];
    final seedOilTriggers = ['canola', 'soybean oil', 'cottonseed'];
    final dyeTriggers = ['red 40', 'yellow 5', 'yellow 6', 'blue 1', 'blue 2'];
    final otherUnclean = [
      'artificial', 'high fructose corn syrup', 'hfcs', 'bht', 'bha', 'tbhq',
      'aspartame', 'sucralose', 'saccharin', 'acesulfame', 'carrageenan',
      'potassium bromate', 'partially hydrogenated', 'sodium nitrite', 'sodium nitrate'
    ];

    if (msgTriggers.any((t) => ingredientsText.contains(t))) currentScore -= 0.3;
    if (seedOilTriggers.any((t) => ingredientsText.contains(t))) currentScore -= 0.3;
    if (dyeTriggers.any((t) => ingredientsText.contains(t))) currentScore -= 0.2;
    if (otherUnclean.any((t) => ingredientsText.contains(t))) currentScore -= 0.2;

    final tagsText = product.ingredientsTags.join(' ').toLowerCase();
    final badTags = ['en:added-sugar', 'en:e150', 'en:e338', 'en:e211', 'en:e951', 'en:e955'];
    if (badTags.any((t) => tagsText.contains(t))) currentScore -= 0.2;

    return currentScore < 0.0 ? 0.0 : currentScore;
  }

  @override
  List<String> violationReasons(Product product) {
    final reasons = <String>[];

    if (product.nutriScore?.toLowerCase() == 'e') {
      reasons.add('Has a NutriScore of E (lowest nutritional quality).');
    }

    final ingredientsText = product.ingredients.join(' ').toLowerCase();
    bool hasMsg = ingredientsText.contains('msg') || ingredientsText.contains('monosodium glutamate');
    if (hasMsg) reasons.add('Contains MSG or related additives.');

    bool hasSeedOils = ingredientsText.contains('canola') || ingredientsText.contains('soybean oil') || ingredientsText.contains('cottonseed');
    if (hasSeedOils) reasons.add('Contains industrial seed oils (e.g., canola, soybean oil).');

    bool hasArtificialDyes = ingredientsText.contains('red 40') || ingredientsText.contains('yellow 5') || ingredientsText.contains('yellow 6') || ingredientsText.contains('blue 1') || ingredientsText.contains('blue 2');
    if (hasArtificialDyes) reasons.add('Contains artificial dyes.');

    if (reasons.isEmpty && isViolation(product)) {
      reasons.add('Contains artificial additives, added sugars, or highly processed ingredients.');
    }

    return reasons;
  }

  @override
  String calculateBenefit(Product original, Product alternative) {
    return 'Cleaner Ingredients / Less Processed';
  }
}
