import '../../models/product.dart';
import 'quantity_normalization_util.dart';

class ComparisonGateResult {
  final bool comparisonAvailable;
  final String? comparisonBasis; // "volume" | "weight" | "count" | "none"
  final double? originalNormalizedTotal;
  final double? alternativeNormalizedTotal;
  final double? equivalentAlternativeCost;
  final double? difference;
  final String direction; // "savings" | "loss" | "none"
  final String reason;

  ComparisonGateResult({
    required this.comparisonAvailable,
    this.comparisonBasis,
    this.originalNormalizedTotal,
    this.alternativeNormalizedTotal,
    this.equivalentAlternativeCost,
    this.difference,
    required this.direction,
    required this.reason,
  });
}

class ComparisonGate {
  static ComparisonGateResult canCompareProducts({
    required Product original,
    required Product alternative,
    required double originalPrice,
    required double alternativePrice,
  }) {
    final normOriginal = QuantityNormalizationUtil.normalizeComparableQuantity(original);
    final normAlternate = QuantityNormalizationUtil.normalizeComparableQuantity(alternative);

    if (!normOriginal.success) {
      return ComparisonGateResult(
        comparisonAvailable: false,
        direction: "none",
        reason: "Original product package size could not be determined (${normOriginal.parseReason})",
      );
    }

    if (!normAlternate.success) {
      return ComparisonGateResult(
        comparisonAvailable: false,
        direction: "none",
        reason: "Alternative product package size could not be determined (${normAlternate.parseReason})",
      );
    }

    if (normOriginal.basis != normAlternate.basis) {
      return ComparisonGateResult(
        comparisonAvailable: false,
        direction: "none",
        reason: "Package sizes could not be matched fairly (${normOriginal.basis} vs ${normAlternate.basis})",
      );
    }

    // Both are successful and have the same basis
    final origTotal = normOriginal.normalizedTotal!;
    final altTotal = normAlternate.normalizedTotal!;

    if (origTotal <= 0 || altTotal <= 0) {
      return ComparisonGateResult(
        comparisonAvailable: false,
        direction: "none",
        reason: "Invalid quantity <= 0",
      );
    }

    final alternativeUnitPrice = alternativePrice / altTotal;
    final equivalentAlternativeCost = alternativeUnitPrice * origTotal;
    final difference = equivalentAlternativeCost - originalPrice;

    String direction = "none";
    if (difference < -0.005) {
      direction = "savings"; // difference is negative e.g. -2.00, meaning alternative is cheaper
    } else if (difference > 0.005) {
      direction = "loss";
    }

    return ComparisonGateResult(
      comparisonAvailable: true,
      comparisonBasis: normOriginal.basis,
      originalNormalizedTotal: origTotal,
      alternativeNormalizedTotal: altTotal,
      equivalentAlternativeCost: equivalentAlternativeCost,
      difference: difference,
      direction: direction,
      reason: "Fair comparison available on ${normOriginal.basis} basis",
    );
  }
}
