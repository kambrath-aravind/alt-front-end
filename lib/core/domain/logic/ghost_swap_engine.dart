import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/located_product.dart';
import 'dart:async';
import 'package:alt/core/domain/models/user_profile.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';
import 'package:alt/core/domain/models/pricing_result.dart';
import 'package:alt/core/data/services/omni_store_service.dart';
import 'package:alt/core/data/repositories/rag_cache_repository.dart';
import 'package:alt/core/data/repositories/product_repository.dart';
import 'package:alt/core/config/app_config.dart';
import 'custom_health_filter.dart';
import 'semantic_service.dart';
import 'pricing/comparison_gate.dart';
import 'package:alt/utils/app_logger.dart';

class GhostSwapEngine {
  static const _tag = 'GhostSwapEngine';

  final ProductRepository _productRepository;
  final CustomHealthFilter _healthFilter;
  final SemanticService _semanticService;
  final OmniStoreService _omniStoreService;
  final RagCacheRepository _cacheRepository;

  GhostSwapEngine(
    this._productRepository,
    this._healthFilter,
    this._semanticService,
    this._omniStoreService,
    this._cacheRepository,
  );

  static ComparisonGateResult resolvePriceComparison({
    required Product original,
    required Product alternative,
    required double? originalPrice,
    required double alternativePrice,
  }) {
    if (originalPrice == null) {
      return ComparisonGateResult(
        comparisonAvailable: false,
        direction: 'none',
        reason:
            'Original product pricing unavailable, so savings could not be calculated.',
      );
    }

    return ComparisonGate.canCompareProducts(
      original: original,
      alternative: alternative,
      originalPrice: originalPrice,
      alternativePrice: alternativePrice,
    );
  }

  // ─── Main Pipeline ─────────────────────────────────────────────

  /// The main pipeline for the "Ghost Swap" mechanic.
  Future<List<SwapProposal>> getAlternatives(
      Product scannedProduct, UserProfile user) async {
    final isViolation = _healthFilter.isViolation(scannedProduct, user);

    if (!isViolation) {
      return [];
    }

    if (AppConfig.enableFirestoreCache) {
      final cachedProposal = await _cacheRepository.getCachedProposal(
          scannedProduct.id, user.dietaryPreferences);
      if (cachedProposal != null) {
        return [cachedProposal];
      }
    }

    final alternatives = await findAlternatives(scannedProduct, user);
    if (alternatives.isEmpty) return [];

    // Pre-fetch original pricing once
    final originalResult = await _omniStoreService.findLowestPriceNearby(
      scannedProduct.id,
      scannedProduct.name,
      user.defaultZipCode,
      user.searchRadiusMiles,
    );
    final originalPriceActual = originalResult.valueOrNull?['price'] as double?;

    // Concurrently fetch pricing for all alternatives
    final proposals = await Future.wait(alternatives.map((alt) async {
      final storeResult = await _omniStoreService.findLowestPriceNearby(
        alt.id,
        alt.name,
        user.defaultZipCode,
        user.searchRadiusMiles,
      );

      double? priceDiff;
      double? alternativePrice;
      String? storeLoc;
      String? storeAdd;
      bool comparisonAvailable = true;
      String? comparisonBasis;
      double? equivalentAlternativeCost;
      String? comparisonReason;
      String? originalQuantityString;
      String? alternativeQuantityString;
      String priceDirection = 'none';
      PricingFailure? pricingFailure;

      final storeData = storeResult.valueOrNull;
      if (storeData != null) {
        alternativePrice = storeData['price'] as double;

        final gateResult = resolvePriceComparison(
          original: scannedProduct,
          alternative: alt,
          originalPrice: originalPriceActual,
          alternativePrice: alternativePrice,
        );

        comparisonAvailable = gateResult.comparisonAvailable;
        comparisonBasis = gateResult.comparisonBasis;
        equivalentAlternativeCost = gateResult.equivalentAlternativeCost;
        comparisonReason = gateResult.reason;
        originalQuantityString = gateResult.originalQuantityString;
        alternativeQuantityString = gateResult.alternativeQuantityString;
        priceDirection = gateResult.direction;

        if (comparisonAvailable) {
          priceDiff = gateResult.difference;
        }

        storeLoc = '${storeData['storeName']} (${storeData['distance']})';
        storeAdd = storeData['storeAddress'] as String?;
      } else {
        pricingFailure = storeResult.failureOrNull;
        AppLogger.warning(
            _tag, 'No pricing for alt "${alt.name}": $pricingFailure');
      }

      final proposal = SwapProposal(
        originalProduct: scannedProduct,
        alternativeProduct: alt,
        priceDifference: priceDiff,
        healthBenefit:
            _healthFilter.calculateBenefit(scannedProduct, alt, user),
        storeLocation: storeLoc,
        storeAddress: storeAdd,
        alternativePrice: alternativePrice,
        reasoning: null,
        comparisonAvailable: comparisonAvailable,
        comparisonBasis: comparisonBasis,
        equivalentAlternativeCost: equivalentAlternativeCost,
        comparisonReason: comparisonReason,
        originalQuantityString: originalQuantityString,
        alternativeQuantityString: alternativeQuantityString,
        priceDirection: priceDirection,
        pricingFailure: pricingFailure,
      );

      if (AppConfig.enableFirestoreCache) {
        await _cacheRepository.cacheProposal(
            scannedProduct.id, user.dietaryPreferences, proposal);
      }

      return proposal;
    }));

    return proposals;
  }

