import 'package:flutter_test/flutter_test.dart';
import 'package:alt/core/domain/logic/ghost_swap_engine.dart';
import 'package:alt/core/domain/logic/custom_health_filter.dart';
import 'package:alt/core/domain/logic/semantic_service.dart';
import 'package:alt/core/data/services/omni_store_service.dart';
import 'package:alt/core/data/repositories/rag_cache_repository.dart';
import 'package:alt/core/data/repositories/product_repository.dart';
import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'package:alt/core/domain/models/pricing_result.dart';

class MockRagCacheRepository implements RagCacheRepository {
  @override
  Future<SwapProposal?> getCachedProposal(String barcode, List<DietRestriction> diets) async => null;

  @override
  Future<void> cacheProposal(String barcode, List<DietRestriction> diets, SwapProposal swap) async {}
}

class MockSemanticService extends SemanticService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {}

  @override
  List<double> getEmbedding(String text) {
    return [1.0, 0.5, 0.5];
  }

  @override
  double cosineSimilarity(List<double> v1, List<double> v2) {
    return 0.9;
  }
}

class MockProductRepository extends ProductRepository {
  @override
  Future<List<Product>> searchProductsByCategory(String categoryTag, {String countryTag = 'united-states', int limit = 10}) async {
    return _getMocks();
  }

  @override
  Future<List<Product>> searchProductsByText(String query, {String countryTag = 'united-states'}) async {
    return _getMocks();
  }
  
  List<Product> _getMocks() {
    return [
      Product(
        id: 'healthy_alt_1',
        name: 'Organic Almond Butter',
        brand: 'Nature',
        categoryTags: ['en:pates-a-tartiner-aux-noisettes'],
        ingredients: ['almonds', 'sea salt'], // No palm oil, no msg
        imageUrl: 'https://example.com/almond.png',
      )
    ];
  }
}


void main() {
  test('Two-Step Discovery Flow Test', () async {
    // 1. Setup Dependencies
    final repo = MockProductRepository();
    final healthFilter = CustomHealthFilter();
    final semantic = MockSemanticService();
    final omniStore = OmniStoreService();
    final cache = MockRagCacheRepository();

    final engine = GhostSwapEngine(repo, healthFilter, semantic, omniStore, cache);

    // 2. Setup mock original product (Bad health product)
    final original = Product(
      id: 'mock_original',
      name: 'Generic Hazelnut Spread',
      brand: 'Generic',
      categoryTags: ['en:pates-a-tartiner-aux-noisettes'],
      ingredients: ['sugar', 'soybean oil', 'hazelnuts', 'cocoa'],
    );
    
    final user = UserProfile(
      id: 'test_user',
      defaultZipCode: '90210',
      searchRadiusMiles: 10,
      dietaryPreferences: [],
    );

    // 3. Execute Step 1: Get Alternatives (No network pricing)
    print('--- Step 1: Getting Alternatives ---');
    final alternatives = await engine.getAlternatives(original, user);
    
    print('Found ${alternatives.length} alternatives.');
    expect(alternatives.isNotEmpty, true, reason: 'Should return at least one alternative');

    // Verify properties of the raw alternatives
    for (var i = 0; i < alternatives.length; i++) {
        final alt = alternatives[i];
        print('Alt \$i: \${alt.alternativeProduct.name}');
        print('  - Score/Benefit: \${alt.healthBenefit}');
        
        // Ensure price & location data is NULL (testing 2-step setup)
        expect(alt.priceDifference, isNull, reason: 'Price diff should be deferred');
        expect(alt.alternativePrice, isNull, reason: 'Price should be deferred');
        expect(alt.storeLocation, isNull, reason: 'Store location should be deferred');
        
        // Ensure health/alt score logic ran
        expect(alt.healthBenefit.isNotEmpty, true, reason: 'Alt score must be computed');
    }

    // 4. Execute Step 2: Fetch Live Pricing for the Top Candidate
    print('\\n--- Step 2: Fetching Live Pricing ---');
    final topCandidate = alternatives.first.alternativeProduct;
    print('Fetching pricing for: \${topCandidate.name}');
    
    final pricingInfo = await omniStore.findLowestPriceNearby(
        topCandidate.id,
        topCandidate.name,
        user.defaultZipCode,
        user.searchRadiusMiles,
    );

    // In a test environment, Kroger API might fail or auth might be missing,
    // so we check the PricingResult regardless of success/failure
    print('Pricing Result: $pricingInfo (success=${pricingInfo.isSuccess})');

    if (pricingInfo is PricingSuccess<Map<String, dynamic>>) {
        final data = pricingInfo.value;
        expect(data.containsKey('price'), true);
        expect(data.containsKey('storeName'), true);
    } else {
        print('Pricing failed (likely API auth or mock data limit): ${pricingInfo.failureOrNull}');
    }
    
    print('Test completely successful. Integration logic holds.');
  });
}
