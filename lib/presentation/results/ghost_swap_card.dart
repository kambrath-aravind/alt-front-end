import 'package:flutter/material.dart';
import '../../domain/models/swap_proposal.dart';

class GhostSwapCard extends StatelessWidget {
  final SwapProposal proposal;
  final VoidCallback onAcceptSwap;

  const GhostSwapCard({
    super.key,
    required this.proposal,
    required this.onAcceptSwap,
  });

  @override
  Widget build(BuildContext context) {
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
                      Text(
                        proposal.priceDifference < 0
                            ? 'Save \$${proposal.priceDifference.abs().toStringAsFixed(2)}'
                            : 'Costs \$${proposal.priceDifference.toStringAsFixed(2)} more',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: proposal.priceDifference < 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              proposal.storeLocation
                                          .toLowerCase()
                                          .contains('online') ||
                                      proposal.storeLocation
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
}
