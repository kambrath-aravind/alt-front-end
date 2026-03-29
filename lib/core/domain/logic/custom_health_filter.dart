import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'filters/dietary_filter.dart';
import 'filters/blood_sugar_filter.dart';
import 'filters/peanut_allergy_filter.dart';
import 'filters/gluten_free_filter.dart';
import 'filters/heart_health_filter.dart';
import 'filters/clean_ingredients_filter.dart';

class CustomHealthFilter {
  final CleanIngredientsFilter _cleanIngredientsFilter =
      CleanIngredientsFilter();

  // The Registry mapping a DietRestriction to its specific logic class
  final Map<DietRestriction, DietaryFilter> _filters = {
    DietRestriction.bloodSugarFocus: BloodSugarFilter(),
    DietRestriction.peanutAllergy: PeanutAllergyFilter(),
    DietRestriction.glutenFree: GlutenFreeFilter(),
    DietRestriction.heartHealth: HeartHealthFilter(),
  };

  DietaryFilter? _getFilter(DietRestriction restriction) {
    return _filters[restriction];
  }

  /// Returns `true` if the product VIOLATES the user's dietary restriction.
  /// Returns `false` if it is SAFE to eat.
  bool isViolation(Product product, UserProfile profile) {
    if (_cleanIngredientsFilter.isViolation(product)) return true;
    if (profile.dietaryPreferences.isEmpty) return false;

    for (final diet in profile.dietaryPreferences) {
      final filter = _getFilter(diet);
      if (filter?.isViolation(product) ?? false) {
        return true;
      }
    }
    return false;
  }

  /// Generates a list of specific reasons explaining *why* the product failed.
  List<String> getViolationReasons(Product product, UserProfile profile) {
    List<String> reasons = [];

    if (_cleanIngredientsFilter.isViolation(product)) {
      reasons.addAll(_cleanIngredientsFilter.violationReasons(product));
    }

    if (profile.dietaryPreferences.isNotEmpty) {
      for (final diet in profile.dietaryPreferences) {
        final filter = _getFilter(diet);
        if (filter?.isViolation(product) ?? false) {
          final filterReasons = filter?.violationReasons(product);
          if (filterReasons != null && filterReasons.isNotEmpty) {
            reasons.addAll(filterReasons);
          }
        }
      }
    }
    return reasons.toSet().toList();
  }

  /// Calculates a holistic Alt Score from 0 to 100 based on all applicable filters.
  double getAltScore(Product product, UserProfile profile) {
    double totalScore = _cleanIngredientsFilter.score(product);
    double filterCount = 1.0;

    for (final diet in profile.dietaryPreferences) {
      final filter = _getFilter(diet);
      if (filter != null) {
        totalScore += filter.score(product);
        filterCount += 1.0;
      }
    }

    return (totalScore / filterCount) * 100.0;
  }

  /// Calculates a benefit string comparing the alternative to the original.
  String calculateBenefit(
      Product original, Product alternative, UserProfile profile) {
    List<String> benefits = [];

    if (_cleanIngredientsFilter.isViolation(original) &&
        !_cleanIngredientsFilter.isViolation(alternative)) {
      benefits
          .add(_cleanIngredientsFilter.calculateBenefit(original, alternative));
    }

    if (profile.dietaryPreferences.isNotEmpty) {
      for (final diet in profile.dietaryPreferences) {
        final filter = _getFilter(diet);
        final benefit = filter?.calculateBenefit(original, alternative);
        if (benefit != null &&
            benefit.isNotEmpty &&
            benefit != 'Better Alternative') {
          benefits.add(benefit);
        }
      }
    }
    return benefits.isNotEmpty ? benefits.join(', ') : 'Better Alternative';
  }
}
