import 'dart:convert';
import 'dart:io';
import '../lib/domain/models/product.dart';
import '../lib/domain/models/user_profile.dart';
import '../lib/domain/logic/custom_health_filter.dart';

void main() async {
  print('Fetching data from OpenFoodFacts...');
  final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/0028400090896.json');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  
  if (response.statusCode != 200) {
    print('Failed to fetch data');
    exit(1);
  }

  final responseBody = await response.transform(utf8.decoder).join();
  final data = jsonDecode(responseBody);
  
  if (data['status'] != 1) {
    print('Product not found');
    exit(1);
  }

  final productData = data['product'];
  final product = Product.fromMap(productData);
  
  print('Product Name: ${product.name}');
  print("Ingredients: ${product.ingredients.take(5).join(', ')}");

  final filter = CustomHealthFilter();
  final profile = UserProfile(id: 'test', dietaryPreferences: [], defaultZipCode: '90210');

  final isViolation = filter.isViolation(product, profile);
  print('Is Violation: $isViolation');

  final score = filter.getAltScore(product, profile);
  print('Alt Score: $score');

  final reasons = filter.getViolationReasons(product, profile);
  print('Violation Reasons:');
  for (var reason in reasons) {
    print('- $reason');
  }

  File('.agent/skills/iterative-feature-tester/features/real_payload.json').writeAsStringSync(jsonEncode(productData));
  print('Wrote payload to features/real_payload.json');
}
