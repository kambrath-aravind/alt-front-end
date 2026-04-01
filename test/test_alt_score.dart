import 'dart:convert';
import 'dart:io';
import 'package:alt/core/domain/models/product.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'package:alt/core/domain/logic/custom_health_filter.dart';
import 'package:alt/utils/app_logger.dart';

void main() async {
  AppLogger.info('TestAltScore', 'Fetching data from OpenFoodFacts...');
  final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/0028400090896.json');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  
  if (response.statusCode != 200) {
    AppLogger.error('TestAltScore', 'Failed to fetch data');
    exit(1);
  }

  final responseBody = await response.transform(utf8.decoder).join();
  final data = jsonDecode(responseBody);
  
  if (data['status'] != 1) {
    AppLogger.error('TestAltScore', 'Product not found');
    exit(1);
  }

  final productData = data['product'];
  final product = Product.fromMap(productData);
  
  AppLogger.info('TestAltScore', 'Product Name: ${product.name}');
  AppLogger.info('TestAltScore', "Ingredients: ${product.ingredients.take(5).join(', ')}");

  final filter = CustomHealthFilter();
  final profile = UserProfile(id: 'test', dietaryPreferences: [], defaultZipCode: '90210');

  final isViolation = filter.isViolation(product, profile);
  AppLogger.info('TestAltScore', 'Is Violation: $isViolation');

  final score = filter.getAltScore(product, profile);
  AppLogger.info('TestAltScore', 'Alt Score: $score');

  final reasons = filter.getViolationReasons(product, profile);
  AppLogger.info('TestAltScore', 'Violation Reasons:');
  for (var reason in reasons) {
    AppLogger.info('TestAltScore', '- $reason');
  }

  File('.agent/skills/iterative-feature-tester/features/real_payload.json').writeAsStringSync(jsonEncode(productData));
  AppLogger.info('TestAltScore', 'Wrote payload to features/real_payload.json');
}
