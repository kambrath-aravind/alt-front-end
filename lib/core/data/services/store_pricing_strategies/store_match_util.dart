import 'package:alt/core/domain/logic/pricing/quantity_normalization_util.dart';
import 'package:alt/core/domain/models/product.dart';

class StoreMatchTarget {
  final String name;
  final String? brand;
  final String? barcode;

  const StoreMatchTarget({
    required this.name,
    this.brand,
    this.barcode,
  });

  factory StoreMatchTarget.fromProduct(Product product) {
    return StoreMatchTarget(
      name: product.name,
      brand: product.brand,
      barcode: product.id,
    );
  }

  factory StoreMatchTarget.fromSearchQuery({
    required String queryName,
    String? barcode,
    String? brand,
  }) {
    return StoreMatchTarget(
      name: queryName,
      brand: brand,
      barcode: barcode,
    );
  }
}

class StoreCatalogCandidate {
  final String title;
  final String? brand;
  final String? upc;
  final String? packageText;
  final double price;
  final bool inStock;
  final Map<String, dynamic> pricingPayload;

  const StoreCatalogCandidate({
    required this.title,
    this.brand,
    this.upc,
    this.packageText,
    required this.price,
    required this.inStock,
    required this.pricingPayload,
  });

  String get searchableText => [title, packageText]
      .where((part) => part != null && part!.trim().isNotEmpty)
      .map((part) => part!.trim())
      .join(' ');
}

class StoreCandidateMatch {
  final StoreCatalogCandidate candidate;
  final double confidence;
  final bool exactBarcodeMatch;

  const StoreCandidateMatch({
    required this.candidate,
    required this.confidence,
    required this.exactBarcodeMatch,
  });
}

class StoreMatchUtil {
  static const double nameSearchThreshold = 0.50;
  static const double upcSearchThreshold = 0.42;

  static List<StoreCandidateMatch> rankCandidates({
    required StoreMatchTarget target,
    required List<StoreCatalogCandidate> candidates,
  }) {
    final ranked = candidates
        .map(
          (candidate) => StoreCandidateMatch(
            candidate: candidate,
            confidence: scoreCandidate(
              target: target,
              candidate: candidate,
            ),
            exactBarcodeMatch:
                _isExactBarcodeMatch(target.barcode, candidate.upc),
          ),
        )
        .toList();

    ranked.sort((a, b) {
      if (a.exactBarcodeMatch != b.exactBarcodeMatch) {
        return a.exactBarcodeMatch ? -1 : 1;
      }

      final confidenceCompare = b.confidence.compareTo(a.confidence);
      if (confidenceCompare != 0) return confidenceCompare;

      if (a.candidate.inStock != b.candidate.inStock) {
        return a.candidate.inStock ? -1 : 1;
      }

      return a.candidate.price.compareTo(b.candidate.price);
    });

    return ranked;
  }

  static StoreCandidateMatch? pickBestCandidate({
    required StoreMatchTarget target,
    required List<StoreCatalogCandidate> candidates,
    required double minConfidence,
  }) {
    final ranked = rankCandidates(
      target: target,
      candidates: candidates,
    );
    if (ranked.isEmpty) return null;

    final exactBarcodeMatches = ranked
        .where((match) => match.exactBarcodeMatch)
        .toList(growable: false);
    if (exactBarcodeMatches.isNotEmpty) {
      exactBarcodeMatches.sort(_candidatePreferenceSort);
      return exactBarcodeMatches.first;
    }

    final acceptable = ranked
        .where((match) => match.confidence >= minConfidence)
        .toList(growable: false);
    if (acceptable.isEmpty) return null;

    acceptable.sort(_candidatePreferenceSort);
    return acceptable.first;
  }

  static double scoreCandidate({
    required StoreMatchTarget target,
    required StoreCatalogCandidate candidate,
  }) {
    if (_isExactBarcodeMatch(target.barcode, candidate.upc)) {
      return 1.0;
    }

    final tokenScore =
        _tokenSimilarityScore(target.name, candidate.searchableText);
    final brandScore = _brandScore(target.brand, candidate.brand);
    final quantityCompatibility = _quantityCompatibilityScore(
      target: target,
      candidate: candidate,
    );
    final containmentScore =
        _titleContainmentScore(target.name, candidate.searchableText);
    final variantPenalty =
        _variantMismatchPenalty(target.name, candidate.searchableText);

    final total = (tokenScore * 0.45) +
        (brandScore * 0.15) +
        (quantityCompatibility.score * 0.25) +
        (containmentScore * 0.15) -
        quantityCompatibility.penalty -
        variantPenalty;

    return total.clamp(0.0, 0.99);
  }

