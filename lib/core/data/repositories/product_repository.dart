import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:alt/core/domain/models/product.dart';

class ProductRepository {
  final http.Client _client;

  // Configuration
  static const _timeout = Duration(seconds: 20);
  static const _maxRetries = 5;

  ProductRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Generic HTTP GET with timeout and retry logic.
  /// Retries on timeouts, exceptions, AND server errors (503/429).
  Future<http.Response?> _getWithRetry(Uri url) async {
    final headers = {
      'User-Agent': 'AltApp/1.0 (Mobile; Food Search)',
      'Accept': 'application/json',
    };

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _client.get(url, headers: headers).timeout(_timeout);

        // Treat 503 (Service Unavailable) and 429 (Too Many Requests) as retryable.
        if (response.statusCode == 503 || response.statusCode == 429) {
          debugPrint(
              '[ALT_APP] HTTP ${response.statusCode} on attempt ${attempt + 1} for $url');
          if (attempt < _maxRetries) {
            await Future.delayed(Duration(milliseconds: 1500 * (attempt + 1)));
            continue;
          }
          // All retries exhausted — return null so callers get an empty result
          // instead of trying to parse an HTML error page as JSON.
          return null;
        }

        return response;
      } on TimeoutException {
        debugPrint('[ALT_APP] Timeout on attempt ${attempt + 1} for $url');
      } catch (e) {
        debugPrint('[ALT_APP] Error on attempt ${attempt + 1}: $e');
      }

      // Wait before retry (exponential backoff: 500ms, 1000ms, …)
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
      debugPrint('[ALT_APP] Error fetching product: $e');
      return null;
    }
  }

  Future<Product?> _fetchFromOpenFoodFacts(String barcode) async {
    final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    debugPrint("[ALT_APP] Fetching URL: $url");

    final response = await _getWithRetry(url);
    if (response == null) return null;

    debugPrint("[ALT_APP] Response Code: ${response.statusCode}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint("[ALT_APP] API Status: ${data['status']}");
      if (data['status'] == 1 && data['product'] != null) {
        return Product.fromMap(data['product']);
      } else {
        debugPrint(
            "Product not found. Status: ${data['status']}, Verbose: ${data['status_verbose']}");
      }
    }
    return null;
  }

  /// Search for products using a general text search phrase to support fuzzy matching and typos.
  /// Filters to products sold in the specified country (default: United States).
  /// Best for human-entered text (like notepad inputs).
  Future<List<Product>> searchProductsByText(String query,
      {String countryTag = 'united-states'}) async {
    // We use search_terms to allow openfoodfacts to do fuzzy matching on names/categories etc.
    // Instead of forcing nutrition sorting (which ruins relevancy for text matches), we sort by popularity/scans.
    final url =
        Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?action=process'
            '&search_terms=${Uri.encodeComponent(query)}'
            '&sort_by=unique_scans_n'
            '&tagtype_0=countries&tag_contains_0=contains&tag_0=$countryTag'
            '&page_size=30&json=1');

    debugPrint("[ALT_APP] Searching Text: $url");

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

  /// Search for products matching a specific exact backend category tag.
  /// Filters to products sold in the specified country (default: United States).
  /// Best for machine-to-machine lookups (like finding alternatives to a scanned barcode's category).
  Future<List<Product>> searchProductsByCategory(String categoryTag,
      {String countryTag = 'united-states'}) async {
    // We use strict tag filtering to ensure we only get apples-to-apples comparisons.
    final url =
        Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?action=process'
            '&tagtype_0=categories&tag_contains_0=contains&tag_0=${Uri.encodeComponent(categoryTag)}'
            '&tagtype_1=countries&tag_contains_1=contains&tag_1=$countryTag'
            '&sort_by=nutrition_grade_asc&page_size=30&json=1');

    debugPrint("[ALT_APP] Searching Category: $url");

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
