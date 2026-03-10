# Two-Step Discovery Flow

## Feature Definition

When a user searches for a product or notepad item, the system should immediately return top alternatives with their calculated Alt Score, but without incurring the network latency or cost of querying live Kroger/Walmart pricing data.
Only upon user selection (simulated by calling `OmniStoreService` directly on the selected candidate) should the live pricing and location be retrieved.

## Input Data

Search Query: `Nutella`

## Expected Output

1. `GhostSwapEngine.getAlternatives` should return a list of `SwapProposal` items.
2. The `priceDifference`, `storeLocation`, `alternativePrice` fields MUST be `null` for all raw alternatives.
3. The `healthBenefit` must be a non-empty string outlining why the alternative is better or their Alt Score.
4. Calling `OmniStoreService.findLowestPriceNearby` on the selected alternative should return a pricing map containing `price` and `storeName`.
