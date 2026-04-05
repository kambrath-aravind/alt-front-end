import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import 'optimized_list_info.dart';
import 'scoring/candidate_scorer.dart';
import 'package:alt/core/data/repositories/product_repository.dart';

/// Facade Pattern / Orchestrator for bulk list processing.
class NotepadOptimizationEngine {
  final ProductRepository _productRepository;
  final CandidateScorer _compositeScorer;

  NotepadOptimizationEngine(
    this._productRepository,
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

    for (final query in queries) {
      debugPrint('[NotepadEngine] Start Optimizing: $query');
      final alternatives = await _optimizeSingleQuery(query, user);
      
      if (alternatives.isNotEmpty) {
        results.add(OptimizationResult(query, alternatives));
        totalCost += alternatives.first.alternativePrice ?? 0.0;
      } else {
        unresolvable.add(query);
      }
      
      // Respect OpenFoodFacts rate limits (10 searches/min).
      // We use a 1-second delay between queries to balance speed and reliability.
      await Future.delayed(const Duration(milliseconds: 1000));
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

    // Take exactly the Top 5 to display to the user
    final top5HealthyCandidates =
        preFiltered.take(5).map((e) => e.candidate).toList();

    // TIER B, PASS 2: Build offline SwapProposals
    final proposalFutures = top5HealthyCandidates.map((candidate) async {
      // Finalize composite score purely locally
      final finalScoreResult =
          await _compositeScorer.score(candidate, {}, user);

      return SwapProposal(
        originalProduct: Product(
            id: 'input',
            name: query,
            brand: '',
            categoryTags: [],
            ingredients: []),
        alternativeProduct: candidate,
        priceDifference: null,
        healthBenefit:
            'Score: ${(finalScoreResult.value * 100).toStringAsFixed(0)}/100',
        storeLocation: null,
        storeAddress: null,
        alternativePrice: null,
        reasoning: finalScoreResult.reasoning,
      );
    }).toList();

    final validProposals = await Future.wait(proposalFutures);

    validProposals.sort((a, b) {
      final scoreA =
          double.parse(a.healthBenefit.replaceAll(RegExp(r'[^0-9]'), ''));
      final scoreB =
          double.parse(b.healthBenefit.replaceAll(RegExp(r'[^0-9]'), ''));
      
      final scoreCompare = scoreB.compareTo(scoreA);
      if (scoreCompare != 0) return scoreCompare;

      return (a.alternativePrice ?? 0.0).compareTo(b.alternativePrice ?? 0.0);
    });

    return validProposals;
  }
}

class _CandidateScorePair {
  final Product candidate;
  final double score;
  _CandidateScorePair(this.candidate, this.score);
}
