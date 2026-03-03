import 'package:flutter_test/flutter_test.dart';
import 'package:alt/data/repositories/product_repository.dart';

void main() {
  test('ProductRepository returns null for invalid barcode', () async {
    final repository = ProductRepository();
    // Use a definitely invalid barcode
    const invalidBarcode = '0000000000000';
    print('Testing getProduct with invalid barcode: $invalidBarcode');

    final product = await repository.getProduct(invalidBarcode);

    if (product == null) {
      print('Product is null (Not Found) as expected.');
    } else {
      print('Product found: ${product.name}');
    }

    expect(product, isNull, reason: 'Should return null for invalid barcode');
  });
}
