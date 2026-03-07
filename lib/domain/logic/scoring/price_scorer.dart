import '../../models/product.dart';
import '../../models/user_profile.dart';
import 'candidate_scorer.dart';
import 'score_result.dart';

/// Strategy for evaluating the price of a product candidate.
class PriceScorer implements CandidateScorer {
  @override
  double get weight => 1.0;

  @override
  Future<ScoreResult> score(Product candidate, Map<String, dynamic> pricingInfo,
      UserProfile profile) async {
    final price = pricingInfo['price'] as double?;
    if (price == null) {
      // If no price is found, penalize heavily.
      return ScoreResult(0.1, "Price unknown");
    }

    // A simple normalization. In the future, we could compare against a category average.
    // For now, lower price = higher score, capping at $20.
    final normalized = 1.0 - (price / 20.0);
    final score = normalized.clamp(0.0, 1.0);
    return ScoreResult(score, "\$${price.toStringAsFixed(2)}");
  }
}
