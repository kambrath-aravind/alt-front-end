import '../../models/product.dart';
import 'dietary_filter.dart';

class BloodSugarFilter implements DietaryFilter {
  @override
  bool isViolation(Product product) {
    final sugar = product.nutriments['sugars_100g'] ?? 0;
    return sugar > 5.0;
  }

  @override
  String violationReason(Product product) {
    final sugar = product.nutriments['sugars_100g'] ?? 0;
    return '$sugar g of sugar per 100g. Too high for Blood Sugar focus.';
  }

  @override
  String calculateBenefit(Product original, Product alternative) {
    final origSugar = original.nutriments['sugars_100g'] ?? 0;
    final altSugar = alternative.nutriments['sugars_100g'] ?? 0;
    final diff = origSugar - altSugar;
    if (diff > 0) {
      return '-${diff.toStringAsFixed(1)}g Sugar per 100g';
    }
    return 'Lower Glycemic Impact';
  }
}
