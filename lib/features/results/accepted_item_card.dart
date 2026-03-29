import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import '../../app/providers.dart';

class AcceptedItemCard extends ConsumerWidget {
  final SwapProposal proposal;

  const AcceptedItemCard({
    super.key,
    required this.proposal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final altProduct = proposal.alternativeProduct;
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final healthFilter = ref.watch(customHealthFilterProvider);

    double altScore = 0.0;
    if (userProfile != null) {
      altScore = healthFilter.getAltScore(proposal.alternativeProduct, userProfile);
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (altProduct.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      altProduct.imageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fastfood,
                        color: Colors.grey, size: 28),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              altProduct.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildMiniBadgeAltScore(altScore),
                          const SizedBox(width: 4),
                          Text(
                            altProduct.brand,
                            style:
                                const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront,
                              size: 16, color: Colors.blueGrey.shade700),
                          const SizedBox(width: 6),
                          Text(
                            proposal.storeLocation ?? 'Unknown Location',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade800,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        proposal.alternativePrice != null
                            ? '\$${proposal.alternativePrice!.toStringAsFixed(2)}'
                            : '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (proposal.reasoning != null &&
                      proposal.reasoning!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            proposal.reasoning!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(value,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildMiniBadgeAltScore(double score) {
    Color color = Colors.green;
    if (score < 50) {
      color = Colors.red;
    } else if (score < 80) {
      color = Colors.orange;
    }
    return _buildMiniBadge(score.toStringAsFixed(0), color);
  }
}
