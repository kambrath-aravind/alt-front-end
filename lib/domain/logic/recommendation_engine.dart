import '../../domain/models/product.dart';
import '../../domain/models/recommendation.dart';
import 'health_scorer.dart';
import 'semantic_service.dart';
import '../../data/repositories/product_repository.dart';

class RecommendationEngine {
  final HealthScorer _scorer;
  final ProductRepository _repository;
  final SemanticService _semantic;

  // Toggle Configuration (Default: true)
  bool useSemanticSearch = true;
  bool _loggedSemanticFallback = false;

  RecommendationEngine(this._scorer, this._repository)
      : _semantic = SemanticService() {
    // Initialize model lazily
    _semantic.init();
  }

  /// Returns a list of healthier alternatives for the given product.
  Future<List<Recommendation>> getAlternatives(Product original) async {
    final searchTerms = original.searchTerms;

    print('[ALT_APP] Original: ${original.name} (${original.id})');
    print('[ALT_APP] Search Terms: $searchTerms');
    print('[ALT_APP] Ciqual Tags: ${original.ciqualTags}');
    print('[ALT_APP] Compared To: ${original.comparedToCategory}');

    if (searchTerms.isEmpty) {
      print('[ALT_APP] No search terms found. Returning empty list.');
      return [];
    }

    // Search using all terms in parallel and merge results (deduplicate by ID)
    final candidateMap = <String, Product>{};

    print('[ALT_APP] Searching ${searchTerms.length} terms in parallel...');
    final searchFutures = searchTerms.map((term) {
      print('[ALT_APP] Searching: $term');
      return _repository.searchProducts(term);
    }).toList();

    final allResults = await Future.wait(searchFutures);

    for (final results in allResults) {
      for (final product in results) {
        candidateMap[product.id] = product;
      }
    }

    final candidates = candidateMap.values.toList();
    print('[ALT_APP] Total unique candidates: ${candidates.length}');

    final scoredOptions = <_ScoredRecommendation>[];

    // --- Optimization: Pre-calculate original embedding once ---
    List<double> originalVec = [];
    if (useSemanticSearch) {
      try {
        originalVec = _semantic.getEmbedding(
            "${original.name} ${original.comparedToCategory} ${original.ingredients.join(' ')}");
      } catch (e) {
        print('[ALT_APP] Failed to get original embedding: $e');
      }
    }

    // --- Optimization: Two-pass ranking ---
    // Pass 1: Calculate "Base Score" (fast metrics) for all candidates
    final baseScoredCandidates = <_BaseScoredCandidate>[];

    for (final candidate in candidates) {
      if (candidate.id == original.id) continue;

      if (!_scorer.isHealthier(original, candidate)) {
        continue;
      }

      final ingredientSim = jaccardSimilarity(
        original.ingredients,
        candidate.ingredients,
      );

      final ciqualSim = _tokenSimilarity(
        original.validCiqualTags,
        candidate.validCiqualTags,
      );

      final categorySim = _tokenSimilarity(
        _categoryToTokens(original.comparedToCategory),
        _categoryToTokens(candidate.comparedToCategory),
      );

      final healthScore = _calculateHealthImprovement(original, candidate);

      // Base score mainly driven by category/ciqual/ingredients & health
      // We give a slight boost to category/ciqual to prioritize "same food type" for the reranker
      final baseScore = (0.30 * categorySim) +
          (0.20 * ciqualSim) +
          (0.10 * ingredientSim) +
          (0.40 * healthScore);

      baseScoredCandidates.add(_BaseScoredCandidate(
        candidate: candidate,
        baseScore: baseScore,
        ingredientSim: ingredientSim,
        ciqualSim: ciqualSim,
        categorySim: categorySim,
        healthScore: healthScore,
      ));
    }

    // Sort by base score descending
    baseScoredCandidates.sort((a, b) => b.baseScore.compareTo(a.baseScore));

    // Pass 2: Semantic Reranking on Top K (e.g. 16)
    // Processing 50+ items with BERT is too slow (~1s per batch vs ~50s).
    final int topK = 16;
    final candidatesToProcess = baseScoredCandidates.take(topK).toList();

    for (final item in candidatesToProcess) {
      double score = item.baseScore; // Default to base score
      double semanticScore = 0.0;
      String reasonText;

      if (useSemanticSearch && originalVec.isNotEmpty) {
        final candidateVec = _semantic.getEmbedding(
            "${item.candidate.name} ${item.candidate.comparedToCategory} ${item.candidate.ingredients.join(' ')}");

        if (candidateVec.isNotEmpty) {
          semanticScore = _semantic.cosineSimilarity(originalVec, candidateVec);
          final rawMatch =
              (item.categorySim + item.ciqualSim + item.ingredientSim) / 3.0;

          // Combined score with semantic boost
          score = (0.40 * item.healthScore) +
              (0.40 * semanticScore) +
              (0.20 * rawMatch);

          print(
              '[ALT_APP] [Semantic] ${item.candidate.name} Base: ${item.baseScore.toStringAsFixed(2)} -> Final: ${score.toStringAsFixed(2)} (Sem: ${semanticScore.toStringAsFixed(2)})');
        } else {
          // Fallback logic if vector is empty
          score = item.baseScore;
        }
      } else {
        // Legacy score Logic (already close to baseScore weights but slightly adjusted in original code)
        // Our baseScore was: 0.3 cat, 0.2 ciqual, 0.1 ing, 0.4 health
        // Legacy was: 0.25 cat, 0.20 ciqual, 0.15 ing, 0.40 health
        // We'll trust the baseScore for sorting is good enough, but let's recalculate precise legacy score if needed
        score = (0.25 * item.categorySim) +
            (0.20 * item.ciqualSim) +
            (0.15 * item.ingredientSim) +
            (0.40 * item.healthScore);

        print('[ALT_APP] [Legacy] ${item.candidate.name} Score: $score');
      }

      reasonText = _generateReason(original, item.candidate, item.ingredientSim,
          semanticScore: semanticScore,
          ciqualSim: item.ciqualSim,
          categorySim: item.categorySim,
          baseScore: item.baseScore);

      scoredOptions.add(_ScoredRecommendation(
        recommendation: Recommendation(
          product: item.candidate,
          reason: reasonText,
        ),
        score: score,
      ));
    }

    scoredOptions.sort((a, b) => b.score.compareTo(a.score));
    return scoredOptions.map((s) => s.recommendation).toList();
  }

