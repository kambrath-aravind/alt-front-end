import '../../models/product.dart';
import 'dietary_filter.dart';

class GlutenFreeFilter implements DietaryFilter {
  @override
  bool isViolation(Product product) {
    final ingredientsText = product.ingredients.join(' ').toLowerCase();
    return ingredientsText.contains('wheat') ||
        ingredientsText.contains('barley') ||
        ingredientsText.contains('rye') ||
        ingredientsText.contains('gluten');
  }

  @override
  double score(Product product) {
    return isViolation(product) ? 0.0 : 1.0;
  }

  @override
  List<String> violationReasons(Product product) {
    return ['Contains gluten (wheat/barley/rye).'];
  }

  @override
  String calculateBenefit(Product original, Product alternative) {
    return '100% Gluten Free';
  }
}
