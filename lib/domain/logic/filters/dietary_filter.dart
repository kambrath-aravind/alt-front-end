import '../../models/product.dart';

abstract class DietaryFilter {
  /// Returns `true` if the product VIOLATES the dietary restriction.
  bool isViolation(Product product);

  /// Returns a score from 0.0 to 1.0 representing how healthy the product is.
  double score(Product product);

  /// Generates a list of brief, punchy texts explaining *why* the product failed.
  List<String> violationReasons(Product product);

  /// Calculates a benefit string comparing the alternative to the original.
  String calculateBenefit(Product original, Product alternative);
}
