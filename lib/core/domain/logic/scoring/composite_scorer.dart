import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'candidate_scorer.dart';
import 'score_result.dart';

/// Composite pattern: Holds a collection of CandidateScorers and calculates a weighted average.
class CompositeScorer implements CandidateScorer {
  final List<CandidateScorer> _scorers;

  CompositeScorer(this._scorers);

  @override
  double get weight => 1.0;

  @override
  Future<ScoreResult> score(Product candidate, Map<String, dynamic> pricingInfo,
      UserProfile profile) async {
    if (_scorers.isEmpty) return ScoreResult(0.0, "No scorers");

    double totalScore = 0.0;
    double totalWeight = 0.0;
    List<String> reasons = [];

    for (final scorer in _scorers) {
      final individualResult =
          await scorer.score(candidate, pricingInfo, profile);

      totalScore += (individualResult.value * scorer.weight);
      totalWeight += scorer.weight;
      reasons.add(individualResult.reasoning);
    }

    final finalScore = totalWeight > 0 ? (totalScore / totalWeight) : 0.0;
    return ScoreResult(finalScore, reasons.join(" • "));
  }
}
