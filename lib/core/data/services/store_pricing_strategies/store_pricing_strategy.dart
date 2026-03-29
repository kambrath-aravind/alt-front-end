import 'package:alt/core/domain/models/pricing_result.dart';

abstract class StorePricingStrategy {
  Future<PricingResult<Map<String, dynamic>>> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  );
}
