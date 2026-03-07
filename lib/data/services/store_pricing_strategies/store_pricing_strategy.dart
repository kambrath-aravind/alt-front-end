abstract class StorePricingStrategy {
  Future<Map<String, dynamic>?> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  );
}
