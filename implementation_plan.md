# Implementation Plan - "alt" Mobile App

## Goal Description
"alt" is a mobile application designed to help consumers make better purchasing decisions. While the MVP starts with food (chips, soda, etc.), the architecture is designed to scale to other categories like cookware, furniture, and electronics. Users scan a product, and the app analyzes it to suggest "better" alternatives (healthier, cheaper, or more sustainable) available in the market. The MVP targets the USA and India, focusing on simplicity, low cost, and a friendly, chat-like interface.

## User Review Required
> [!IMPORTANT]
> **Data Source Strategy**: Real-time pricing and availability from specific stores (Kroger, Trader Joe's, etc.) often requires paid/restricted APIs. For the MVP, we will attempt to use open/public endpoints or search tools where possible, but may rely on "General Availability" or Amazon/Walmart backfills to keep costs zero.
> **Throttling**: To maintain free-tier usage, we will enforce strict daily scan limits per device (via Anonymous Auth).

## Requirements Specification

### Core Features (MVP)
1.  **Identity & Access**:
    *   **Guest Mode**: No signup required. Friendly onboarding.
    *   **Throttling**: Firebase Anonymous Auth assigns a background ID to enforce daily usage limits.
2.  **Input/Scanning**:
    *   **Barcode Scanner**: Primary, fast identification.
    *   **Visual Recognition**: Fallback for non-barcode items or ingredient lists.
    *   **Manual Input**: Text search.
3.  **Analysis Engine (Extensible)**:
    *   **Product Lookup**: Query OpenFoodFacts (Primary). Fallback to **USDA FoodData Central** (Authoritative US Data) using GTIN/Barcode.
    *   **Store Integration (Experimental for MVP)**: Attempt to fetch data from specific retailers (Kroger, Whole Foods) via public search endpoints if available, or fall back to general web search.
    *   **Scoring Strategy (Polymorphic)**:
        *   **FoodStrategy**: Health Score (Nutri-Score), Ingredients (Red Flags), Processing (NOVA).
        *   *(Future)* **DurableGoodStrategy**: Sustainability, Durability, Price-Performance.
4.  **Recommendation System**:
    *   Suggests 1-3 alternatives based on the active Strategy.
    *   **Pricing**: Displays "Approx Price" from store data or user input.
    *   **Availability**: "Likely found at [Store Name]" (static mapping) or "Buy on Amazon".
    *   **User Feedback**: Simple Thumbs Up/Down on suggestions.
        *   *Thumbs Up*: "This was helpful/good alt".
        *   *Thumbs Down*: "Bad price/taste/availability". (Data used to improve future ranking).
5.  **Admin Interface**:
    *   Simple, hidden screen for the "Superuser" to manually link Product A -> Alternative B.
    *   **Feedback View**: Review "Thumbs Down" items to manually correct bad logic.
6.  **UI/UX**:
    *   **Vibe**: Friendly, Minimal, Chat-like (inspired by Gemini/Messaging apps).
    *   **Aesthetics**: Clean, whitespace-heavy, trusted feel.

### Technical Stack
*   **Framework**: Flutter (Dart) - Single codebase for Android (Primary) and iOS (Future).
*   **Backend**: Firebase (Spark Plan - Free).
    *   *Auth*: Anonymous Login.
    *   *Firestore*: Database for user history, product cache, and manually linked alts.
    *   *Storage*: Product images (if needed).
*   **APIs**:
    *   OpenFoodFacts API (Free, extensive).
    *   **USDA FoodData Central API** (Free, requires key). Supports search by GTIN (Barcode) and Keyword.
    *   Google ML Kit (On-device, Free) for basic barcode/text recognition.

## Proposed Changes

### Project Structure
We will initialize a standard Flutter project structure:

```text
lib/
├── main.dart
├── app/                  # App configuration, theme, routes
├── data/                 # Repositories, API clients (OpenFoodFacts, Firebase)
├── domain/               # Business Logic (HealthScorer, RecommendationEngine)
├── presentation/         # UI Code
│   ├── common/           # Reusable widgets
│   ├── scan/             # Camera/Barcode screen
│   ├── results/          # Analysis & Alternatives screen
│   └── admin/            # Hidden admin panel
└── utils/                # Constants, formatting helpers
```

### [Step 1] Project Setup
#### [NEW] [pubspec.yaml](file:///Users/aravind/development/alt/pubspec.yaml)
- Define dependencies: `firebase_core`, `cloud_firestore`, `camera`, `google_mlkit_barcode_scanning`, `go_router`, `flutter_riverpod` (state management).

### [Step 2] Core Logic Implementation
#### [NEW] [health_scorer.dart](file:///Users/aravind/development/alt/lib/domain/logic/health_scorer.dart)
- Implement the "Scoring Strategy": Inputs Product Data -> Outputs Score (0-100) & Grade (A-F).

#### [NEW] [product_repository.dart](file:///Users/aravind/development/alt/lib/data/repositories/product_repository.dart)
- Fetch from OpenFoodFacts.
- Check Firestore cache (to save API calls/latency).

### [Step 3] UI Implementation
#### [NEW] [scanner_screen.dart](file:///Users/aravind/development/alt/lib/presentation/scan/scanner_screen.dart)
- Full-screen camera view with a "Scan Barcode" overlay.
- "Take Photo" button for non-barcode items.

#### [NEW] [chat_interface.dart](file:///Users/aravind/development/alt/lib/presentation/results/chat_interface.dart)
- Display results as a conversation:
    - User: [Image of Chips]
    - Alt-Bot: "Looking at Lays Classic... That's a 'C' grade due to high salt. Here is a better option:"
    - Alt-Bot: [Card: "Kettle Low Sodium" - $3.99 - Grade 'A']

## Verification Plan

### Automated Tests
*   **Unit Tests**: Verify `HealthScorer` logic (e.g., ensure "Apple" scores higher than "Candy").
*   **Widget Tests**: Verify the Chat Interface renders messages correctly.

### Manual Verification
1.  **Throttling Test**: Open app -> Scan 10 times -> Verify the 11th is blocked.
2.  **Product Scan**: Scan a real barcode (e.g., localized test items) -> Verify data matches label.
3.  **Admin Flow**: Manually link "Bad Soda" to "Sparkling Water" in Admin -> Scan "Bad Soda" -> Verify "Sparkling Water" is suggested.
