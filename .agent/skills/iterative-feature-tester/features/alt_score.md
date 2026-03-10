# Feature: Holistic Alt Score and 'Why it's flagged' Dropdowns

## Description
This feature replaces binary health pass/fail analysis with a continuous "Alt Score" (0-100) and provides specific reasons for why a product was flagged in an expandable dropdown, focusing on MSG, seed oils, artificial dyes, and other triggers.

## Usability & Output Requirements
- Requirement 1: The model must assign an Alt Score based on individual `DietaryFilter` penalties instead of immediately failing.
- Requirement 2: The model must return an aggregated list of specific violation strings (e.g. "Contains MSG or related additives.").
- Requirement 3: `CleanIngredientsFilter` must explicitly flag MSG, seed oils, and artificial dyes.

## Real Data Inputs
*(From `test_alt_score.dart` which fetched Doritos Nacho Cheese JSON from OpenFoodFacts API, using barcode 0028400090896)*
```json
// View full payload at /test/features/real_payload.json
// Excerpt:
{
  "product_name": "Nacho Cheese Flavored Tortilla Chips",
  "ingredients_text": "CORN, VEGETABLE OIL (SUNFLOWER OIL, CANOLA OIL, CORN OIL), MALTODEXTRIN (MADE FROM CORN), SALT, CHEDDAR CHEESE (MILK, CHEESE CULTURES, SALT, ENZYMES), WHEY, MONOSODIUM GLUTAMATE, BUTTERMILK, ROMANO CHEESE (PART-SKIM COW'S MILK, CHEESE CULTURES, SALT, ENZYMES), WHEY PROTEIN CONCENTRATE, ONION POWDER, CORN FLOUR, NATURAL AND ARTIFICIAL FLAVOR, DEXTROSE, TOMATO POWDER, LACTOSE, SPICES, ARTIFICIAL COLOR (YELLOW 6, YELLOW 5, RED 40), LACTIC ACID, CITRIC ACID, SUGAR, GARLIC POWDER, SKIM MILK, RED AND GREEN BELL PEPPER POWDER, DISODIUM INOSINATE, DISODIUM GUANYLATE",
  "nutriscore_grade": "d"
}
```

## Expected Output
The `CustomHealthFilter` engine should evaluate the product and output:
- Is Violation: `true`
- Alt Score: `0.0`
- Violation Reasons:
  - `Contains MSG or related additives.`
  - `Contains industrial seed oils (e.g., canola, soybean oil).`
  - `Contains artificial dyes.`

## Test Log (Iterative Status)
- Attempt 1: [2026-03-09] - Success. The features correctly parsed the ingredients text for Doritos, applied penalties, aggregated the score to 0.0, and generated the multiple reason strings accurately. UI is also updated.
