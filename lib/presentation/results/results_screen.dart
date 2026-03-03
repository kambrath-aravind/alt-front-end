import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/providers.dart';
import '../scan/scan_controller.dart';
import '../../domain/logic/health_scorer.dart';
import '../../data/services/store_service.dart';
import '../../domain/models/recommendation.dart';
import '../../domain/models/product.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  Color _getGradeColor(ProductGrade grade) {
    switch (grade) {
      case ProductGrade.a:
        return Colors.green.shade700;
      case ProductGrade.b:
        return Colors.lightGreen;
      case ProductGrade.c:
        return Colors.yellow.shade700;
      case ProductGrade.d:
        return Colors.orange;
      case ProductGrade.e:
        return Colors.red;
      case ProductGrade.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originalProduct = ref.watch(scanResultProvider);

    if (originalProduct == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis')),
        body: const Center(child: Text('No product found')),
      );
    }

    final scorer = ref.watch(healthScorerProvider);
    final engine = ref.watch(recommendationEngineProvider);
    final grade = scorer.calculateGrade(originalProduct);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verdict'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Original Product Card with Image
              _buildOriginalProductCard(context, originalProduct, grade),

              const SizedBox(height: 24),

              // Warning for incomplete product data
              if (originalProduct.hasIncompleteData)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "This product has incomplete category data in the Open Food Facts database. Recommendations may not be accurate.",
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Text('Healthier Alternatives',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),

              // Alternatives List
              FutureBuilder<List<Recommendation>>(
                future: engine.getAlternatives(originalProduct),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }

                  final recommendations = snapshot.data ?? [];

                  if (recommendations.isEmpty) {
                    return _buildEmptyState(scorer, originalProduct);
                  }

                  return Column(
                    children: recommendations.map((rec) {
                      return _buildAlternativeCard(
                        context,
                        rec,
                        scorer.calculateGrade(rec.product),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginalProductCard(
    BuildContext context,
    Product product,
    ProductGrade grade,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Product Image
            if (product.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  height: 120,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    height: 120,
                    child: Icon(Icons.image_not_supported, size: 48),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Product Name & Brand
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              product.brand,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),

            // Grade Circle
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getGradeColor(grade),
              ),
              child: Text(
                grade.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Grade based on ingredients",
              style: TextStyle(color: Colors.grey.shade600),
            ),

            // Main Ingredients Preview
            if (product.ingredients.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "Main Ingredients",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                product.ingredients.take(5).join(', '),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeCard(
    BuildContext context,
    Recommendation rec,
    ProductGrade grade,
  ) {
    final product = rec.product;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showProductDetail(context, product, grade),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            ListTile(
              // Thumbnail Image
              leading: SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.fastfood),
                        ),
                ),
              ),
              title: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.brand),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      rec.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getGradeColor(grade),
                ),
                child: Center(
                  child: Text(
                    grade.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up_outlined, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanks for the feedback!'),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.thumb_down_outlined, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanks for the feedback!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text("Find Online"),
                    onPressed: () {
                      StoreService().findInStore(
                        product.name,
                        brand: product.brand,
                        barcode: product.id,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetail(
    BuildContext context,
    Product product,
    ProductGrade grade,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Product Image
                if (product.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      height: 200,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 200,
                        child: Icon(Icons.image_not_supported, size: 64),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Grade Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getGradeColor(grade),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Grade ${grade.name.toUpperCase()}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Product Name & Brand
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  product.brand,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Main Ingredients Section
                Text(
                  "Main Ingredients",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (product.ingredients.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.ingredients.take(10).map((ingredient) {
                      return Chip(
                        label: Text(
                          ingredient.trim(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.grey.shade100,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  )
                else
                  Text(
                    "No ingredient information available",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),

                const SizedBox(height: 24),

                // Nutri-Score & NOVA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (product.nutriScore != null)
                      _buildInfoChip(
                        "Nutri-Score",
                        product.nutriScore!.toUpperCase(),
                      ),
                    if (product.novaGroup != null)
                      _buildInfoChip(
                        "NOVA",
                        product.novaGroup.toString(),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Find Online Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    StoreService().findInStore(
                      product.name,
                      brand: product.brand,
                      barcode: product.id,
                    );
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text("Find Online"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(HealthScorer scorer, Product originalProduct) {
    final originalGrade = scorer.calculateGrade(originalProduct);

    if (originalGrade == ProductGrade.a || originalGrade == ProductGrade.b) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
              const Text(
                "Great Choice!",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This product is already ranked highly in our health score.",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text("No better alternatives found in our database... yet!"),
    );
  }
}
