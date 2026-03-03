import '../models/product.dart';

enum ProductGrade { a, b, c, d, e, unknown }

class HealthScorer {
  /// Calculates a unified grade for the product.
  /// Priority: NutriScore > NOVA > Ingredient Density
  ProductGrade calculateGrade(Product product) {
    // 1. Try Nutri-Score first (if valid)
    if (product.nutriScore != null) {
      final grade = _parseNutriScore(product.nutriScore!);
      if (grade != ProductGrade.unknown) {
        return grade;
      }
    }

    // 2. Fallback: Weighted Reinforcement Score
    final score = _calculateReinforcedScore(product);
    return _scoreToGrade(score);
  }

  /// Calculates a health score (0-100) based on multiple signals.
  /// Base: 50
  /// NOVA 1: +25, Ingredient count <= 5: +15, Low Sugar: +10, etc.
  double _calculateReinforcedScore(Product product) {
    double score = 50.0;

    // --- 1. Processing (NOVA) ---
    if (product.novaGroup != null) {
      switch (product.novaGroup!) {
        case 1:
          score += 25;
          break; // Unprocessed
        case 2:
          score += 10;
          break; // Processed culinary ingredients
        case 3:
          score -= 10;
          break; // Processed
        case 4:
          score -= 30;
          break; // Ultra-processed
      }
    }

    // --- 2. Ingredient Count (Clean Label) ---
    if (product.ingredients.isNotEmpty) {
      if (product.ingredients.length <= 5) {
        score += 15;
      } else if (product.ingredients.length > 15) {
        score -= 15;
      }
    }

    // --- 3. Nutrient Levels (per 100g) ---
    final n = product.nutriments;

    // Sugars
    if (n.containsKey('sugars_100g')) {
      final sugar = n['sugars_100g']!;
      if (sugar > 22.5)
        score -= 20; // High
      else if (sugar <= 5.0) score += 10; // Low
    }

    // Salt
    if (n.containsKey('salt_100g')) {
      final salt = n['salt_100g']!;
      if (salt > 1.5)
        score -= 20; // High
      else if (salt <= 0.3) score += 10; // Low
    }

    // Saturated Fat
    if (n.containsKey('saturated-fat_100g')) {
      final satFat = n['saturated-fat_100g']!;
      if (satFat > 5.0)
        score -= 15; // High
      else if (satFat <= 1.5) score += 10; // Low
    }

    // Good Nutrients (Fiber, Protein)
    if ((n['fiber_100g'] ?? 0) > 4.0) score += 5;
    if ((n['proteins_100g'] ?? 0) > 8.0) score += 5;

    // Clamp score
    return score.clamp(0.0, 100.0);
  }

  ProductGrade _scoreToGrade(double score) {
    if (score >= 80) return ProductGrade.a; // Strict A
    if (score >= 60) return ProductGrade.b;
    if (score >= 40) return ProductGrade.c;
    if (score >= 20) return ProductGrade.d;
    return ProductGrade.e;
  }

  ProductGrade _parseNutriScore(String score) {
    switch (score.toLowerCase()) {
      case 'a':
        return ProductGrade.a;
      case 'b':
        return ProductGrade.b;
      case 'c':
        return ProductGrade.c;
      case 'd':
        return ProductGrade.d;
      case 'e':
        return ProductGrade.e;
      default:
        return ProductGrade.unknown;
    }
  }

  /// Returns true if [candidate] is significantly healthier than [original]
  bool isHealthier(Product original, Product candidate) {
    final gradeOriginal = calculateGrade(original);
    final gradeCandidate = calculateGrade(candidate);

    return gradeCandidate.index < gradeOriginal.index; // a(0) < b(1)
  }
}