  static int _candidatePreferenceSort(
    StoreCandidateMatch a,
    StoreCandidateMatch b,
  ) {
    if (a.candidate.inStock != b.candidate.inStock) {
      return a.candidate.inStock ? -1 : 1;
    }

    final priceCompare = a.candidate.price.compareTo(b.candidate.price);
    if (priceCompare != 0) return priceCompare;

    return b.confidence.compareTo(a.confidence);
  }

  static bool _isExactBarcodeMatch(
      String? targetBarcode, String? candidateUpc) {
    final normalizedTarget = _normalizeBarcode(targetBarcode);
    final normalizedCandidate = _normalizeBarcode(candidateUpc);
    return normalizedTarget != null &&
        normalizedCandidate != null &&
        normalizedTarget == normalizedCandidate;
  }

  static String? _normalizeBarcode(String? barcode) {
    if (barcode == null) return null;
    final digitsOnly = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;
    final trimmed = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
    return trimmed.isEmpty ? digitsOnly : trimmed;
  }

  static double _tokenSimilarityScore(String targetName, String candidateText) {
    final targetTokens = _tokenize(targetName);
    final candidateTokens = _tokenize(candidateText);

    if (targetTokens.isEmpty || candidateTokens.isEmpty) {
      return 0.0;
    }

    final intersectSet = targetTokens.intersection(candidateTokens);
    double intersectWeight = 0;
    for (final t in intersectSet) {
      final len = t.length;
      intersectWeight += len * len * len;
    }

    double targetTotalWeight = 0;
    for (final t in targetTokens) {
      final len = t.length;
      targetTotalWeight += len * len * len;
    }

    double candidateTotalWeight = 0;
    for (final t in candidateTokens) {
      final len = t.length;
      candidateTotalWeight += len * len * len;
    }

    final recall = targetTotalWeight > 0 ? intersectWeight / targetTotalWeight : 0.0;
    final precision = candidateTotalWeight > 0 ? intersectWeight / candidateTotalWeight : 0.0;
    return ((recall * 0.4) + (precision * 0.6)).clamp(0.0, 1.0);
  }

  static double _brandScore(String? targetBrand, String? candidateBrand) {
    final normalizedTarget = _normalizeText(targetBrand);
    final normalizedCandidate = _normalizeText(candidateBrand);

    if (normalizedTarget.isEmpty) {
      return 0.0;
    }
    if (normalizedCandidate.isEmpty) {
      return 0.1;
    }

    if (normalizedTarget == normalizedCandidate) return 1.0;
    if (normalizedTarget.contains(normalizedCandidate) ||
        normalizedCandidate.contains(normalizedTarget)) {
      return 0.75;
    }

    return 0.0;
  }

  static double _titleContainmentScore(
    String targetName,
    String candidateText,
  ) {
    final normalizedTarget = _normalizeText(targetName);
    final normalizedCandidate = _normalizeText(candidateText);

    if (normalizedTarget.isEmpty || normalizedCandidate.isEmpty) {
      return 0.0;
    }

    if (normalizedTarget == normalizedCandidate) return 1.0;
    if (normalizedCandidate.contains(normalizedTarget) ||
        normalizedTarget.contains(normalizedCandidate)) {
      return 0.8;
    }

    return 0.0;
  }

