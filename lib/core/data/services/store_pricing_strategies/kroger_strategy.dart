import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'store_pricing_strategy.dart';
import 'store_match_util.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';
import 'package:alt/core/domain/models/pricing_result.dart';
import 'package:alt/utils/app_logger.dart';

class KrogerStrategy implements StorePricingStrategy {
  static const _tag = 'KrogerStrategy';

  String? _accessToken;
  DateTime? _tokenExpiry;

  final String _baseUrl = 'https://api.kroger.com/v1';

  // ─── Authentication ────────────────────────────────────────────

  /// Authenticates against the Kroger OAuth endpoint.
  /// Returns `null` on success; a [PricingFailure] on error.
  Future<PricingFailure?> _authenticate() async {
    AppLogger.debug(_tag, '>> _authenticate() called');
    final clientId = dotenv.env['KROGER_CLIENT_ID'];
    final clientSecret = dotenv.env['KROGER_CLIENT_SECRET'];

    if (clientId == null || clientSecret == null || clientId.isEmpty) {
      AppLogger.warning(_tag, 'Missing API credentials in .env');
      return PricingFailure.authFailure;
    }

    AppLogger.debug(_tag,
        'Client ID: ${clientId.substring(0, 4)}… (${clientId.length} chars)');

    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/connect/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': basicAuth,
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'product.compact',
        },
      ).timeout(const Duration(seconds: 10));

      AppLogger.debug(_tag, 'Auth response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        AppLogger.info(
            _tag, '<< Authenticated OK, token expires in ${expiresIn}s');
        return null; // success
      } else {
        final snippet = response.body.substring(
            0, response.body.length > 200 ? 200 : response.body.length);
        AppLogger.warning(
            _tag, '<< Auth FAILED: ${response.statusCode} - $snippet');
        return PricingFailure.authFailure;
      }
    } on TimeoutException {
      AppLogger.warning(_tag, '<< Auth TIMEOUT');
      return PricingFailure.timeout;
    } catch (e) {
      AppLogger.error(_tag, '<< Auth EXCEPTION', e);
      return PricingFailure.networkError;
    }
  }

  // ─── Nearest Store ─────────────────────────────────────────────

  Future<Map<String, String>?> _getNearestStore(
      String zipCode, double radiusMiles) async {
    AppLogger.debug(
        _tag, '>> _getNearestStore(zip=$zipCode, radius=$radiusMiles)');
    if (_accessToken == null) {
      AppLogger.warning(_tag, '<< No access token, skipping store lookup');
      return null;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/locations?filter.zipCode.near=$zipCode&filter.radiusInMiles=${radiusMiles.toInt()}');
      AppLogger.debug(_tag, 'Store URL: $url');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      AppLogger.debug(_tag, 'Store lookup response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final locations = data['data'] as List?;
        AppLogger.debug(_tag, 'Stores found: ${locations?.length ?? 0}');

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

          AppLogger.debug(_tag, '<< Nearest store: $storeId ($addressStr)');
          return {
            'locationId': storeId,
            if (addressStr.isNotEmpty) 'address': addressStr,
          };
        }
      }
    } on TimeoutException {
      AppLogger.warning(_tag, '<< Store lookup TIMEOUT');
    } catch (e) {
      AppLogger.error(_tag, '<< Store lookup EXCEPTION', e);
    }
    AppLogger.debug(_tag, '<< No store found');
    return null;
  }

  // ─── Product Search ────────────────────────────────────────────

  Future<Map<String, dynamic>?> _searchProduct(
    String searchTerm,
    String locationId,
    String? storeAddress,
    bool isOnlineFallback,
    double radiusInMiles,
    StoreMatchTarget target,
    double minConfidence,
  ) async {
    try {
      final encodedTerm = Uri.encodeQueryComponent(searchTerm);
      final url = Uri.parse(
          '$_baseUrl/products?filter.term=$encodedTerm&filter.locationId=$locationId');
      AppLogger.debug(_tag, 'Product URL: $url');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      AppLogger.debug(_tag, 'Product lookup response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['data'] as List?;
        AppLogger.debug(_tag, 'Products found: ${products?.length ?? 0}');

        if (products != null && products.isNotEmpty) {
          final candidates = <StoreCatalogCandidate>[];

          for (final rawProduct in products.whereType<Map>()) {
            final productData = rawProduct.cast<String, dynamic>();
            final items = productData['items'] as List?;
            if (items == null || items.isEmpty) continue;

            for (final rawItem in items.whereType<Map>()) {
              final item = rawItem.cast<String, dynamic>();
              final priceInfo = item['price'];
              AppLogger.debug(_tag, 'Price info: $priceInfo');
              final price = _asDouble(priceInfo is Map
                      ? priceInfo['promo'] ?? priceInfo['regular']
                      : null) ??
                  _asDouble(priceInfo is Map ? priceInfo['regular'] : null);
              if (price == null || price <= 0) continue;

              candidates.add(
                StoreCatalogCandidate(
                  title:
                      (productData['description'] ?? productData['name'] ?? '')
                          .toString(),
                  brand: (productData['brand'] ?? item['brand'])?.toString(),
                  upc: (item['upc'] ??
                          productData['upc'] ??
                          productData['productId'])
                      ?.toString(),
                  packageText:
                      (item['size'] ?? productData['size'])?.toString(),
                  price: price,
                  inStock: item['inventory']?['stockLevel'] != 'OUT_OF_STOCK',
                  pricingPayload: {
                    'storeName':
                        isOnlineFallback ? 'Kroger (Online)' : 'Kroger',
                    if (storeAddress != null) 'storeAddress': storeAddress,
                    'price': price,
                    'distance': isOnlineFallback
                        ? 'National Shipping'
                        : '< ${radiusInMiles.toInt()} mi',
                    'inStock':
                        item['inventory']?['stockLevel'] != 'OUT_OF_STOCK',
                  },
                ),
              );
            }
          }

          final bestMatch = StoreMatchUtil.pickBestCandidate(
            target: target,
            candidates: candidates,
            minConfidence: minConfidence,
          );

          if (bestMatch != null) {
            AppLogger.info(_tag,
                '<< Found price: \$${bestMatch.candidate.price} (confidence=${bestMatch.confidence.toStringAsFixed(2)})');
            return bestMatch.candidate.pricingPayload;
          }

          AppLogger.debug(
              _tag, 'No Kroger candidates cleared confidence threshold');
        }
      } else {
        AppLogger.warning(
            _tag, 'Product Lookup FAILED: ${response.statusCode}');
      }
    } on TimeoutException {
      AppLogger.warning(_tag, '<< Product lookup TIMEOUT');
    } catch (e) {
      AppLogger.error(_tag, '<< Product lookup EXCEPTION', e);
    }
    return null;
  }

  // ─── Public API ────────────────────────────────────────────────

  @override
  Future<PricingResult<Map<String, dynamic>>> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    AppLogger.debug(
        _tag, '>> getLowestPrice(barcode=$productBarcode, query=$queryName)');
    AppLogger.debug(_tag, '   zipCode=$zipCode, radius=$radiusInMiles');

    // 1. Ensure authenticated
    if (_accessToken == null ||
        _tokenExpiry == null ||
        DateTime.now().isAfter(_tokenExpiry!)) {
      final authFailure = await _authenticate();
      if (authFailure != null) {
        AppLogger.warning(_tag, '<< Returning auth failure');
        return PricingFailureResult(authFailure,
            detail: 'Authentication failed before product lookup');
      }
    }

    // 2. Find closest store (fall back to online)
    String? locationId;
    String? storeAddress;
    bool isOnlineFallback = false;

    if (zipCode.isNotEmpty) {
      final storeInfo = await _getNearestStore(zipCode, radiusInMiles);
      if (storeInfo != null) {
        locationId = storeInfo['locationId'];
        storeAddress = storeInfo['address'];
      }
    }

    if (locationId == null) {
      AppLogger.info(_tag,
          'No local store found. Falling back to Online Pricing (01400943)');
      locationId = '01400943';
      storeAddress = 'Online / Delivery';
      isOnlineFallback = true;
    }

    // 3. Try UPC lookup first
    final upc = productBarcode.padLeft(13, '0');
    AppLogger.debug(_tag, 'Trying UPC search: $upc');
    var result = await _searchProduct(
      upc,
      locationId,
      storeAddress,
      isOnlineFallback,
      radiusInMiles,
      StoreMatchTarget.fromSearchQuery(
        queryName: queryName,
        barcode: upc,
      ),
      StoreMatchUtil.upcSearchThreshold,
    );

    // 4. Fall back to name search
    if (result == null && queryName.isNotEmpty) {
      AppLogger.debug(_tag,
          'UPC search returned 0 results. Trying name search: "$queryName"');
      result = await _searchProduct(
        queryName,
        locationId,
        storeAddress,
        isOnlineFallback,
        radiusInMiles,
        StoreMatchTarget.fromSearchQuery(
          queryName: queryName,
          barcode: productBarcode,
        ),
        StoreMatchUtil.nameSearchThreshold,
      );
    }

    if (result != null) {
      return PricingSuccess(result);
    }

    AppLogger.warning(
        _tag, '<< No price found via UPC or name, returning productNotFound');
    return const PricingFailureResult(PricingFailure.productNotFound,
        detail: 'No price found via UPC or name search');
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
