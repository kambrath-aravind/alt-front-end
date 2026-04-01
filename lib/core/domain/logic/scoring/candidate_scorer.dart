import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'score_result.dart';

/// Strategy Interface for scoring a product candidate based on specific criteria.
/// Applies the Strategy Pattern (GoF) and adheres to Open/Closed Principle.
abstract class CandidateScorer {
  /// Defines the relative importance of this scorer.
  double get weight;

  /// Evaluates a candidate and returns a ScoreResult containing the normalized
  /// score between 0.0 (worst) and 1.0 (best) and a human-readable reason.
  /// [pricingInfo] corresponds to the data retrieved from OmniStoreService.
  Future<ScoreResult> score(
      Product candidate, Map<String, dynamic> pricingInfo, UserProfile profile);
}
