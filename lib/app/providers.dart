import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/logic/health_scorer.dart';
import '../domain/logic/recommendation_engine.dart';
import '../data/services/throttling_service.dart';
import '../data/repositories/product_repository.dart';

// Moved from scan_controller.dart or redefined here for global access
final productRepositoryProvider = Provider((ref) => ProductRepository());

final healthScorerProvider = Provider((ref) => HealthScorer());

final recommendationEngineProvider = Provider((ref) {
  final scorer = ref.watch(healthScorerProvider);
  final repository = ref.watch(productRepositoryProvider);
  return RecommendationEngine(scorer, repository);
});

final throttlingServiceProvider = Provider((ref) => ThrottlingService());
