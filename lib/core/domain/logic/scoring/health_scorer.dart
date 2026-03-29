import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import '../custom_health_filter.dart';
import 'candidate_scorer.dart';
import 'score_result.dart';

class HealthScorer implements CandidateScorer {
  final CustomHealthFilter _healthFilter;

  HealthScorer(this._healthFilter);

  @override
  double get weight => 1.5; // Health is typically prioritized

  @override
  Future<ScoreResult> score(Product candidate, Map<String, dynamic> pricingInfo,
      UserProfile profile) async {
    final altScore = _healthFilter.getAltScore(candidate, profile);
    final reasons = _healthFilter.getViolationReasons(candidate, profile);

    final floatScore = altScore / 100.0;
    final reasonStr = reasons.isNotEmpty ? reasons.join(' • ') : "Healthy choice";

    return ScoreResult(floatScore, reasonStr);
  }
}
