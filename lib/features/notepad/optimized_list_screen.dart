import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import 'package:alt/core/domain/logic/optimized_list_info.dart';
import 'package:alt/core/domain/models/swap_proposal.dart';
import '../results/alternative_details_popup.dart';

final optimizedListProvider =
    FutureProvider.family<OptimizedListInfo, String>((ref, rawList) async {
  final engine = ref.read(notepadOptimizationEngineProvider);
  final user = await ref.read(userProfileProvider.future);
  return engine.optimizeList(rawList, user);
});

class OptimizedListScreen extends ConsumerStatefulWidget {
  final String rawList;

  const OptimizedListScreen({super.key, required this.rawList});

  @override
  ConsumerState<OptimizedListScreen> createState() =>
      _OptimizedListScreenState();
}

class _OptimizedListScreenState extends ConsumerState<OptimizedListScreen> {
  // Store the selected index for each query string
  final Map<String, int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    final optimizationState = ref.watch(optimizedListProvider(widget.rawList));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimized List'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: optimizationState.when(
        data: (info) => _buildResults(context, info),
        loading: () => _buildLoadingState(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.black),
          SizedBox(height: 16),
          Text(
            "Analyzing products...",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Weighing health impact, local prices, and distance...",
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, OptimizedListInfo info) {
    // Dynamically calculate the total cost based on user selection
    double currentEstimatedTotal = 0.0;
    for (final result in info.results) {
      if (result.alternatives.isNotEmpty) {
        final selectedIdx = _selectedIndices[result.query] ?? 0;
        currentEstimatedTotal +=
            result.alternatives[selectedIdx].alternativePrice ?? 0.0;
      }
    }

    return Column(
      children: [
        // Summary Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${info.results.length} items optimized',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (info.unresolvableQueries.isNotEmpty)
                    Text(
                      '${info.unresolvableQueries.length} items not found',
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Est. Total (Selected)',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '\$${(currentEstimatedTotal).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade800),
                  ),
                ],
              )
            ],
          ),
        ),

        // Missing items warning
        if (info.unresolvableQueries.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "We couldn't find healthy matches for:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.unresolvableQueries.map((q) => '"$q"').join(", "),
                        style:
                            TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // List of Items
        Expanded(
          child: ListView.builder(
            itemCount: info.results.length,
            itemBuilder: (context, index) {
              final result = info.results[index];
              return _buildResultGroup(result);
            },
          ),
        ),

        // Action Buttons
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    child: const Text('Edit List'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Add the selected alternative for each query
                      for (final result in info.results) {
                        if (result.alternatives.isNotEmpty) {
                          final selectedIdx =
                              _selectedIndices[result.query] ?? 0;
                          ref.read(staplesListProvider.notifier).addItem(result
                              .alternatives[selectedIdx]
                              .copyWith(isAccepted: true));
                        }
                      }
                      context.go('/');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept Selected'),
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildResultGroup(OptimizationResult result) {
    if (result.alternatives.isEmpty) return const SizedBox.shrink();

    final selectedIndex = _selectedIndices[result.query] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
          child: Text(
            'Alternatives for "${result.query}"',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 200, // Fixed height for horizontal cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: result.alternatives.length,
            itemBuilder: (context, index) {
              final item = result.alternatives[index];
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndices[result.query] = index;
                  });
                  // Trigger deep dive
                  showAlternativeDetails(
                    context,
                    item,
                    (proposal) {
                      ref.read(staplesListProvider.notifier).addItem(
                          proposal.copyWith(isAccepted: true));
                      context.go('/');
                    },
                  );
                },
                child: _buildOptimizedItemCard(item, isSelected: isSelected),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptimizedItemCard(SwapProposal proposal,
      {bool isSelected = false}) {
    final userProfile = ref.read(userProfileProvider).valueOrNull;
    final healthFilter = ref.read(customHealthFilterProvider);
    double altScore = 0.0;
    if (userProfile != null) {
      altScore = healthFilter.getAltScore(proposal.alternativeProduct, userProfile);
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
      child: Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected ? Colors.green.shade50 : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: Colors.green.shade400, width: 2.5)
                : BorderSide(color: Colors.grey.shade300, width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The chosen item top row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (proposal.alternativeProduct.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        proposal.alternativeProduct.imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.fastfood,
                          color: Colors.grey, size: 20),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposal.alternativeProduct.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          proposal.alternativeProduct.brand,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Price
                  Text(
                    proposal.alternativePrice != null
                        ? '\$${proposal.alternativePrice!.toStringAsFixed(2)}'
                        : 'Tap for details',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: proposal.alternativePrice != null ? 15 : 12,
                        color: proposal.alternativePrice != null ? Colors.black : Colors.blue),
                  ),
                ],
              ),
              const Spacer(),

              // Health Badges & Location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildMiniBadgeAltScore(altScore),
                      const SizedBox(width: 4),
                      _buildMiniBadge(
                          proposal.alternativeProduct.nutriScore
                                  ?.toUpperCase() ??
                              "?",
                          Colors.blue),
                      const SizedBox(width: 4),
                      _buildMiniBadge(
                          "N${proposal.alternativeProduct.novaGroup ?? '?'}",
                          Colors.orange),
                    ],
                  ),
                  if (proposal.storeLocation != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront,
                            size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Text(
                          proposal.storeLocation!.split(' ').first,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                ],
              ),

              const Divider(height: 16),

              // Reasoning
              if (proposal.reasoning != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.insights,
                            size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        const Text("Why this?",
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade700)
                  ],
                ),
                Text(
                  proposal.reasoning!,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ]
            ],
          ),
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
