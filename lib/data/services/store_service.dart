import 'package:url_launcher/url_launcher.dart';

class StoreService {
  /// Searches for a product online using name, brand, and optionally UPC barcode.
  Future<void> findInStore(String productName,
      {String? brand, String? barcode}) async {
    // Build a specific search query: "Brand Name Product Name UPC"
    final parts = <String>[];
    if (brand != null && brand.isNotEmpty && brand != 'Unknown Brand') {
      parts.add(brand);
    }
    parts.add(productName);
    if (barcode != null && barcode.isNotEmpty) {
      parts.add(barcode); // UPC/EAN helps find exact product
    }
    parts.add('near me'); // Location-aware search

    final query = Uri.encodeComponent(parts.join(' '));
    final url = Uri.parse('https://www.google.com/search?q=$query&tbm=shop');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print("Could not launch store search for $productName");
    }
  }
}
