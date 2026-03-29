/// Encapsulates the numerical score of a candidate along with a
/// human-readable explanation of why that score was given.
class ScoreResult {
  final double value;
  final String reasoning;

  ScoreResult(this.value, this.reasoning);

  @override
  String toString() => 'Score: \$value (\$reasoning)';
}
