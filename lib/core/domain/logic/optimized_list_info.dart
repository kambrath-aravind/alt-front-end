import 'package:alt/core/domain/models/swap_proposal.dart';

class OptimizationResult {
  final String query;
  final List<SwapProposal> alternatives; // Ranked top 5

  OptimizationResult(this.query, this.alternatives);
}

class OptimizedListInfo {
  final List<OptimizationResult> results;
  final List<String> unresolvableQueries;
  final double estimatedTotalCost;

  OptimizedListInfo({
    required this.results,
    required this.unresolvableQueries,
    required this.estimatedTotalCost,
  });
}
