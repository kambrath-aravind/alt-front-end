import '../models/product.dart';
import '../models/user_profile.dart';
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

  /// Generates a brief, punchy text explaining *why* the product failed.
  String generateViolationReason(Product product, UserProfile profile) {
    List<String> reasons = [];

    if (_cleanIngredientsFilter.isViolation(product)) {
      reasons.add(_cleanIngredientsFilter.violationReason(product));
    }

    if (profile.dietaryPreferences.isNotEmpty) {
      for (final diet in profile.dietaryPreferences) {
        final filter = _getFilter(diet);
        if (filter?.isViolation(product) ?? false) {
          final reason = filter?.violationReason(product);
          if (reason != null && reason.isNotEmpty) {
            reasons.add(reason);
          }
        }
      }
    }
    return reasons.join('\n');
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
