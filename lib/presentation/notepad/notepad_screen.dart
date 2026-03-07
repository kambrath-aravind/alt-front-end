import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotepadScreen extends ConsumerStatefulWidget {
  const NotepadScreen({super.key});

  @override
  ConsumerState<NotepadScreen> createState() => _NotepadScreenState();
}

class _NotepadScreenState extends ConsumerState<NotepadScreen> {
  final _textController = TextEditingController();
  final List<String> _items = [];

  void _addItem() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _items.add(text);
        _textController.clear();
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _onOptimize() {
    if (_items.isEmpty) return;

    // The optimization engine expects a newline-separated string
    final text = _items.join('\n');
    context.push('/notepad_results', extra: text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Grocery List'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Add items to your grocery list one by one.\nWe'll find the best options based on your health preferences, local prices, and distance.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // The list of added items
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          "Your list is empty.\nType an item below to begin.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.circle,
                                size: 8, color: Colors.black54),
                            title: Text(_items[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => _removeItem(index),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // The new single-line input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    autocorrect: true,
                    enableSuggestions: true,
                    keyboardType: TextInputType
                        .text, // Single-line guarantees autocorrect
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _addItem(),
                    decoration: InputDecoration(
                      hintText: 'Add an item (e.g. Bread)',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Optimize action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _items.isNotEmpty ? _onOptimize : null,
                icon: const Icon(Icons.auto_awesome),
                label:
                    const Text('Optimize List', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