  // ─── Find Alternatives ─────────────────────────────────────────

  /// Step 2 of Workflow: Discover the top 5 semantic alternatives.
  Future<List<Product>> findAlternatives(
      Product scannedProduct, UserProfile user) async {
    final searchTerms = scannedProduct.searchTerms;
    if (searchTerms.isEmpty) {
      AppLogger.warning(
          _tag, 'No valid search terms found for ${scannedProduct.name}');
      return [];
    }

    List<Product> candidates = [];
    List<Product> safeCandidates = [];
    String? successfulCategory;

    for (final term in searchTerms) {
      AppLogger.debug(_tag, 'Searching OpenFoodFacts for category/term: $term');

      candidates = await _productRepository.searchProductsByCategory(term);

      if (candidates.isEmpty) {
        AppLogger.debug(
            _tag, 'Category search yielded 0. Trying text search for: $term');
        candidates = await _productRepository.searchProductsByText(term);
      }

      AppLogger.debug(
          _tag, 'Found ${candidates.length} candidates for term: $term.');

      if (candidates.isEmpty) continue;

      safeCandidates =
          candidates.where((c) => c.id != scannedProduct.id).toList();

      AppLogger.debug(_tag,
          '${safeCandidates.length} candidates available for term: $term.');

      if (safeCandidates.isNotEmpty) {
        successfulCategory = term;
        break;
      } else {
        AppLogger.debug(_tag,
            'All ${candidates.length} candidates failed the health filter for $term. Trying next term…');
      }
    }

    if (safeCandidates.isEmpty) {
      AppLogger.debug(_tag,
          'Returning empty because all search terms failed to find an alternative.');
      return [];
    }

    final primaryCategory = successfulCategory!;

    // Category pre-filter
    final originalTags = scannedProduct.categoryTags.toSet();
    List<Product> categoryFiltered;

    if (originalTags.isNotEmpty) {
      categoryFiltered = safeCandidates.where((c) {
        final shared = c.categoryTags.toSet().intersection(originalTags);
        return shared.length >= 2;
      }).toList();

      AppLogger.debug(_tag,
          '${categoryFiltered.length}/${safeCandidates.length} candidates share ≥2 category tags.');

      if (categoryFiltered.length < 3) {
        categoryFiltered = safeCandidates.where((c) {
          final shared = c.categoryTags.toSet().intersection(originalTags);
          return shared.isNotEmpty;
        }).toList();
        AppLogger.debug(_tag,
            'Relaxed to ≥1 shared tag: ${categoryFiltered.length} candidates.');
      }

      if (categoryFiltered.isEmpty) {
        AppLogger.debug(_tag,
            'Category filter left 0 candidates. Using all safe candidates.');
        categoryFiltered = safeCandidates;
      }
    } else {
      AppLogger.debug(_tag,
          'No category tags on scanned product. Skipping category filter.');
      categoryFiltered = safeCandidates;
    }

    // Semantic scoring
    if (!_semanticService.isInitialized) {
      await _semanticService.init();
    }

    final originalText = '${scannedProduct.name} $primaryCategory';
    final originalEmbedding = _semanticService.getEmbedding(originalText);

    if (originalEmbedding.isNotEmpty) {
      AppLogger.debug(_tag,
          'Scoring ${categoryFiltered.length} category-filtered candidates…');
      var scoredCandidates = categoryFiltered.map((candidate) {
        final candidateText = '${candidate.name} $primaryCategory';
        final candidateEmbedding = _semanticService.getEmbedding(candidateText);
        final semanticScore = _semanticService.cosineSimilarity(
            originalEmbedding, candidateEmbedding);

        final altScore = _healthFilter.getAltScore(candidate, user);
        final compositeScore =
            (0.3 * semanticScore) + (0.7 * (altScore / 100.0));

        AppLogger.debug(_tag,
            '${candidate.name}: semantic=${semanticScore.toStringAsFixed(3)}, altScore=$altScore, composite=${compositeScore.toStringAsFixed(3)}');
        return {
          'product': candidate,
          'composite': compositeScore,
          'semantic': semanticScore
        };
      }).toList();

      scoredCandidates.sort((a, b) =>
          (b['composite'] as double).compareTo(a['composite'] as double));

      final topMatches =
          scoredCandidates.take(5).map((c) => c['product'] as Product).toList();

      if (topMatches.isNotEmpty) {
        AppLogger.info(_tag,
            'Returning ${topMatches.length} top composite-scored alternatives.');
        return topMatches;
      }
    }

    // Fallback: ciqual tag match
    AppLogger.debug(_tag, 'Scoring failed. Falling back to ciqual tag match.');
    final categoryMatches = safeCandidates
        .where((c) =>
            c.validCiqualTags.isNotEmpty &&
            scannedProduct.validCiqualTags.isNotEmpty &&
            c.validCiqualTags.first == scannedProduct.validCiqualTags.first)
        .take(5)
        .toList();

    if (categoryMatches.isNotEmpty) {
      AppLogger.debug(
          _tag, 'Found ${categoryMatches.length} ciqual fallback matches.');
    } else {
      AppLogger.debug(_tag, 'No fallback found.');
    }

    return categoryMatches;
  }

