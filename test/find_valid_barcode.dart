import 'package:flutter_test/flutter_test.dart';
import 'dart:developer';
import 'package:alt/data/repositories/product_repository.dart';

void main() {
  test('Find valid Coca-Cola barcode', () async {
    final repository = ProductRepository();
    final products = await repository.searchProductsByCategory('en:sodas');

    if (products.isNotEmpty) {
      final validProduct = products.first;
      log('Found valid product: ${validProduct.name}');
      log('Barcode: ${validProduct.id}');
    } else {
      log('No products found in search.');
    }
  });
}
