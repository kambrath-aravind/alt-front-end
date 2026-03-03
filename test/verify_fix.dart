import 'package:flutter_test/flutter_test.dart';
import 'package:alt/data/repositories/product_repository.dart';

void main() {
  test('Verify valid Coca-Cola barcode works', () async {
    final repository = ProductRepository();
    const validBarcode = '5449000054227';
    print('Testing getProduct with valid barcode: $validBarcode');

    final product = await repository.getProduct(validBarcode);

    expect(product, isNotNull,
        reason: 'Should return a product for valid barcode');
    print('Successfully fetched: ${product!.name}');
  });
}
