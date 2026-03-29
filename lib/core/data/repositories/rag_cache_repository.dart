import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'package:alt/core/domain/models/product.dart';

class RagCacheRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a consistent document ID based on the barcode and the user's specific diet.
  /// Example: "00049000028904_bloodSugarFocus-heartHealth"
  String _generateCacheKey(String productBarcode, List<DietRestriction> diets) {
    final dietNames = diets.map((e) => e.name).toList()..sort();
    final dietString = dietNames.isNotEmpty ? dietNames.join('-') : 'none';
    return '${productBarcode}_$dietString';
  }

  /// Check Level 2 Cache (Firestore) for an existing evaluation.
  Future<SwapProposal?> getCachedProposal(
      String barcode, List<DietRestriction> diets) async {
    try {
      final key = _generateCacheKey(barcode, diets);
      final doc = await _firestore.collection('ProductAnalyses').doc(key).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // Return a partially re-inflated Proposal.
        // Note: For MVP we just mock inflating the Product entities here.
        return SwapProposal(
          originalProduct: Product(
            id: barcode,
            name: data['originalName'] ?? 'Unknown',
            brand: '',
            ingredients: [],
            categoryTags: [],
          ),
          alternativeProduct: Product(
            id: data['alternativeProductId'],
            name: data['alternativeName'] ?? 'Better Option',
            brand: '',
            imageUrl: data['alternativeImage'],
            ingredients: [],
            categoryTags: [],
          ),
          priceDifference: (data['priceDifference'] as num).toDouble(),
          healthBenefit: data['healthBenefit'],
          storeLocation: data['storeLocation'],
          alternativePrice: (data['alternativePrice'] as num).toDouble(),
        );
      }
      return null;
    } catch (e) {
      // If network fails, return null to force a fresh lookup
      return null;
    }
  }

  /// Save a newly generated SweepProposal to Firestore to save costs for future users.
  Future<void> cacheProposal(
      String barcode, List<DietRestriction> diets, SwapProposal swap) async {
    try {
      final key = _generateCacheKey(barcode, diets);

      // Store the core facts for the next user.
      await _firestore.collection('ProductAnalyses').doc(key).set({
        'originalProductId': swap.originalProduct.id,
        'originalName': swap.originalProduct.name,
        'alternativeProductId': swap.alternativeProduct.id,
        'alternativeName': swap.alternativeProduct.name,
        'alternativeImage': swap.alternativeProduct.imageUrl,
        'priceDifference': swap.priceDifference,
        'healthBenefit': swap.healthBenefit,
        'storeLocation': swap.storeLocation,
        'alternativePrice': swap.alternativePrice,
        'cachingTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Intentionally swallow errors so caching failures don't break the user flow.
    }
  }
}
