import '../../models/product.dart';

abstract class DietaryFilter {
  /// Returns `true` if the product VIOLATES the dietary restriction.
  bool isViolation(Product product);

  /// Generates a brief, punchy text explaining *why* the product failed.
  String violationReason(Product product);

  /// Calculates a benefit string comparing the alternative to the original.
  String calculateBenefit(Product original, Product alternative);
}
