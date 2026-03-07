# Alt — Development Plan

## Current State (as of March 2026)

Alt is a Flutter app that helps users find healthier, affordable grocery alternatives. The core loop works:

**Onboarding → Scan barcode → Health analysis → Find alternatives → Find nearest/cheapest store → Add to list**

A secondary flow exists via the Notepad: type grocery items → optimize the list for health + price.

### Architecture
- **Presentation**: Flutter + Riverpod, GoRouter navigation
- **Domain**: `GhostSwapEngine` (scan flow), `NotepadOptimizationEngine` (list flow), `CustomHealthFilter` (chain-of-responsibility with `DietaryFilter` interface), `CompositeScorer` (strategy pattern with health/price/distance scorers)
- **Data**: OpenFoodFacts API (products), Kroger + Walmart APIs (pricing), `OmniStoreService` (fan-out), `StorePricingStrategy` interface

### Key Files
| File | Purpose |
|---|---|
| `lib/app/app.dart` | GoRouter routes |
| `lib/app/providers.dart` | All Riverpod providers, `StaplesListNotifier`, `UserProfileNotifier` |
| `lib/domain/logic/ghost_swap_engine.dart` | Scan flow: alternatives + pricing |
| `lib/domain/logic/notepad_optimization_engine.dart` | Notepad flow: bulk list optimization |
| `lib/domain/logic/custom_health_filter.dart` | Health violation registry |
| `lib/domain/logic/filters/` | Per-diet filter implementations (`BloodSugarFilter`, `PeanutAllergyFilter`, etc.) |
| `lib/domain/logic/scoring/` | `CandidateScorer` interface, `CompositeScorer`, `HealthScorer`, `PriceScorer`, `DistanceScorer` |
| `lib/domain/models/product.dart` | Product model (from OpenFoodFacts) |
| `lib/domain/models/located_product.dart` | Product + store/price info (for originals) |
| `lib/domain/models/swap_proposal.dart` | Original + alternative + pricing comparison |
| `lib/domain/models/user_profile.dart` | ZIP, dietary prefs, onboarding flag |
| `lib/data/services/omni_store_service.dart` | Queries all store strategies, returns cheapest |
| `lib/data/services/store_pricing_strategies/` | `StorePricingStrategy` interface + Kroger, Walmart implementations |
| `lib/data/repositories/product_repository.dart` | OpenFoodFacts API (barcode lookup, text search, category search) |
| `lib/presentation/scan/scanner_screen.dart` | Camera + ML Kit barcode scanning |
| `lib/presentation/results/product_details_screen.dart` | Health analysis + alternative selection + pricing workflow |
| `lib/presentation/results/staples_list_screen.dart` | Grocery list display |
| `lib/presentation/notepad/notepad_screen.dart` | Text-based grocery list input |
| `lib/presentation/notepad/optimized_list_screen.dart` | Optimized list results |

---

## Iteration 2 — Foundation

> **Goal**: Make the app persistent and configurable so users can close and reopen without losing data.

### 2.1 Persist the Staples List
- **What**: Save the staples list to local storage so it survives app restarts.
- **Where**: `lib/app/providers.dart` → `StaplesListNotifier`
- **How**: Use `shared_preferences` or `hive` to serialize/deserialize the list on every change. Each item type (`Product`, `LocatedProduct`, `SwapProposal`) needs a `toJson()`/`fromJson()` method.
- **Files to modify**:
  - `lib/domain/models/product.dart` — add `toJson()`
  - `lib/domain/models/located_product.dart` — add `toJson()`, `fromJson()`
  - `lib/domain/models/swap_proposal.dart` — add `fromJson()`
  - `lib/app/providers.dart` — `StaplesListNotifier` reads from storage on init, writes on every mutation

### 2.2 Type-Safe Staples List
- **What**: Replace `List<dynamic>` with a sealed class for type safety.
- **Where**: `lib/app/providers.dart`, `lib/presentation/results/staples_list_screen.dart`
- **How**: Create `sealed class StaplesItem` with subtypes: `ProductItem`, `LocatedItem`, `SwappedItem`. Update all `is` checks to exhaustive `switch`.
- **Why**: Prevents runtime crashes from unhandled types and makes serialization cleaner.

### 2.3 Settings Screen
- **What**: Allow users to change ZIP code and dietary preferences after onboarding.
- **Where**: New file `lib/presentation/settings/settings_screen.dart`
- **How**: Reuse the onboarding UI components. Add a settings icon to the home screen app bar. Route: `/settings`.
- **Files to modify**:
  - `lib/app/app.dart` — add `/settings` route
  - `lib/presentation/home/home_screen.dart` — add settings icon to app bar

