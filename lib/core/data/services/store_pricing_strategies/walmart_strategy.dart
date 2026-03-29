import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'store_pricing_strategy.dart';
import 'store_match_util.dart';
import 'package:alt/core/domain/models/pricing_failure.dart';
import 'package:alt/core/domain/models/pricing_result.dart';
import 'package:alt/utils/app_logger.dart';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';

class WalmartStrategy implements StorePricingStrategy {
  static const _tag = 'WalmartStrategy';

  final String _baseUrl =
      'https://developer.api.walmart.com/api-proxy/service/affil/product/v2';

  // ─── Signature ─────────────────────────────────────────────────

  String _generateSignature(
      String consumerId, String pemKey, String timestamp) {
    try {
      final dataToSign = '$consumerId\n$timestamp\n1\n';
      final parser = RSAKeyParser();
      final RSAPrivateKey privateKey = parser.parse(pemKey) as RSAPrivateKey;
      final signer =
          Signer(RSASigner(RSASignDigest.SHA256, privateKey: privateKey));
      final signature = signer.sign(dataToSign);
      return signature.base64;
    } catch (e) {
      AppLogger.error(_tag, 'Signature generation FAILED', e);
      return '';
    }
  }

  Map<String, String> _buildHeaders(String consumerId, String pemKey) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = _generateSignature(consumerId, pemKey, timestamp);
    return {
      'WM_SEC.KEY_VERSION': '1',
      'WM_CONSUMER.ID': consumerId,
      'WM_CONSUMER.INTIMESTAMP': timestamp,
      'WM_SEC.AUTH_SIGNATURE': signature,
      'Accept': 'application/json',
    };
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

    final consumerId = dotenv.env['WALMART_CONSUMER_ID'];
    final pemKey = dotenv.env['WALMART_PRIVATE_KEY_PEM'];

    if (consumerId == null || pemKey == null || consumerId.isEmpty) {
      AppLogger.warning(_tag, '<< Missing API credentials in .env');
      return const PricingFailureResult(PricingFailure.authFailure,
          detail: 'WALMART_CONSUMER_ID or WALMART_PRIVATE_KEY_PEM not set');
    }

    AppLogger.debug(_tag, 'Consumer ID: ${consumerId.substring(0, 8)}…');

    // Try multiple barcode formats
    final barcodesToTry = <String>{productBarcode};
    if (productBarcode.length < 12) {
      barcodesToTry.add(productBarcode.padLeft(12, '0'));
    }
    if (productBarcode.length < 13) {
      barcodesToTry.add(productBarcode.padLeft(13, '0'));
    }

    PricingFailure? lastFailure;

    for (final upc in barcodesToTry) {
      final result = await _tryUpcLookup(consumerId, pemKey, upc, queryName);
      if (result is PricingSuccess<Map<String, dynamic>>) return result;
      lastFailure = (result as PricingFailureResult).failure;
    }

    // All UPC attempts failed — try name-based search
    AppLogger.debug(
        _tag, 'All UPC formats failed. Trying name search: "$queryName"');
    final nameResult =
        await _tryNameSearch(consumerId, pemKey, queryName, productBarcode);
    if (nameResult is PricingSuccess<Map<String, dynamic>>) return nameResult;
    final nameFailure =
        (nameResult as PricingFailureResult<Map<String, dynamic>>).failure;

