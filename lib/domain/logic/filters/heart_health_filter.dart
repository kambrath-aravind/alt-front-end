import '../../models/product.dart';
import 'dietary_filter.dart';

class HeartHealthFilter implements DietaryFilter {
  @override
  bool isViolation(Product product) {
    final sodium = product.nutriments['salt_100g'] ?? 0;
    if (sodium > 1.2) return true; // >1.2g salt roughly means High Sodium

    final saturatedFat = product.nutriments['saturated-fat_100g'] ?? 0;
    if (saturatedFat > 5.0) return true;

    final totalFat = product.nutriments['fat_100g'] ?? 0;
    if (totalFat > 17.5) return true; // High Total Fat

    final cholesterol = product.nutriments['cholesterol_100g'] ?? 0;
    if (cholesterol > 0.06) return true; // High Cholesterol

    return false;
  }

  @override
  double score(Product product) {
    double currentScore = 1.0;
    
    final sodium = product.nutriments['salt_100g'] ?? 0;
    if (sodium > 1.2) currentScore -= 0.5;

    final saturatedFat = product.nutriments['saturated-fat_100g'] ?? 0;
    if (saturatedFat > 5.0) currentScore -= 0.5;

    final totalFat = product.nutriments['fat_100g'] ?? 0;
    if (totalFat > 17.5) currentScore -= 0.3;

    final cholesterol = product.nutriments['cholesterol_100g'] ?? 0;
    if (cholesterol > 0.06) currentScore -= 0.5;

    return currentScore < 0.0 ? 0.0 : currentScore;
  }

  @override
  List<String> violationReasons(Product product) {
    return ['High in Sodium, Fats, or Cholesterol.'];
  }

  @override
  String calculateBenefit(Product original, Product alternative) {
    final origSodium = original.nutriments['salt_100g'] ?? 0;
    final altSodium = alternative.nutriments['salt_100g'] ?? 0;
    final diff = origSodium - altSodium;
    if (diff > 0) {
      return '-${diff.toStringAsFixed(1)}g Salt per 100g';
    }
    return 'Heart Healthy Choice';
  }
}
