import '../models/product.dart';
import '../models/located_product.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/swap_proposal.dart';
import '../../data/services/omni_store_service.dart';
import '../../data/repositories/rag_cache_repository.dart';
import '../../data/repositories/product_repository.dart';
import 'custom_health_filter.dart';
import 'semantic_service.dart';

class GhostSwapEngine {
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

  /// The main pipeline for the "Ghost Swap" mechanic.
  Future<SwapProposal?> evaluateAndPropose(
      Product scannedProduct, UserProfile user) async {
    final isViolation = _healthFilter.isViolation(scannedProduct, user);

    if (!isViolation) {
      return null;
    }

    final cachedProposal = await _cacheRepository.getCachedProposal(
        scannedProduct.id, user.dietaryPreferences);
    if (cachedProposal != null) {
      return cachedProposal;
    }

    final alternatives = await findAlternatives(scannedProduct, user);
    if (alternatives.isEmpty) return null;

    return await fetchPricing(scannedProduct, alternatives.first, user);
  }

  /// Step 2 of Workflow: Discover the top 5 semantic alternatives
  /// Uses category pre-filtering and NutriScore-weighted ranking.
  Future<List<Product>> findAlternatives(
      Product scannedProduct, UserProfile user) async {
    final searchTerms = scannedProduct.searchTerms;
    if (searchTerms.isEmpty) {
      debugPrint(
          '[GhostSwap] No valid search terms found for ${scannedProduct.name}');
      return [];
    }

    final primaryCategory = searchTerms.first;
    debugPrint(
        '[GhostSwap] Searching OpenFoodFacts for category: $primaryCategory');

    final candidates =
        await _productRepository.searchProductsByCategory(primaryCategory);
    debugPrint(
        '[GhostSwap] Found ${candidates.length} candidates in category.');

    if (candidates.isEmpty) return [];

    // 1. Health filter — remove violations and self-match
    final safeCandidates = candidates.where((c) {
      final safe =
          c.id != scannedProduct.id && !_healthFilter.isViolation(c, user);
      if (!safe) {
        debugPrint(
            '[GhostSwap-Debug] Candidate ${c.name} (${c.id}) rejected by health filter or matches ID.');
      }
      return safe;
    }).toList();

    debugPrint(
        '[GhostSwap] ${safeCandidates.length} candidates passed health filter.');
    if (safeCandidates.isEmpty) {
      debugPrint(
          '[GhostSwap-Debug] Returning empty because all ${candidates.length} candidates failed the health filter.');
      return [];
    }

    // 2. Category pre-filter — only keep candidates sharing at least one
    //    category tag with the scanned product (eliminates Taco Shells for a cookie scan)
    final originalTags = scannedProduct.categoryTags.toSet();
    List<Product> categoryFiltered;

    if (originalTags.isNotEmpty) {
      categoryFiltered = safeCandidates.where((c) {
        final shared = c.categoryTags.toSet().intersection(originalTags);
        return shared.length >= 2; // require at least 2 shared tags
      }).toList();

      debugPrint(
          '[GhostSwap] ${categoryFiltered.length}/${safeCandidates.length} candidates share ≥2 category tags.');

      // Fallback: if too aggressive, try 1 shared tag
      if (categoryFiltered.length < 3) {
        categoryFiltered = safeCandidates.where((c) {
          final shared = c.categoryTags.toSet().intersection(originalTags);
          return shared.isNotEmpty;
        }).toList();
        debugPrint(
            '[GhostSwap] Relaxed to ≥1 shared tag: ${categoryFiltered.length} candidates.');
      }

      // Final fallback: use all safe candidates if category filtering is empty
      if (categoryFiltered.isEmpty) {
        debugPrint(
            '[GhostSwap] Category filter left 0 candidates. Using all safe candidates.');
        categoryFiltered = safeCandidates;
      }
    } else {
      debugPrint(
          '[GhostSwap] No category tags on scanned product. Skipping category filter.');
      categoryFiltered = safeCandidates;
    }

    // 3. Semantic scoring + NutriScore weighting
    if (!_semanticService.isInitialized) {
      await _semanticService.init();
    }

    final originalText = '${scannedProduct.name} $primaryCategory';
    final originalEmbedding = _semanticService.getEmbedding(originalText);

    if (originalEmbedding.isNotEmpty) {
      debugPrint(
          '[GhostSwap-Debug] Scoring ${categoryFiltered.length} category-filtered candidates...');
      var scoredCandidates = categoryFiltered.map((candidate) {
        final candidateText = '${candidate.name} $primaryCategory';
        final candidateEmbedding = _semanticService.getEmbedding(candidateText);
        final semanticScore = _semanticService.cosineSimilarity(
            originalEmbedding, candidateEmbedding);

        // NutriScore bonus: A=1.0, B=0.8, C=0.6, D=0.4, E=0.2, unknown=0.5
        final nutriBonus = _nutriScoreBonus(candidate.nutriScore);

        // Nova group bonus: 1=1.0 (unprocessed), 2=0.75, 3=0.5, 4=0.2 (ultra-processed)
        final novaBonus = _novaGroupBonus(candidate.novaGroup);

        // Composite: semantic (text match) + NutriScore (nutrition) + Nova (processing)
        final compositeScore =
            (0.3 * semanticScore) + (0.35 * nutriBonus) + (0.35 * novaBonus);

        debugPrint(
            '[GhostSwap-Debug] ${candidate.name}: semantic=${semanticScore.toStringAsFixed(3)}, nutri=${candidate.nutriScore ?? "?"} (${nutriBonus.toStringAsFixed(1)}), nova=${candidate.novaGroup ?? "?"} (${novaBonus.toStringAsFixed(2)}), composite=${compositeScore.toStringAsFixed(3)}');
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
        debugPrint(
            '[GhostSwap] Returning ${topMatches.length} top composite-scored alternatives.');
        return topMatches;
      }
    }

    // Fallback: category match by ciqual tags
    debugPrint('[GhostSwap] Scoring failed. Falling back to ciqual tag match.');
    final categoryMatches = safeCandidates
        .where((c) =>
            c.validCiqualTags.isNotEmpty &&
            scannedProduct.validCiqualTags.isNotEmpty &&
            c.validCiqualTags.first == scannedProduct.validCiqualTags.first)
        .take(5)
        .toList();

    if (categoryMatches.isNotEmpty) {
      debugPrint(
          '[GhostSwap] Found ${categoryMatches.length} ciqual fallback matches.');
    } else {
      debugPrint('[GhostSwap] No fallback found.');
    }

    return categoryMatches;
  }

  /// Maps NutriScore grade to a 0.0-1.0 bonus value.
  double _nutriScoreBonus(String? grade) {
    switch (grade?.toLowerCase()) {
      case 'a':
        return 1.0;
      case 'b':
        return 0.8;
      case 'c':
        return 0.6;
      case 'd':
        return 0.4;
      case 'e':
        return 0.2;
      default:
        return 0.5; // unknown
    }
  }

  /// Maps Nova group to a 0.0-1.0 bonus value.
  /// Nova 1 (unprocessed) = best, Nova 4 (ultra-processed) = worst.
  double _novaGroupBonus(int? group) {
    switch (group) {
      case 1:
        return 1.0;
      case 2:
        return 0.75;
      case 3:
        return 0.5;
      case 4:
        return 0.2;
      default:
        return 0.5; // unknown
    }
  }

  /// Step 3 of Workflow: Fetch pricing for the original and alternative
  Future<SwapProposal?> fetchPricing(
      Product scannedProduct, Product bestCandidate, UserProfile user) async {
    // Overall timeout so the UI never spins forever
    return await _fetchPricingImpl(scannedProduct, bestCandidate, user).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('[GhostSwap] fetchPricing timed out after 30s');
        return null;
      },
    );
  }

  Future<SwapProposal?> _fetchPricingImpl(
      Product scannedProduct, Product bestCandidate, UserProfile user) async {
    debugPrint("[ZIPCODE] Default zip code: ${user.defaultZipCode}");

    final storeResult = await _omniStoreService.findLowestPriceNearby(
      bestCandidate.id,
      bestCandidate.name,
      user.defaultZipCode,
      user.searchRadiusMiles,
    );

    if (storeResult == null) {
      debugPrint(
          '[GhostSwap] No pricing found for alternative: ${bestCandidate.name}');
      return null;
    }

    final originalStoreResult = await _omniStoreService.findLowestPriceNearby(
      scannedProduct.id,
      scannedProduct.name,
      user.defaultZipCode,
      user.searchRadiusMiles,
    );

    final originalPriceActual =
        (originalStoreResult?['price'] as double?) ?? 5.99;
    final alternativePrice = storeResult['price'] as double;
    final priceDiff = originalPriceActual - alternativePrice;

    final proposal = SwapProposal(
      originalProduct: scannedProduct,
      alternativeProduct: bestCandidate,
      priceDifference: priceDiff,
      healthBenefit:
          _healthFilter.calculateBenefit(scannedProduct, bestCandidate, user),
      storeLocation: '${storeResult['storeName']} (${storeResult['distance']})',
      storeAddress: storeResult['storeAddress'] as String?,
      alternativePrice: alternativePrice,
    );

    await _cacheRepository.cacheProposal(
        scannedProduct.id, user.dietaryPreferences, proposal);

    return proposal;
  }

  /// Fetch pricing for the original product (no alternative comparison).
  /// Returns a [LocatedProduct] with the cheapest nearby store, or null.
  Future<LocatedProduct?> fetchOriginalPricing(
      Product product, UserProfile user) async {
    debugPrint('[GhostSwap] fetchOriginalPricing for: ${product.name}');

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
        debugPrint('[GhostSwap] fetchOriginalPricing timed out after 30s');
        return null;
      },
    );

    if (storeResult == null) {
      debugPrint('[GhostSwap] No pricing found for original: ${product.name}');
      return null;
    }

    return LocatedProduct(
      product: product,
      price: storeResult['price'] as double,
      storeName: storeResult['storeName'] as String,
      storeDistance: storeResult['distance'] as String? ?? '',
      storeAddress: storeResult['storeAddress'] as String?,
    );
  }
}