    final resolvedFailure = lastFailure ?? nameFailure;
    AppLogger.warning(_tag, '<< No price found, returning: $resolvedFailure');
    return PricingFailureResult(resolvedFailure,
        detail: 'No price found via any UPC format or name search');
  }

  // ─── UPC Lookup ────────────────────────────────────────────────

  Future<PricingResult<Map<String, dynamic>>> _tryUpcLookup(
      String consumerId, String pemKey, String upc, String targetName) async {
    final headers = _buildHeaders(consumerId, pemKey);
    if (headers['WM_SEC.AUTH_SIGNATURE']!.isEmpty) {
      return const PricingFailureResult(PricingFailure.authFailure,
          detail: 'Signature generation failed for UPC lookup');
    }

    final url = Uri.parse('$_baseUrl/items?upc=$upc');
    AppLogger.debug(_tag, 'Trying UPC: $url');

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      AppLogger.debug(_tag, 'UPC $upc response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _extractPrice(
          response.body,
          target: StoreMatchTarget.fromSearchQuery(
            queryName: targetName,
            barcode: upc,
          ),
          minConfidence: StoreMatchUtil.upcSearchThreshold,
        );
      }

      final snippet = response.body.substring(
          0, response.body.length > 200 ? 200 : response.body.length);
      AppLogger.warning(
          _tag, 'UPC $upc FAILED: ${response.statusCode} - $snippet');
      return const PricingFailureResult(PricingFailure.productNotFound,
          detail: 'Non-200 response for UPC lookup');
    } on TimeoutException {
      AppLogger.warning(_tag, 'UPC $upc TIMEOUT');
      return const PricingFailureResult(PricingFailure.timeout);
    } catch (e) {
      AppLogger.error(_tag, 'UPC $upc EXCEPTION', e);
      return const PricingFailureResult(PricingFailure.networkError);
    }
  }

  // ─── Name Search ───────────────────────────────────────────────

  Future<PricingResult<Map<String, dynamic>>> _tryNameSearch(String consumerId,
      String pemKey, String query, String targetBarcode) async {
    final headers = _buildHeaders(consumerId, pemKey);
    if (headers['WM_SEC.AUTH_SIGNATURE']!.isEmpty) {
      return const PricingFailureResult(PricingFailure.authFailure,
          detail: 'Signature generation failed for name search');
    }

    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = Uri.parse('$_baseUrl/search?query=$encodedQuery&numItems=5');
    AppLogger.debug(_tag, 'Name search URL: $url');

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      AppLogger.debug(_tag, 'Name search response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _extractPrice(
          response.body,
          target: StoreMatchTarget.fromSearchQuery(
            queryName: query,
            barcode: targetBarcode,
          ),
          minConfidence: StoreMatchUtil.nameSearchThreshold,
        );
      }

      final snippet = response.body.substring(
          0, response.body.length > 200 ? 200 : response.body.length);
      AppLogger.warning(
          _tag, 'Name search FAILED: ${response.statusCode} - $snippet');
      return const PricingFailureResult(PricingFailure.productNotFound,
          detail: 'Non-200 response for name search');
    } on TimeoutException {
      AppLogger.warning(_tag, 'Name search TIMEOUT');
      return const PricingFailureResult(PricingFailure.timeout);
    } catch (e) {
      AppLogger.error(_tag, 'Name search EXCEPTION', e);
      return const PricingFailureResult(PricingFailure.networkError);
    }
  }

  // ─── Price Extraction ──────────────────────────────────────────

  PricingResult<Map<String, dynamic>> _extractPrice(
    String responseBody, {
    required StoreMatchTarget target,
    required double minConfidence,
  }) {
    final data = jsonDecode(responseBody);
    final items = data['items'] as List?;
    AppLogger.debug(_tag, 'Items found: ${items?.length ?? 0}');

    if (items != null && items.isNotEmpty) {
      final candidates = items
          .whereType<Map>()
          .map((rawItem) {
            final item = rawItem.cast<String, dynamic>();
            final price =
                _asDouble(item['salePrice']) ?? _asDouble(item['msrp']);
            if (price == null || price <= 0) return null;

            return StoreCatalogCandidate(
              title: (item['name'] ?? item['productName'] ?? '').toString(),
              brand: (item['brandName'] ?? item['brand'])?.toString(),
              upc: (item['upc'] ?? item['upcNumber'])?.toString(),
              packageText: (item['size'] ?? item['packageSize'])?.toString(),
              price: price,
              inStock: item['stock'] == 'Available',
              pricingPayload: {
                'storeName': 'Walmart (Online/Affiliate)',
                'storeAddress': 'Online / Affiliate Network',
                'price': price,
                'distance': 'N/A',
                'inStock': item['stock'] == 'Available',
              },
            );
          })
          .whereType<StoreCatalogCandidate>()
          .toList();

      final bestMatch = StoreMatchUtil.pickBestCandidate(
        target: target,
        candidates: candidates,
        minConfidence: minConfidence,
      );

      if (bestMatch != null) {
        AppLogger.info(_tag,
            '<< Returning price: \$${bestMatch.candidate.price} (confidence=${bestMatch.confidence.toStringAsFixed(2)})');
        return PricingSuccess(bestMatch.candidate.pricingPayload);
      }

      AppLogger.debug(
          _tag, 'No Walmart candidates cleared confidence threshold');
    }

    return const PricingFailureResult(PricingFailure.productNotFound,
        detail: 'No items with valid price in response body');
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
