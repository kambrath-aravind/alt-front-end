import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/services/throttling_service.dart';
import '../../app/providers.dart'; // To access the newly added provider if needed, or define here

// Repository Provider
final productRepositoryProvider = Provider((ref) => ProductRepository());

// State: nullable Product (null = no scan yet)
final scanResultProvider = StateProvider<Product?>((ref) => null);

// Loading state
final isScanningProvider = StateProvider<bool>((ref) => false);

// Message state (Error/Info) - Valid for one-time consumption
final scanMessageProvider = StateProvider<String?>((ref) => null);

class ScanController {
  final ProductRepository _repository;
  final ThrottlingService _throttlingService;
  final Ref _ref;

  ScanController(this._ref)
      : _repository = _ref.read(productRepositoryProvider),
        _throttlingService = _ref.read(throttlingServiceProvider);

  /// Validates that the barcode is a product barcode (UPC/EAN), not a QR code or URL.
  bool _isValidProductBarcode(String barcode) {
    // Product barcodes (UPC-A, UPC-E, EAN-8, EAN-13, GTIN-14) are 8-14 digits only
    final numericOnly = RegExp(r'^\d{8,14}$');
    return numericOnly.hasMatch(barcode);
  }

  Future<void> onBarcodeScanned(String barcode) async {
    // Filter out QR codes, URLs, and invalid barcodes
    if (!_isValidProductBarcode(barcode)) {
      print('[ALT_APP] Ignoring non-product barcode: $barcode');
      return;
    }

    // Prevent multiple scans
    if (_ref.read(isScanningProvider)) return;

    // Check Throttling
    final canScan = await _throttlingService.canScan();
    if (!canScan) {
      _ref.read(scanMessageProvider.notifier).state =
          "Daily scan limit reached! Come back tomorrow.";
      return;
    }

    _ref.read(isScanningProvider.notifier).state = true;

    try {
      print("[ALT_APP] Fetching product for barcode: $barcode");
      // Increment usage count before fetch (strict)
      await _throttlingService.incrementScan();

      final product = await _repository.getProduct(barcode);

      if (product != null) {
        _ref.read(scanResultProvider.notifier).state = product;
      } else {
        _ref.read(scanMessageProvider.notifier).state =
            "Product not found. Try another.";
      }
    } catch (e) {
      _ref.read(scanMessageProvider.notifier).state = "Error scanning: $e";
    } finally {
      _ref.read(isScanningProvider.notifier).state = false;
    }
  }
}

final scanControllerProvider = Provider((ref) => ScanController(ref));