  // ─── Fetch Pricing (Step 3) ────────────────────────────────────

  /// Step 3 of Workflow: Fetch pricing for the original and alternative.
  Future<SwapProposal?> fetchPricing(
      Product scannedProduct, Product bestCandidate, UserProfile user) async {
    return await _fetchPricingImpl(scannedProduct, bestCandidate, user).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        AppLogger.warning(_tag, 'fetchPricing timed out after 30s');
        return null;
      },
    );
  }

  Future<SwapProposal?> _fetchPricingImpl(
      Product scannedProduct, Product bestCandidate, UserProfile user) async {
    AppLogger.debug(_tag, 'ZIP code: ${user.defaultZipCode}');

    final storeResult = await _omniStoreService.findLowestPriceNearby(
      bestCandidate.id,
      bestCandidate.name,
      user.defaultZipCode,
      user.searchRadiusMiles,
    );

    final storeData = storeResult.valueOrNull;
    if (storeData == null) {
      final failure =
          storeResult.failureOrNull ?? PricingFailure.productNotFound;
      AppLogger.warning(
          _tag, 'No pricing for alternative "${bestCandidate.name}": $failure');
      // Return a proposal with the failure reason so the UI can display it
      return SwapProposal(
        originalProduct: scannedProduct,
        alternativeProduct: bestCandidate,
        healthBenefit:
            _healthFilter.calculateBenefit(scannedProduct, bestCandidate, user),
        pricingFailure: failure,
      );
    }

    final originalResult = await _omniStoreService.findLowestPriceNearby(
      scannedProduct.id,
      scannedProduct.name,
      user.defaultZipCode,
      user.searchRadiusMiles,
    );

    final alternativePrice = storeData['price'] as double;
    final originalPriceActual = originalResult.valueOrNull?['price'] as double?;

    bool comparisonAvailable = false;
    String? comparisonBasis;
    double? equivalentAlternativeCost;
    String? comparisonReason;
    String? originalQuantityString;
    String? alternativeQuantityString;
    String priceDirection = 'none';
    double? priceDiff;

    final gateResult = resolvePriceComparison(
      original: scannedProduct,
      alternative: bestCandidate,
      originalPrice: originalPriceActual,
      alternativePrice: alternativePrice,
    );

    comparisonAvailable = gateResult.comparisonAvailable;
    comparisonBasis = gateResult.comparisonBasis;
    equivalentAlternativeCost = gateResult.equivalentAlternativeCost;
    comparisonReason = gateResult.reason;
    originalQuantityString = gateResult.originalQuantityString;
    alternativeQuantityString = gateResult.alternativeQuantityString;
    priceDirection = gateResult.direction;

    if (gateResult.comparisonAvailable) {
      priceDiff = gateResult.difference;
    }

    final proposal = SwapProposal(
      originalProduct: scannedProduct,
      alternativeProduct: bestCandidate,
      priceDifference: priceDiff,
      healthBenefit:
          _healthFilter.calculateBenefit(scannedProduct, bestCandidate, user),
      storeLocation: '${storeData['storeName']} (${storeData['distance']})',
      storeAddress: storeData['storeAddress'] as String?,
      alternativePrice: alternativePrice,
      comparisonAvailable: comparisonAvailable,
      comparisonBasis: comparisonBasis,
      equivalentAlternativeCost: equivalentAlternativeCost,
      comparisonReason: comparisonReason,
      originalQuantityString: originalQuantityString,
      alternativeQuantityString: alternativeQuantityString,
      priceDirection: priceDirection,
    );

    if (AppConfig.enableFirestoreCache) {
      await _cacheRepository.cacheProposal(
          scannedProduct.id, user.dietaryPreferences, proposal);
    }

    return proposal;
  }

  // ─── Fetch Original Pricing ────────────────────────────────────

  /// Fetch pricing for the original product (no alternative comparison).
  Future<LocatedProduct?> fetchOriginalPricing(
      Product product, UserProfile user) async {
    AppLogger.debug(_tag, 'fetchOriginalPricing for: ${product.name}');

    final storeResult = await _omniStoreService
        .findLowestPriceNearby(
      product.id,
      product.name,
      user.defaultZipCode,
      user.searchRadiusMiles,
    )
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        AppLogger.warning(_tag, 'fetchOriginalPricing timed out after 30s');
        return const PricingFailureResult(PricingFailure.timeout);
      },
    );

    final storeData = storeResult.valueOrNull;
    if (storeData == null) {
      final failure =
          storeResult.failureOrNull ?? PricingFailure.productNotFound;
      AppLogger.warning(
          _tag, 'No pricing for original "${product.name}": $failure');
      return null;
    }

    return LocatedProduct(
      product: product,
      price: storeData['price'] as double,
      storeName: storeData['storeName'] as String,
      storeDistance: storeData['distance'] as String? ?? '',
      storeAddress: storeData['storeAddress'] as String?,
    );
  }
}