### 2.4 Remove Admin Screen
- **What**: The admin screen is a non-functional stub. Remove it.
- **Where**: Delete `lib/presentation/admin/admin_screen.dart`, remove route from `lib/app/app.dart`

---

## Iteration 3 — Trust & Engagement

> **Goal**: Make health analysis more nuanced and give users a reason to come back.

### 3.1 Health Score Spectrum (0–100)
- **What**: Replace binary pass/fail health analysis with a continuous 0–100 score.
- **Where**: `lib/domain/logic/custom_health_filter.dart`, `lib/domain/logic/filters/`
- **How**:
  1. Add a `double score(Product product, UserProfile profile)` method to `DietaryFilter` interface
  2. Each filter returns 0.0–1.0 based on severity (e.g., sugar at 5g = 0.9, sugar at 25g = 0.2)
  3. `CustomHealthFilter` aggregates sub-scores into a weighted composite
  4. Product details screen shows a colored score badge (green 80+, yellow 50-79, red <50) instead of just pass/fail
- **Impact**: Users understand *why* and *how much* a product is good/bad. Currently a product with 11g sugar looks identical to one with 50g.

### 3.2 Weekly Savings Tracker
- **What**: Track cumulative health improvements and price savings from swaps.
- **Where**: New file `lib/domain/logic/savings_tracker.dart`, modify `lib/presentation/home/home_screen.dart`
- **How**:
  1. When a swap is accepted, record: `{ date, originalPrice, swapPrice, healthScoreImprovement }`
  2. Home screen shows: "This week: 3 swaps, saved $4.20, -45g added sugar"
  3. Persist with same storage mechanism as 2.1
- **Impact**: Creates recurring engagement. Users open the app to see their progress.

### 3.3 Connect Home Screen to Real Data
- **What**: Replace hardcoded swap cards on the home screen with actual recent items from the staples list.
- **Where**: `lib/presentation/home/home_screen.dart`
- **How**: Read from `staplesListProvider`, show the last 3 items. If list is empty, show onboarding prompts ("Scan your first item!").

---

## Iteration 4 — Monetization

> **Goal**: Generate revenue without degrading UX.

### 4.1 Affiliate Links
- **What**: When the app says "Available at Kroger (1.2 mi)" — make it tappable with an affiliate link.
- **Where**: `lib/presentation/results/ghost_swap_card.dart`, `lib/presentation/results/accepted_item_card.dart`, `lib/presentation/results/staples_list_screen.dart`
- **How**:
  1. Store strategies should return a `productUrl` field alongside price/store/distance
  2. Wrap store name in cards with `url_launcher` to open the store's product page
  3. Use Kroger/Walmart affiliate program URLs with your partner tracking ID
- **Files to modify**:
  - `lib/data/services/store_pricing_strategies/kroger_strategy.dart` — return product URL
  - `lib/data/services/store_pricing_strategies/walmart_strategy.dart` — return product URL
  - `lib/domain/models/swap_proposal.dart` — add `storeUrl` field
  - `lib/domain/models/located_product.dart` — add `storeUrl` field
  - All cards that display store info — add tappable link

### 4.2 Freemium Scan Limit
- **What**: Free tier gets 5 scans/day, premium gets unlimited.
- **Where**: `lib/data/services/throttling_service.dart` (already exists, just needs real limits)
- **How**:
  1. Change `_dailyLimit` from 1,000,000 to 5
  2. Add a `bool isPremium` flag to `UserProfile`
  3. Skip throttle check if `isPremium`
  4. Show a paywall dialog when limit reached (RevenueCat or in-app purchases)
- **Note**: The `ThrottlingService` and `ScanController` integration already exists — this is mostly config + UI.

### 4.3 Expand Store Coverage
- **What**: Add 2–3 more store pricing strategies to improve pricing hit rate.
- **Where**: `lib/data/services/store_pricing_strategies/`
- **How**: Implement `CostcoStrategy` and `TargetStrategy` (stub files already exist). Consider Instacart API as a meta-source that covers many stores.
- **Impact**: More pricing results = more affiliate opportunities = more revenue.

---

## Iteration 5 — Growth

> **Goal**: Features that drive organic acquisition.

### 5.1 Share Grocery List
- Users can share their optimized list as text via native share sheet.
- Receiver sees "Built with Alt" branding → organic install driver.

### 5.2 Barcode History
- Show scan history so users can re-find previous products.
- Cross-reference with pricing changes over time.

### 5.3 Household Profiles
- Multiple dietary profiles per household (e.g., one family member is gluten-free, another has diabetes).
- Lists can be filtered/merged per profile.
