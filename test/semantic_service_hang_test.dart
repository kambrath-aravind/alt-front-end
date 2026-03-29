import 'package:flutter_test/flutter_test.dart';
import 'package:alt/core/domain/logic/semantic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Semantic Service getEmbedding does not hang',
      (WidgetTester tester) async {
    final service = SemanticService();
    await service.init();

    if (!service.isInitialized) {
      print('Init error: ${service.initializationError}');
    }

    expect(service.isInitialized, true);

    print('Starting embedding generation...');
    final result = service.getEmbedding('Test Product Snacky Snacks');
    print('Finished embedding generation. Length: ${result.length}');

    expect(result.isNotEmpty, true);
  });
}