  static _QuantityCompatibility _quantityCompatibilityScore({
    required StoreMatchTarget target,
    required StoreCatalogCandidate candidate,
  }) {
    final targetProduct = Product(
      id: 'target',
      name: target.name,
      brand: target.brand ?? '',
      ingredients: const [],
      categoryTags: const [],
    );
    final candidateProduct = Product(
      id: 'candidate',
      name: candidate.searchableText,
      brand: candidate.brand ?? '',
      ingredients: const [],
      categoryTags: const [],
    );

    final targetNorm =
        QuantityNormalizationUtil.normalizeComparableQuantity(targetProduct);
    final candidateNorm =
        QuantityNormalizationUtil.normalizeComparableQuantity(candidateProduct);

    if (targetNorm.success && candidateNorm.success) {
      if (targetNorm.basis != candidateNorm.basis) {
        return const _QuantityCompatibility(score: 0.0, penalty: 0.25);
      }

      final targetTotal = targetNorm.normalizedTotal!;
      final candidateTotal = candidateNorm.normalizedTotal!;
      final maxTotal =
          targetTotal > candidateTotal ? targetTotal : candidateTotal;
      if (maxTotal <= 0) {
        return const _QuantityCompatibility(score: 0.0);
      }

      final relativeDiff = (targetTotal - candidateTotal).abs() / maxTotal;
      final penalty = relativeDiff > 0.35 ? 0.25 : 0.0;
      return _QuantityCompatibility(
        score: (1.0 - relativeDiff).clamp(0.0, 1.0),
        penalty: penalty,
      );
    }

    if (targetNorm.success != candidateNorm.success) {
      return const _QuantityCompatibility(score: 0.1, penalty: 0.1);
    }

    return const _QuantityCompatibility(score: 0.35);
  }

  static double _variantMismatchPenalty(
      String targetName, String candidateText) {
    final targetVariants = _variantDimensions(targetName);
    final candidateVariants = _variantDimensions(candidateText);

    var penalty = 0.0;
    for (final dimension in _variantGroups.keys) {
      final targetVariant = targetVariants[dimension];
      final candidateVariant = candidateVariants[dimension];

      if (targetVariant != null &&
          candidateVariant != null &&
          targetVariant != candidateVariant) {
        penalty += 0.24;
        continue;
      }

      if (targetVariant != null && candidateVariant == null) {
        penalty += 0.08;
      } else if (targetVariant == null && candidateVariant != null) {
        penalty += 0.08;
      }
    }

    return penalty.clamp(0.0, 0.20);
  }

  static Map<String, String> _variantDimensions(String text) {
    final normalized = _normalizeText(text);
    final variants = <String, String>{};

    for (final entry in _variantGroups.entries) {
      for (final token in entry.value) {
        if (normalized.contains(token)) {
          variants[entry.key] = token;
          break;
        }
      }
    }

    return variants;
  }

  static Set<String> _tokenize(String text) {
    return _normalizeText(text)
        .split(' ')
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .map((token) {
      if (token.length < 4) return token;
      if (token.endsWith('ies')) return '${token.substring(0, token.length - 3)}y';
      if (token.endsWith('es')) return token.substring(0, token.length - 2);
      if (token.endsWith('s')) return token.substring(0, token.length - 1);
      return token;
    }).toSet();
  }

  static String _normalizeText(String? text) {
    if (text == null) return '';
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const Map<String, List<String>> _variantGroups = {
    'sweetener': [
      'diet',
      'zero sugar',
      'zero',
      'sugar free',
      'no sugar',
      'regular',
      'classic',
      'original',
    ],
    'flavor': [
      'plain',
      'unflavored',
      'vanilla',
      'chocolate',
      'strawberry',
      'berry',
      'lemon',
      'lime',
      'orange',
      'cherry',
      'grape',
      'peanut butter',
      'caramel',
    ],
    'texture': [
      'crunchy',
      'creamy',
    ],
    'salt': [
      'salted',
      'unsalted',
    ],
    'heat': [
      'mild',
      'spicy',
      'hot',
    ],
    'fat': [
      'whole milk',
      'skim',
      '1 milk',
      '2 milk',
    ],
  };

  static const Set<String> _stopWords = {
    'and',
    'for',
    'the',
    'with',
    'from',
    'pack',
    'count',
    'ct',
    'oz',
    'ml',
    'l',
    'lb',
    'lbs',
    'g',
    'kg',
    'fl',
    'fluid',
    'original',
    'premium',
    'classic',
    'style',
    'natural',
    'pure',
    'best',
    'great',
  };
}

class _QuantityCompatibility {
  final double score;
  final double penalty;

  const _QuantityCompatibility({
    required this.score,
    this.penalty = 0.0,
  });
}
