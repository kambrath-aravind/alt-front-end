import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=en:pates-a-tartiner-aux-noisettes&tagtype_1=countries&tag_contains_1=contains&tag_1=united-states&sort_by=nutrition_grade_asc&page_size=30&json=1');
  
  final request = await HttpClient().getUrl(url);
  request.headers.set('User-Agent', 'AltApp/1.0 - Dart Script');
  final response = await request.close();
  
  if (response.statusCode != 200) {
    print('Failed with status: \${response.statusCode}');
    exit(1);
  }

  final responseBody = await response.transform(utf8.decoder).join();
  final data = jsonDecode(responseBody);
  
  print("Total count: ${data['count']}");
  
  final products = data['products'] as List;
  print("Returned products: ${products.length}");
  
  for (var p in products) {
    print("- ${p['product_name']} (${p['_id']})");
  }
}
