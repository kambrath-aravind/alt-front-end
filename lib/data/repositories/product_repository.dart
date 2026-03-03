import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../domain/models/product.dart';

class ProductRepository {
  final http.Client _client;

  // Configuration
  static const _timeout = Duration(seconds: 20);
  static const _maxRetries = 2;

  ProductRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Generic HTTP GET with timeout and retry logic.
  Future<http.Response?> _getWithRetry(Uri url) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _client.get(url).timeout(_timeout);
        return response;
      } on TimeoutException {
        print('[ALT_APP] Timeout on attempt ${attempt + 1} for $url');
      } catch (e) {
        print('[ALT_APP] Error on attempt ${attempt + 1}: $e');
      }

      // Wait before retry (exponential backoff: 500ms, 1000ms)
      if (attempt < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return null;
  }

  /// Fetches product data by barcode (GTIN).
  /// Tries OpenFoodFacts first.
  Future<Product?> getProduct(String barcode) async {
    try {
      // 1. Try OpenFoodFacts
      final offProduct = await _fetchFromOpenFoodFacts(barcode);
      if (offProduct != null) return offProduct;

      // 2. Fallback to USDA (Stub for now)
      // return await _fetchFromUSDA(barcode);

      return null;
    } catch (e) {
      print('[ALT_APP] Error fetching product: $e');
      return null;
    }
  }

  Future<Product?> _fetchFromOpenFoodFacts(String barcode) async {
    final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    print("[ALT_APP] Fetching URL: $url");

    final response = await _getWithRetry(url);
    if (response == null) return null;

    print("[ALT_APP] Response Code: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("[ALT_APP] API Status: ${data['status']}");
      if (data['status'] == 1 && data['product'] != null) {
        return Product.fromMap(data['product']);
      } else {
        print(
            "Product not found. Status: ${data['status']}, Verbose: ${data['status_verbose']}");
      }
    }
    return null;
  }

  /// Search for better products in a specific category.
  /// Filters to products sold in the specified country (default: United States).
  Future<List<Product>> searchProducts(String categoryTag,
      {String countryTag = 'united-states'}) async {
    final url =
        Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?action=process'
            '&tagtype_0=categories&tag_contains_0=contains&tag_0=$categoryTag'
            '&tagtype_1=countries&tag_contains_1=contains&tag_1=$countryTag'
            '&sort_by=nutrition_grade_asc&page_size=50&json=1');

    print("[ALT_APP] Searching Category: $url");

    final response = await _getWithRetry(url);
    if (response == null) return [];

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['products'] != null) {
        return (data['products'] as List)
            .map((p) => Product.fromMap(p))
            .toList();
      }
    }
    return [];
  }
}
