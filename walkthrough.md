# "alt" App - Alpha 1.0 Walkthrough

We have successfully implemented the MVP for **alt**. The codebase is structure, compilable, and contains all the core business logic requested.

## Features Implemented

### 1. Smart Scanning & Analysis
- **Technology**: Uses `camera` and `google_mlkit_barcode_scanning` to detect products in real-time.
- **Logic**: The `HealthScorer` ranks products based on Nutri-Score, NOVA group, and ingredient length.
- **Verification**: Unit tests pass confirming our logic correctly identifies "Bad" vs "Good" products.

```dart
// Test Result
00:04 +3: All tests passed!
```

### 2. Recommendation Engine
- **Solver**: Solves the "Cold Start" problem with a local database of healthy category staples (Chips, Soda, etc.).
- **Extensible**: Designed to support non-food items in the future via polymorphic strategies.

### 3. Availability & Store Finder
- **Strategy**: Since store APIs are expensive, we use a `StoreService` that generates targeted "Google Shopping" or "Instacart" search links for the user.
- **UI**: Added a "Find Online" button to every alternative card.

### 4. Throttling (MVP Security)
- **Constraint**: To keep costs at $0, we implemented client-side throttling.
- **Implementation**: `ThrottlingService` restricts users to 10 scans/day using local storage. This mimics the eventual Firebase Anonymous Auth rule structure.

### 5. Admin Interface
- **Access**: A hidden `/admin` route allows for manual linking of products and viewing "Thumbs Down" feedback.

## Setup Instructions

1.  **Firebase Setup**:
    - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from your Firebase Console.
    - Place them in `android/app/` and `ios/Runner/` respectively.
2.  **Run the App**:
    ```bash
    flutter run
    ```
3.  **Test It**:
    - Scan a barcode (or mock one in the emulator).
    - See the "Grade" (A-E).
    - Click "Find Online" on a suggestion.

## Next Steps
- [ ] Connect `ProductRepository` to the real USDA API Key.
- [ ] Migrate `ThrottlingService` to Firebase Cloud Functions for server-side enforcement.
