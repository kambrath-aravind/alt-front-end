import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'store_pricing_strategy.dart';

class KrogerStrategy implements StorePricingStrategy {
  String? _accessToken;
  DateTime? _tokenExpiry;

  final String _baseUrl = 'https://api.kroger.com/v1';

  Future<void> _authenticate() async {
    debugPrint('[KrogerStrategy] >> _authenticate() called');
    final clientId = dotenv.env['KROGER_CLIENT_ID'];
    final clientSecret = dotenv.env['KROGER_CLIENT_SECRET'];

    if (clientId == null || clientSecret == null || clientId.isEmpty) {
      debugPrint('[KrogerStrategy] Missing API credentials in .env');
      return;
    }

    debugPrint(
        '[KrogerStrategy] Client ID: ${clientId.substring(0, 4)}... (${clientId.length} chars)');

    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/connect/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': basicAuth,
        },
        body: {'grant_type': 'client_credentials', 'scope': 'product.compact'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('[KrogerStrategy] Auth response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        debugPrint(
            '[KrogerStrategy] << Authenticated OK, token expires in ${expiresIn}s');
      } else {
        debugPrint(
            '[KrogerStrategy] << Auth FAILED: ${response.statusCode} - ${response.body.substring(0, (response.body.length > 200 ? 200 : response.body.length))}');
      }
    } catch (e) {
      debugPrint('[KrogerStrategy] << Auth EXCEPTION: $e');
    }
  }

  Future<Map<String, String>?> _getNearestStore(
      String zipCode, double radiusMiles) async {
    debugPrint(
        '[KrogerStrategy] >> _getNearestStore(zipCode=$zipCode, radius=$radiusMiles)');
    if (_accessToken == null) {
      debugPrint('[KrogerStrategy] << No access token, returning null');
      return null;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/locations?filter.zipCode.near=$zipCode&filter.radiusInMiles=${radiusMiles.toInt()}');
      debugPrint('[KrogerStrategy] Store URL: $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      debugPrint(
          '[KrogerStrategy] Store lookup response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final locations = data['data'] as List?;
        debugPrint('[KrogerStrategy] Stores found: ${locations?.length ?? 0}');
        if (locations != null && locations.isNotEmpty) {
          final store = locations.first;
          final storeId = store['locationId']?.toString();

          if (storeId == null) return null;

          String addressStr = '';
          if (store['address'] != null) {
            final addr = store['address'];
            final line1 = addr['addressLine1'] ?? '';
            final city = addr['city'] ?? '';
            final state = addr['state'] ?? '';
            final zip = addr['zipCode'] ?? '';
            addressStr = '$line1, $city, $state $zip'.trim();
            if (addressStr.startsWith(',')) {
              addressStr = addressStr.substring(1).trim();
            }
          }

          debugPrint(
              '[KrogerStrategy] << Nearest store: $storeId ($addressStr)');
          return {
            'locationId': storeId,
            if (addressStr.isNotEmpty) 'address': addressStr,
          };
        }
      }
    } catch (e) {
      debugPrint('[KrogerStrategy] << Store lookup EXCEPTION: $e');
    }
    debugPrint('[KrogerStrategy] << No store found');
    return null;
  }

  /// Search Kroger products by term at a given location.
  /// Returns the first matching product's price info or null.
  Future<Map<String, dynamic>?> _searchProduct(
      String searchTerm,
      String locationId,
      String? storeAddress,
      bool isOnlineFallback,
      double radiusInMiles) async {
    try {
      final encodedTerm = Uri.encodeQueryComponent(searchTerm);
      final url = Uri.parse(
          '$_baseUrl/products?filter.term=$encodedTerm&filter.locationId=$locationId');
      debugPrint('[KrogerStrategy] Product URL: $url');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      debugPrint(
          '[KrogerStrategy] Product lookup response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['data'] as List?;
        debugPrint('[KrogerStrategy] Products found: ${products?.length ?? 0}');
        if (products != null && products.isNotEmpty) {
          final productData = products.first;
          final items = productData['items'] as List?;
          if (items != null && items.isNotEmpty) {
            final item = items.first;
            final priceInfo = item['price'];
            debugPrint('[KrogerStrategy] Price info: $priceInfo');
            if (priceInfo != null && priceInfo['regular'] != null) {
              final double price =
                  (priceInfo['promo'] ?? priceInfo['regular']).toDouble();

              debugPrint('[KrogerStrategy] << Found price: \$$price');
              return {
                'storeName': isOnlineFallback ? 'Kroger (Online)' : 'Kroger',
                if (storeAddress != null) 'storeAddress': storeAddress,
                'price': price,
                'distance': isOnlineFallback
                    ? 'National Shipping'
                    : '< ${radiusInMiles.toInt()} mi',
                'inStock': item['inventory']?['stockLevel'] != 'OUT_OF_STOCK',
              };
            }
          }
        }
      } else {
        debugPrint(
            '[KrogerStrategy] Product Lookup FAILED: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KrogerStrategy] << Product lookup EXCEPTION: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    debugPrint(
        '[KrogerStrategy] >> getLowestPrice(barcode=$productBarcode, query=$queryName)');
    debugPrint('[KrogerStrategy]    zipCode=$zipCode, radius=$radiusInMiles');

    // 1. Ensure authenticated
    if (_accessToken == null ||
        _tokenExpiry == null ||
        DateTime.now().isAfter(_tokenExpiry!)) {
      await _authenticate();
    }

    if (_accessToken == null) {
      debugPrint('[KrogerStrategy] << Auth failed, returning null');
      return null;
    }

    // 2. Find closest store or fallback
    String? locationId;
    String? storeAddress;
    if (zipCode.isNotEmpty) {
      final storeInfo = await _getNearestStore(zipCode, radiusInMiles);
      if (storeInfo != null) {
        locationId = storeInfo['locationId'];
        storeAddress = storeInfo['address'];
      }
    }

    bool isOnlineFallback = false;
    if (locationId == null) {
      debugPrint(
          '[KrogerStrategy] No store found. Falling back to Online Pricing (01400943)');
      locationId = '01400943';
      storeAddress = 'Online / Delivery';
      isOnlineFallback = true;
    }

    // 3. Try barcode (UPC) lookup first
    String upc = productBarcode.padLeft(13, '0');
    debugPrint('[KrogerStrategy] Trying UPC search: $upc');
    var result = await _searchProduct(
        upc, locationId, storeAddress, isOnlineFallback, radiusInMiles);

    // 4. Fall back to product name search if barcode didn't match
    if (result == null && queryName.isNotEmpty) {
      debugPrint(
          '[KrogerStrategy] UPC search returned 0 results. Trying name search: "$queryName"');
      result = await _searchProduct(
          queryName, locationId, storeAddress, isOnlineFallback, radiusInMiles);
    }

    if (result == null) {
      debugPrint(
          '[KrogerStrategy] << No price found via UPC or name, returning null');
    }
    return result;
  }
}
