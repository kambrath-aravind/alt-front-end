import 'package:flutter_test/flutter_test.dart';
import 'dart:developer';
import 'package:alt/core/data/repositories/product_repository.dart';

void main() {
  test('Verify valid Coca-Cola barcode works', () async {
    final repository = ProductRepository();
    const validBarcode = '5449000054227';
    log('Testing getProduct with valid barcode: $validBarcode');

    final product = await repository.getProduct(validBarcode);

    expect(product, isNotNull,
        reason: 'Should return a product for valid barcode');
    log('Successfully fetched: ${product!.name}');
  });
}
