import '../../models/product.dart';

class NormalizationResult {
  final bool success;
  final String basis; // "volume" | "weight" | "count" | "none"
  final double? normalizedTotal;
  final String? normalizedUnit;
  final String parseReason;
  final String confidence; // "high" | "medium" | "low"

  NormalizationResult({
    required this.success,
    required this.basis,
    this.normalizedTotal,
    this.normalizedUnit,
    required this.parseReason,
    required this.confidence,
  });
}

class QuantityNormalizationUtil {
  static final RegExp _volumeRegex =
      RegExp(r'([\d.]+)\s*(ml|l|fl\s*oz|fluid\s*oz)', caseSensitive: false);
  static final RegExp _weightRegex =
      RegExp(r'([\d.]+)\s*(g|kg|oz|lb|lbs)', caseSensitive: false);
  static final RegExp _countRegex =
      RegExp(r'([\d.]+)\s*(pack|pk|ct|count|cans|bottles)', caseSensitive: false);
  static final RegExp _multipackRegex = RegExp(
      r'(\d+)\s*(?:pack|pk|cans|bottles|cups|pouches)[\s\w-]*?(\d*\.?\d+)\s*(ml|l|fl\s*oz|fluid\s*oz|g|kg|oz|lb|lbs)',
      caseSensitive: false);
  static final RegExp _ambiguousRegex =
      RegExp(r'(family size|party size|variety pack|single serve|multipack)', caseSensitive: false);

  /// Analyzes a product and attempts to normalize its quantity to a standard basis.
  static NormalizationResult normalizeComparableQuantity(Product product) {
    final title = product.name.toLowerCase();
    
    // We try to extract quantity from title or product tags if available.
    // In OpenFoodFacts, 'quantity' field might not be exposed on the Product model currently, 
    // so we parse the title for now.
    
    // 1. Check for ambiguous multipack phrases without clear sizes
    if (_ambiguousRegex.hasMatch(title)) {
      // It's ambiguous unless we find very strong structured data
      // For now, let's look for explicit multipack structure: e.g. "12 pack of 12 fl oz"
      final multiMatch = _multipackRegex.firstMatch(title);
      if (multiMatch != null) {
        final count = double.tryParse(multiMatch.group(1) ?? '1') ?? 1;
        final size = double.tryParse(multiMatch.group(2) ?? '0') ?? 0;
        final unit = multiMatch.group(3)?.toLowerCase() ?? '';
        
        return _processUnit(title, size * count, unit, product, isMultipack: true);
      }
      return NormalizationResult(
        success: false,
        basis: "none",
        parseReason: "Title contains ambiguous quantity phrases: family/party size or variety pack",
        confidence: "low",
      );
    }

    // Check for explicit multipack pattern "12 pack 12 oz" or "12 cans 12 fl oz"
    final multiMatch = _multipackRegex.firstMatch(title);
    if (multiMatch != null) {
        final count = double.tryParse(multiMatch.group(1) ?? '1') ?? 1;
        final size = double.tryParse(multiMatch.group(2) ?? '0') ?? 0;
        final unit = multiMatch.group(3)?.toLowerCase() ?? '';
        return _processUnit(title, size * count, unit, product, isMultipack: true);
    }

    // 2. Try to find Volume
    final volumeMatch = _volumeRegex.firstMatch(title);
    if (volumeMatch != null) {
      final value = double.tryParse(volumeMatch.group(1) ?? '0') ?? 0;
      final unit = volumeMatch.group(2)?.toLowerCase() ?? '';
      return _processUnit(title, value, unit, product);
    }

    // 3. Try to find Weight
    final weightMatch = _weightRegex.firstMatch(title);
    if (weightMatch != null) {
      final value = double.tryParse(weightMatch.group(1) ?? '0') ?? 0;
      final unit = weightMatch.group(2)?.toLowerCase() ?? '';
      return _processUnit(title, value, unit, product);
    }

    // 4. Try to find Count only if weight and volume fail
    final countMatch = _countRegex.firstMatch(title);
    if (countMatch != null) {
      final value = double.tryParse(countMatch.group(1) ?? '0') ?? 0;
      return NormalizationResult(
        success: true,
        basis: "count",
        normalizedTotal: value,
        normalizedUnit: "count",
        parseReason: "Parsed discrete count from title",
        confidence: "medium",
      );
    }

    return NormalizationResult(
      success: false,
      basis: "none",
      parseReason: "Could not parse identifiable quantity/size from product",
      confidence: "low",
    );
  }

  static NormalizationResult _processUnit(String title, double value, String unit, Product product, {bool isMultipack = false}) {
    // If unit is "oz", resolve ambiguity
    if (unit == "oz") {
      if (_isLikelyLiquid(title, product)) {
        unit = "fl oz";
      } else if (_isLikelySolid(title, product)) {
        unit = "oz_weight";
      } else {
        return NormalizationResult(
          success: false,
          basis: "none",
          parseReason: "Ambiguous 'oz' unit, cannot confidently determine if fluid or weight",
          confidence: "low",
        );
      }
    }

    // Volume normalization (normalize to ml)
    if (unit == "ml" || unit == "l" || unit == "fl oz" || unit == "fluid oz") {
      double normalized = value;
      if (unit == "l") normalized = value * 1000;
      if (unit == "fl oz" || unit == "fluid oz") normalized = value * 29.5735;
      
      return NormalizationResult(
        success: true,
        basis: "volume",
        normalizedTotal: normalized,
        normalizedUnit: "ml",
        parseReason: isMultipack ? "Parsed multipack volume and normalized to ml" : "Parsed volume and normalized to ml",
        confidence: "high",
      );
    }

    // Weight normalization (normalize to grams)
    if (unit == "g" || unit == "kg" || unit == "oz_weight" || unit == "lb" || unit == "lbs") {
      double normalized = value;
      if (unit == "kg") normalized = value * 1000;
      if (unit == "oz_weight") normalized = value * 28.3495;
      if (unit == "lb" || unit == "lbs") normalized = value * 453.592;

      return NormalizationResult(
        success: true,
        basis: "weight",
        normalizedTotal: normalized,
        normalizedUnit: "g",
        parseReason: isMultipack ? "Parsed multipack weight and normalized to grams" : "Parsed weight and normalized to grams",
        confidence: "high",
      );
    }

    return NormalizationResult(
      success: false,
      basis: "none",
      parseReason: "Unsupported unit",
      confidence: "low",
    );
  }

  static bool _isLikelyLiquid(String title, Product product) {
    final liquidKeywords = ['drink', 'soda', 'water', 'juice', 'milk', 'beverage', 'tea', 'coffee', 'liquid', 'oil', 'vinegar'];
    if (liquidKeywords.any((k) => title.contains(k))) return true;

    final tags = product.categoryTags.join(' ').toLowerCase() + ' ' + (product.comparedToCategory ?? '').toLowerCase();
    if (liquidKeywords.any((k) => tags.contains(k))) return true;

    return false;
  }

  static bool _isLikelySolid(String title, Product product) {
    final solidKeywords = ['snack', 'chip', 'cookie', 'bread', 'meat', 'cheese', 'pasta', 'cereal', 'bar', 'nut', 'candy'];
    if (solidKeywords.any((k) => title.contains(k))) return true;

    final tags = product.categoryTags.join(' ').toLowerCase() + ' ' + (product.comparedToCategory ?? '').toLowerCase();
    if (solidKeywords.any((k) => tags.contains(k))) return true;

    return false;
  }
}
