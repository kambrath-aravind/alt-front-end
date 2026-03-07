import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/product.dart';
import '../../domain/models/swap_proposal.dart';
import '../../domain/models/located_product.dart';
import '../../app/providers.dart';
import 'ghost_swap_card.dart';
import 'accepted_item_card.dart';

class StaplesListScreen extends ConsumerWidget {
  const StaplesListScreen({super.key});

  void _acceptSwap(WidgetRef ref, int index, SwapProposal proposal) {
    ref
        .read(staplesListProvider.notifier)
        .replaceItem(index, proposal.copyWith(isAccepted: true));
  }

  void _promptZipCode(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Zip Code'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'e.g. 90210'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final zip = controller.text.trim();
                if (zip.isNotEmpty) {
                  ref.read(userProfileProvider.notifier).updateZipCode(zip);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listItems = ref.watch(staplesListProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Staples'),
      ),
      body: userProfileAsync.when(
        data: (userProfile) {
          return Column(
            children: [
              if (userProfile.defaultZipCode.isEmpty)
                Card(
                  color: Colors.amber[100],
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                              'Please enter your zip code for local pricing.'),
                        ),
                        TextButton(
                          onPressed: () => _promptZipCode(context, ref),
                          child: const Text('Enter Zip'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: listItems.isEmpty
                    ? const Center(
                        child: Text('Scan an item to start your list.'))
                    : ListView.builder(
                        itemCount: listItems.length,
                        itemBuilder: (context, index) {
                          final item = listItems[index];

                          Widget child = const SizedBox.shrink();

                          if (item is LocatedProduct) {
                            child = _buildLocatedItemCard(item);
                          } else if (item is Product) {
                            child = ListTile(
                              leading: const Icon(Icons.shopping_bag),
                              title: Text(item.name),
                              subtitle: const Text('Approved for your diet!'),
                              trailing: const Icon(Icons.check_circle,
                                  color: Colors.green),
                            );
                          } else if (item is SwapProposal) {
                            if (item.isAccepted) {
                              child = AcceptedItemCard(proposal: item);
                            } else {
                              child = GhostSwapCard(
                                proposal: item,
                                onAcceptSwap: () =>
                                    _acceptSwap(ref, index, item),
                              );
                            }
                          }

                          return Dismissible(
                            key: Key('staples_item_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              ref
                                  .read(staplesListProvider.notifier)
                                  .removeItem(index);
                            },
                            child: child,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'notepad_fab',
            onPressed: () {
              context.push('/notepad');
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('New List'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'scan_fab',
            onPressed: () {
              context.push('/scan');
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocatedItemCard(LocatedProduct located) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (located.product.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      located.product.imageUrl!,
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
                              located.product.name,
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
                      Text(
                        located.product.brand,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
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
                            '${located.storeName} (${located.storeDistance})',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade800,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        '\$${located.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  if (located.storeAddress != null &&
                      located.storeAddress!.isNotEmpty) ...[
                    const Divider(height: 16),
                    Text(
                      located.storeAddress!,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}
