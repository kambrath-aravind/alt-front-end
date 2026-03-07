import 'package:flutter_test/flutter_test.dart';
import 'dart:developer';
import 'package:alt/data/repositories/product_repository.dart';

void main() {
  test('ProductRepository.searchProducts fetches data from internet', () async {
    final repository = ProductRepository();
    // Use a common category likely to have results
    const category = 'en:sodas';
    log('Testing searchProducts with category: $category');

    final products = await repository.searchProductsByCategory(category);

    log('Fetched ${products.length} products.');
    for (var p in products) {
      log(' - ${p.name} (${p.brand})');
    }

    expect(products, isNotEmpty, reason: 'Should return a list of products');
  });
}
