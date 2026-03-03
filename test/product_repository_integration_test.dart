import 'package:flutter_test/flutter_test.dart';
import 'package:alt/data/repositories/product_repository.dart';

void main() {
  test('ProductRepository.searchProducts fetches data from internet', () async {
    final repository = ProductRepository();
    // Use a common category likely to have results
    const category = 'en:sodas';
    print('Testing searchProducts with category: $category');

    final products = await repository.searchProducts(category);

    print('Fetched ${products.length} products.');
    for (var p in products) {
      print(' - ${p.name} (${p.brand})');
    }

    expect(products, isNotEmpty, reason: 'Should return a list of products');
  });
}
