import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/swap_proposal.dart';
import '../../app/providers.dart';

class GhostSwapCard extends ConsumerWidget {
  final SwapProposal proposal;
  final VoidCallback onAcceptSwap;

  const GhostSwapCard({
    super.key,
    required this.proposal,
    required this.onAcceptSwap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final healthFilter = ref.watch(customHealthFilterProvider);

    List<String> reasons = [];
    double altScore = 0.0;
    if (userProfile != null) {
      reasons = healthFilter.getViolationReasons(proposal.originalProduct, userProfile);
      altScore = healthFilter.getAltScore(proposal.alternativeProduct, userProfile);
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header showing the problem
            if (reasons.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  iconColor: Colors.red,
                  collapsedIconColor: Colors.red,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: Text(
                    '${proposal.originalProduct.name} flagged',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  subtitle: const Text("Why it's flagged", style: TextStyle(color: Colors.red, fontSize: 12)),
                  children: reasons.map((reason) => Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("• ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(child: Text(reason, style: TextStyle(color: Colors.red.shade900, fontSize: 12))),
                      ],
                    ),
                  )).toList(),
                ),
              )
            else
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${proposal.originalProduct.name} flagged for your diet.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // The Before / After Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // BAD ITEM (Crossed out)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.originalProduct.name,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.arrow_forward_rounded, color: Colors.blue),
                const SizedBox(width: 16),

                // BETTER ITEM
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.alternativeProduct.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildMiniBadgeAltScore(altScore),
                          const SizedBox(width: 4),
                          _buildMiniBadge(
                              proposal.alternativeProduct.nutriScore
                                      ?.toUpperCase() ??
                                  "?",
                              Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        proposal.healthBenefit,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                      if (proposal
                          .alternativeProduct.ingredients.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Key Ingredients: ${proposal.alternativeProduct.ingredients.take(3).join(', ')}...',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Pricing and Location
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!proposal.comparisonAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Price Comparison Unavailable\n${proposal.comparisonReason ?? 'Package sizes are not comparable'}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else if (proposal.priceDifference != null)
                        if (proposal.priceDifference! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Switch Savings\nHealthier & Save \$${proposal.priceDifference!.toStringAsFixed(2)} at ${proposal.storeLocation != null ? proposal.storeLocation!.split(' ').first : 'Store'}!',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Costs \$${proposal.priceDifference!.abs().toStringAsFixed(2)} more',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                      const SizedBox(height: 6),
                        if (proposal.storeLocation != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  proposal.storeLocation!
                                              .toLowerCase()
                                              .contains('online') ||
                                          proposal.storeLocation!
                                              .toLowerCase()
                                              .contains('national')
                                      ? Icons.local_shipping_outlined
                                      : Icons.storefront_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Found at ${proposal.storeLocation}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (proposal.storeAddress != null &&
                                        proposal.storeAddress!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        proposal.storeAddress!,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),

                // The One-Tap Swap Button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Adds healthier item\nto your list',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: onAcceptSwap,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: const Text('Add to Grocery List'),
                    ),
                  ],
                )
              ],
            )
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
