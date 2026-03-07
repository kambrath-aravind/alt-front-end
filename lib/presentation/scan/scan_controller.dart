import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/throttling_service.dart';
import '../../app/providers.dart';

// Loading state
final isScanningProvider = StateProvider<bool>((ref) => false);
final scanMessageProvider = StateProvider<String?>((ref) => null);
final scanResultProvider = StateProvider<dynamic>((ref) => null);

class ScanController {
  final ProductRepository _repository;
  final ThrottlingService _throttlingService;
  final Ref _ref;

  ScanController(this._ref)
      : _repository = _ref.read(productRepositoryProvider),
        _throttlingService = _ref.read(throttlingServiceProvider);

  bool _isValidProductBarcode(String barcode) {
    final numericOnly = RegExp(r'^\d{8,14}$');
    return numericOnly.hasMatch(barcode);
  }

  Future<void> onBarcodeScanned(String barcode) async {
    if (!_isValidProductBarcode(barcode)) {
      debugPrint('[ALT_APP] Ignoring non-product barcode: $barcode');
      return;
    }

    if (_ref.read(isScanningProvider)) return;

    final canScan = await _throttlingService.canScan();
    if (!canScan) {
      _ref.read(scanMessageProvider.notifier).state =
          "Daily scan limit reached.";
      return;
    }

    _ref.read(isScanningProvider.notifier).state = true;
    _ref.read(scanMessageProvider.notifier).state =
        null; // Clear previous messages
    _ref.read(scanResultProvider.notifier).state =
        null; // Clear previous result

    try {
      await _throttlingService.incrementScan();

      // 1. Fetch Product
      final product = await _repository.getProduct(barcode);
      if (product == null) {
        _ref.read(scanMessageProvider.notifier).state = "Product not found.";
        return;
      }

      // 2. Pass product to the UI for interactive analysis
      _ref.read(scanResultProvider.notifier).state = product;
    } catch (e) {
      _ref.read(scanMessageProvider.notifier).state = "Error scanning: $e";
    } finally {
      _ref.read(isScanningProvider.notifier).state = false;
    }
  }
}

final scanControllerProvider = Provider((ref) => ScanController(ref));
