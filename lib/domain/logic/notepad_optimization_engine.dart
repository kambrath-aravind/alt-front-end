import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/user_profile.dart';
import '../models/swap_proposal.dart';
import 'optimized_list_info.dart';
import 'scoring/candidate_scorer.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/omni_store_service.dart';

/// Facade Pattern / Orchestrator for bulk list processing.
class NotepadOptimizationEngine {
  final ProductRepository _productRepository;
  final OmniStoreService _omniStoreService;
  final CandidateScorer _compositeScorer;

  NotepadOptimizationEngine(
    this._productRepository,
    this._omniStoreService,
    this._compositeScorer,
  );

  /// Process a multi-line newline-separated list of items utilizing Tier A Concurrency.
  Future<OptimizedListInfo> optimizeList(
      String rawList, UserProfile user) async {
    final queries = rawList
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    List<OptimizationResult> results = [];
    List<String> unresolvable = [];
    double totalCost = 0.0;

    // TIER A Concurrency: Map all queries to Futures and execute simultaneously
    final queryFutures = queries.map((query) async {
      debugPrint('[NotepadEngine] Start Optimizing: $query');
      final alternatives = await _optimizeSingleQuery(query, user);
      return {'query': query, 'alternatives': alternatives};
    }).toList();

    final completedQueries = await Future.wait(queryFutures);

    for (final completed in completedQueries) {
      final query = completed['query'] as String;
      final alternatives = completed['alternatives'] as List<SwapProposal>;

      if (alternatives.isNotEmpty) {
        results.add(OptimizationResult(query, alternatives));
        totalCost += alternatives.first.alternativePrice;
      } else {
        unresolvable.add(query);
      }
    }

    return OptimizedListInfo(
      results: results,
      unresolvableQueries: unresolvable,
      estimatedTotalCost: totalCost,
    );
  }

  Future<List<SwapProposal>> _optimizeSingleQuery(
      String query, UserProfile user) async {
    // 1. Search candidate products using the fuzzy text pipeline
    final candidates = await _productRepository.searchProductsByText(query);
    if (candidates.isEmpty) return [];

    final top15Candidates = candidates.take(15).toList();

    // TIER B, PASS 1: Local Offline Health Filtering
    // We expect the dependency injector to have provided a CompositeScorer
    // where one of the sub-scorers is a HealthScorer. For simplicity in pass 1
    // we'll run a quick offline mock composite score (assuming price/dist = 0 for now)
    // or just rely entirely on HealthScorer if we extract it.
    // Instead of extracting, to keep Strategy intact, we just score offline:

    List<_CandidateScorePair> preFiltered = [];
    for (final candidate in top15Candidates) {
      // Pass empty pricing to force it to rely purely on offline health mechanics
      final offlineScore = await _compositeScorer.score(candidate, {}, user);
      preFiltered.add(_CandidateScorePair(candidate, offlineScore.value));
    }

    // Sort descending by highest offline score
    preFiltered.sort((a, b) => b.score.compareTo(a.score));

    // Take exactly the Top 3 to avoid spamming the Kroger/Walmart API
    final top3HealthyCandidates =
        preFiltered.take(3).map((e) => e.candidate).toList();

    // TIER B, PASS 2: Concurrent Pricing API Fetches
    final proposalFutures = top3HealthyCandidates.map((candidate) async {
      // Fetch pricing over network
      final pricingInfo = await _omniStoreService.findLowestPriceNearby(
        candidate.id,
        candidate.name,
        user.defaultZipCode,
        user.searchRadiusMiles,
      );

      // Finalize composite score including network data
      final finalScoreResult =
          await _compositeScorer.score(candidate, pricingInfo ?? {}, user);

      debugPrint(
          '[NotepadEngine] Candidate [${candidate.name}] final scored: ${finalScoreResult.value}');

      if (finalScoreResult.value > 0.0) {
        return SwapProposal(
          originalProduct: Product(
              id: 'input',
              name: query,
              brand: '',
              categoryTags: [],
              ingredients: []),
          alternativeProduct: candidate,
          priceDifference: 0.0,
          healthBenefit:
              'Score: ${(finalScoreResult.value * 100).toStringAsFixed(0)}/100',
          storeLocation: pricingInfo?['storeName'] ?? 'Online/Unknown',
          storeAddress: pricingInfo?['storeAddress'],
          alternativePrice: (pricingInfo?['price'] as double?) ?? 0.0,
          reasoning: finalScoreResult.reasoning,
        );
      }
      return null;
    }).toList();

    final resolvedProposals = await Future.wait(proposalFutures);

    // Filter out nulls and sort final results
    final List<SwapProposal> validProposals =
        resolvedProposals.whereType<SwapProposal>().toList();

    validProposals.sort((a, b) {
      final scoreA =
          double.parse(a.healthBenefit.replaceAll(RegExp(r'[^0-9]'), ''));
      final scoreB =
          double.parse(b.healthBenefit.replaceAll(RegExp(r'[^0-9]'), ''));
      return scoreB.compareTo(scoreA);
    });

    return validProposals;
  }
}

class _CandidateScorePair {
  final Product candidate;
  final double score;
  _CandidateScorePair(this.candidate, this.score);
}
