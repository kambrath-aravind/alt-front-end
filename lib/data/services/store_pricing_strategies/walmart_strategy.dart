import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'store_pricing_strategy.dart';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';

class WalmartStrategy implements StorePricingStrategy {
  final String _baseUrl =
      'https://developer.api.walmart.com/api-proxy/service/affil/product/v2';

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
      debugPrint('[WalmartStrategy] Signature generation FAILED: $e');
      return '';
    }
  }

  @override
  Future<Map<String, dynamic>?> getLowestPrice(
    String productBarcode,
    String queryName,
    String zipCode,
    double radiusInMiles,
  ) async {
    debugPrint(
        '[WalmartStrategy] >> getLowestPrice(barcode=$productBarcode, query=$queryName)');

    final consumerId = dotenv.env['WALMART_CONSUMER_ID'];
    final pemKey = dotenv.env['WALMART_PRIVATE_KEY_PEM'];

    if (consumerId == null || pemKey == null || consumerId.isEmpty) {
      debugPrint('[WalmartStrategy] << Missing API credentials in .env');
      return null;
    }

    debugPrint(
        '[WalmartStrategy] Consumer ID: ${consumerId.substring(0, 8)}...');

    try {
      // Try multiple barcode formats: original, UPC-A (12-digit), EAN-13 (13-digit)
      final barcodesToTry = <String>{productBarcode};
      if (productBarcode.length < 12) {
        barcodesToTry.add(productBarcode.padLeft(12, '0'));
      }
      if (productBarcode.length < 13) {
        barcodesToTry.add(productBarcode.padLeft(13, '0'));
      }

      for (final upc in barcodesToTry) {
        final result = await _tryUpcLookup(consumerId, pemKey, upc);
        if (result != null) return result;
      }

      // All UPC attempts failed — try name-based search
      debugPrint(
          '[WalmartStrategy] All UPC formats failed. Trying name search: "$queryName"');
      final nameResult = await _tryNameSearch(consumerId, pemKey, queryName);
      if (nameResult != null) return nameResult;
    } catch (e) {
      debugPrint('[WalmartStrategy] << EXCEPTION: $e');
    }

    debugPrint('[WalmartStrategy] << No price found, returning null');
    return null;
  }

  Future<Map<String, dynamic>?> _tryUpcLookup(
      String consumerId, String pemKey, String upc) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = _generateSignature(consumerId, pemKey, timestamp);
    if (signature.isEmpty) {
      debugPrint('[WalmartStrategy] UPC $upc signature failed, returning null');
      return null;
    }

    final url = Uri.parse('$_baseUrl/items?upc=$upc');
    debugPrint('[WalmartStrategy] Trying UPC: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'WM_SEC.KEY_VERSION': '1',
          'WM_CONSUMER.ID': consumerId,
          'WM_CONSUMER.INTIMESTAMP': timestamp,
          'WM_SEC.AUTH_SIGNATURE': signature,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('[WalmartStrategy] UPC $upc response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _extractPrice(response.body);
      } else {
        debugPrint(
            '[WalmartStrategy] UPC $upc FAILED: ${response.statusCode} - ${response.body.substring(0, (response.body.length > 200 ? 200 : response.body.length))}');
      }
    } catch (e) {
      debugPrint('[WalmartStrategy] UPC $upc EXCEPTION: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _tryNameSearch(
      String consumerId, String pemKey, String query) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = _generateSignature(consumerId, pemKey, timestamp);
    if (signature.isEmpty) {
      debugPrint(
          '[WalmartStrategy] Name search signature failed, returning null');
      return null;
    }

    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = Uri.parse('$_baseUrl/search?query=$encodedQuery&numItems=5');
    debugPrint('[WalmartStrategy] Name search URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'WM_SEC.KEY_VERSION': '1',
          'WM_CONSUMER.ID': consumerId,
          'WM_CONSUMER.INTIMESTAMP': timestamp,
          'WM_SEC.AUTH_SIGNATURE': signature,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint(
          '[WalmartStrategy] Name search response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _extractPrice(response.body);
      } else {
        debugPrint(
            '[WalmartStrategy] Name search FAILED: ${response.statusCode} - ${response.body.substring(0, (response.body.length > 200 ? 200 : response.body.length))}');
      }
    } catch (e) {
      debugPrint('[WalmartStrategy] Name search EXCEPTION: $e');
    }
    return null;
  }

  Map<String, dynamic>? _extractPrice(String responseBody) {
    final data = jsonDecode(responseBody);
    final items = data['items'] as List?;
    debugPrint('[WalmartStrategy] Items found: ${items?.length ?? 0}');
    if (items != null && items.isNotEmpty) {
      final item = items.first;
      final double price =
          (item['salePrice'] ?? item['msrp'] ?? 0.0).toDouble();
      debugPrint('[WalmartStrategy] Price: $price');

      if (price > 0) {
        debugPrint('[WalmartStrategy] << Returning price: \$$price');
        return {
          'storeName': 'Walmart (Online/Affiliate)',
          'storeAddress': 'Online / Affiliate Network',
          'price': price,
          'distance': 'N/A',
          'inStock': item['stock'] == 'Available',
        };
      } else {
        debugPrint('[WalmartStrategy] Price was 0, skipping');
      }
    }
    return null;
  }
}
