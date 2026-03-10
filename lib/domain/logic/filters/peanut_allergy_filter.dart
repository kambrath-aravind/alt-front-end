import '../../models/product.dart';
import 'dietary_filter.dart';

class PeanutAllergyFilter implements DietaryFilter {
  @override
  bool isViolation(Product product) {
    final ingredientsText = product.ingredients.join(' ').toLowerCase();
    return ingredientsText.contains('peanut') ||
        ingredientsText.contains('tree nut');
  }

  @override
  double score(Product product) {
    return isViolation(product) ? 0.0 : 1.0;
  }

  @override
  List<String> violationReasons(Product product) {
    return ['Contains peanuts or tree nuts.'];
  }

  @override
  String calculateBenefit(Product original, Product alternative) {
    return 'Peanut & Tree Nut Free';
  }
}
