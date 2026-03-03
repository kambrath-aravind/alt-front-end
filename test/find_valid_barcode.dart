import 'package:flutter_test/flutter_test.dart';
import 'package:alt/data/repositories/product_repository.dart';

void main() {
  test('Find valid Coca-Cola barcode', () async {
    final repository = ProductRepository();
    final products = await repository.searchProducts('en:sodas');

    if (products.isNotEmpty) {
      final validProduct = products.first;
      print('Found valid product: ${validProduct.name}');
      print('Barcode: ${validProduct.id}');
    } else {
      print('No products found in search.');
    }
  });
}
