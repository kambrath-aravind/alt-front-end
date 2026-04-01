/// The reason a store-pricing lookup did not return a price.
///
/// Use [userMessage] to get a short, user-readable explanation that can be
/// shown directly in the UI (e.g. in a SnackBar or pricing card).
enum PricingFailure {
  /// API credentials are missing or rejected by the store's auth endpoint.
  authFailure,

  /// The network request exceeded the configured time limit.
  timeout,

  /// No participating store was found within the requested radius.
  noStoreNearby,

  /// The store was reached but the product could not be matched in its catalog.
  productNotFound,

  /// A general network or HTTP error that does not fit a more specific category.
  networkError;

  /// Short, human-readable message suitable for display in the UI.
  String get userMessage => switch (this) {
        PricingFailure.authFailure =>
          'Store pricing is temporarily unavailable.',
        PricingFailure.timeout =>
          'No pricing found – check your connection.',
        PricingFailure.noStoreNearby =>
          'No nearby store found for your location.',
        PricingFailure.productNotFound =>
          'This product isn\'t listed at local stores.',
        PricingFailure.networkError =>
          'No pricing found – check your connection.',
      };
}
