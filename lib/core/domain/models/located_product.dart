import 'product.dart';

/// Represents a Product that has been located at a nearby store
/// with pricing information. Used when the user keeps the original
/// scanned item (no alternative swap).
class LocatedProduct {
  final Product product;
  final double price;
  final String storeName;
  final String storeDistance;
  final String? storeAddress;

  const LocatedProduct({
    required this.product,
    required this.price,
    required this.storeName,
    required this.storeDistance,
    this.storeAddress,
  });

  LocatedProduct copyWith({
    Product? product,
    double? price,
    String? storeName,
    String? storeDistance,
    String? storeAddress,
  }) {
    return LocatedProduct(
      product: product ?? this.product,
      price: price ?? this.price,
      storeName: storeName ?? this.storeName,
      storeDistance: storeDistance ?? this.storeDistance,
      storeAddress: storeAddress ?? this.storeAddress,
    );
  }
}
