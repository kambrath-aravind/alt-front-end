import '../../models/product.dart';
import '../../models/user_profile.dart';
import 'candidate_scorer.dart';
import 'score_result.dart';

/// Strategy for evaluating the physical distance of the store for a candidate.
class DistanceScorer implements CandidateScorer {
  @override
  double get weight => 0.8; // Convenience

  @override
  Future<ScoreResult> score(Product candidate, Map<String, dynamic> pricingInfo,
      UserProfile profile) async {
    final distanceStr = pricingInfo['distance'] as String?;
    if (distanceStr == null) {
      // If no location distance is provided, penalize
      return ScoreResult(0.2, "Online/Unknown location");
    }

    // Parse '1.5 mi' -> 1.5
    final match = RegExp(r'([\d\.]+)\s*mi').firstMatch(distanceStr);
    if (match != null) {
      final miles = double.tryParse(match.group(1) ?? '0') ?? 0;

      // Normalization based on the user's search radius.
      // Closer = Higher Score
      final maxDistance =
          profile.searchRadiusMiles > 0 ? profile.searchRadiusMiles : 5.0;
      final normalized = 1.0 - (miles / maxDistance);
      final score = normalized.clamp(0.0, 1.0);
      return ScoreResult(score, "${miles.toStringAsFixed(1)} mi away");
    }

    // Online or Unknown
    return ScoreResult(0.5, "Location unspecified");
  }
}
