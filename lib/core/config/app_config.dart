/// Central configuration flags for the app.
/// Toggle features on/off without touching business logic.
class AppConfig {
  /// When `true`, SwapProposal results are cached to / read from Firestore
  /// (`ProductAnalyses` collection) so repeat scans skip the full pipeline.
  ///
  /// Set to `false` while Firestore security rules are not configured,
  /// to avoid PERMISSION_DENIED retry storms.
  static const bool enableFirestoreCache = false;
  /// Google Maps Cloud Map ID for Advanced Markers and Data-driven styling.
  /// Leave null unless you have a Map ID from the Google Cloud Console.
  static const String? googleMapsMapId = null;
}