  /// Jaccard similarity between two string lists.
  static double jaccardSimilarity(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final setA = a.map((e) => e.toLowerCase().trim()).toSet();
    final setB = b.map((e) => e.toLowerCase().trim()).toSet();

    final intersection = setA.intersection(setB);
    final union = setA.union(setB);

    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  /// Token-based Jaccard similarity for hyphenated tags/categories.
  double _tokenSimilarity(List<String> tagsA, List<String> tagsB) {
    if (tagsA.isEmpty && tagsB.isEmpty) return 1.0;
    if (tagsA.isEmpty || tagsB.isEmpty) return 0.0;

    final tokensA = tagsA
        .expand((tag) => tag.toLowerCase().split(RegExp(r'[-:]')))
        .where((t) => t.isNotEmpty && t != 'en')
        .toSet();

    final tokensB = tagsB
        .expand((tag) => tag.toLowerCase().split(RegExp(r'[-:]')))
        .where((t) => t.isNotEmpty && t != 'en')
        .toSet();

    final intersection = tokensA.intersection(tokensB);
    final union = tokensA.union(tokensB);

    return union.isEmpty ? 0.0 : intersection.length / union.length;
  }

  /// Converts a compared_to_category string to a list for token similarity.
  List<String> _categoryToTokens(String? category) {
    if (category == null || category.isEmpty) return [];
    return [category];
  }

  /// Normalized health improvement score (0.0 - 1.0).
  double _calculateHealthImprovement(Product original, Product candidate) {
    final gradeOriginal = _scorer.calculateGrade(original);
    final gradeCandidate = _scorer.calculateGrade(candidate);

    final improvement = gradeOriginal.index - gradeCandidate.index;
    return (improvement / 4.0).clamp(0.0, 1.0);
  }

  /// Generates a human-readable reason for the recommendation.
  /// Generates a human-readable reason for the recommendation.
  String _generateReason(
    Product original,
    Product candidate,
    double ingredientSim, {
    double semanticScore = 0.0,
    double ciqualSim = 0.0,
    double categorySim = 0.0,
    double baseScore = 0.0,
  }) {
    final parts = <String>[];

    final originalGrade = _scorer.calculateGrade(original);
    final candidateGrade = _scorer.calculateGrade(candidate);

    if (candidateGrade.index < originalGrade.index) {
      parts.add(
        "Better Nutri-Score "
        "(${candidate.nutriScore?.toUpperCase() ?? '?'} vs "
        "${original.nutriScore?.toUpperCase() ?? '?'})",
      );
    }

    if (original.novaGroup != null && candidate.novaGroup != null) {
      if (candidate.novaGroup! < original.novaGroup!) {
        parts.add("Less processed (NOVA ${candidate.novaGroup})");
      }
    }

    // Semantic Badge vs Legacy Badge
    if (semanticScore > 0) {
      if (semanticScore >= 0.85)
        parts.add("High relevance");
      else if (semanticScore >= 0.7) parts.add("Similar item");
    } else {
      // Legacy Logic
      if (categorySim >= 0.5 || ciqualSim >= 0.5) parts.add("Same food type");
    }

    if (ingredientSim >= 0.5) {
      parts.add("Similar ingredients");
    }

    return parts.isNotEmpty ? parts.join(' • ') : "Healthier alternative";
  }
}

class _ScoredRecommendation {
  final Recommendation recommendation;
  final double score;

  _ScoredRecommendation({
    required this.recommendation,
    required this.score,
  });
}

class _BaseScoredCandidate {
  final Product candidate;
  final double baseScore;
  final double ingredientSim;
  final double ciqualSim;
  final double categorySim;
  final double healthScore;

  _BaseScoredCandidate({
    required this.candidate,
    required this.baseScore,
    required this.ingredientSim,
    required this.ciqualSim,
    required this.categorySim,
    required this.healthScore,
  });
}
