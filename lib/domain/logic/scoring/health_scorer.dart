import '../../models/product.dart';
import '../../models/user_profile.dart';
import '../custom_health_filter.dart';
import 'candidate_scorer.dart';
import 'score_result.dart';

import '../filters/clean_ingredients_filter.dart';

/// Strategy for evaluating the healthiness of a product candidate.
/// Factors in diet restrictions, mandatory clean ingredients, NutriScore, and Nova group.
class HealthScorer implements CandidateScorer {
  final CustomHealthFilter _healthFilter;
  final CleanIngredientsFilter _cleanIngredientsFilter =
      CleanIngredientsFilter();

  HealthScorer(this._healthFilter);

  @override
  double get weight => 1.5; // Health is typically prioritized

  @override
  Future<ScoreResult> score(Product candidate, Map<String, dynamic> pricingInfo,
      UserProfile profile) async {
    // 1. Mandatory Clean Ingredients Check
    if (_cleanIngredientsFilter.isViolation(candidate)) {
      return ScoreResult(
          0.0, _cleanIngredientsFilter.violationReason(candidate));
    }

    // 2. Strict Diet Check: If it violates the active diets, score is 0.0 immediately.
    if (_healthFilter.isViolation(candidate, profile)) {
      final reason = _healthFilter.generateViolationReason(candidate, profile);
      return ScoreResult(
          0.0, reason.isNotEmpty ? reason : "Violates Dietary Restrictions");
    }

    // 2. NutriScore Evaluation (A = 1.0, E = 0.2, Unknown = 0.5)
    double nutriScoreBonus = 0.5;
    switch (candidate.nutriScore?.toLowerCase()) {
      case 'a':
        nutriScoreBonus = 1.0;
        break;
      case 'b':
        nutriScoreBonus = 0.8;
        break;
      case 'c':
        nutriScoreBonus = 0.6;
        break;
      case 'd':
        nutriScoreBonus = 0.4;
        break;
      case 'e':
        nutriScoreBonus = 0.2;
        break;
    }

    // 3. Nova Group Evaluation (1 = Unprocessed/Best, 4 = Ultra-processed/Worst)
    double novaBonus = 0.5;
    switch (candidate.novaGroup) {
      case 1:
        novaBonus = 1.0;
        break;
      case 2:
        novaBonus = 0.75;
        break;
      case 3:
        novaBonus = 0.5;
        break;
      case 4:
        novaBonus = 0.2;
        break;
    }

    // Composite health rating
    final score = (nutriScoreBonus + novaBonus) / 2.0;

    // Construct reason
    String nsStr = candidate.nutriScore?.toUpperCase() ?? '?';
    String novaStr =
        candidate.novaGroup != null ? 'N${candidate.novaGroup}' : '?';
    String reason = "NutriScore $nsStr, Nova $novaStr";

    return ScoreResult(score, reason);
  }
}
