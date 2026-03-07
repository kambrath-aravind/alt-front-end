import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/product.dart';
import '../../domain/models/swap_proposal.dart';
import '../../domain/models/located_product.dart';
import '../../domain/models/user_profile.dart';
import '../../app/providers.dart';
import '../scan/scan_controller.dart';
import 'ghost_swap_card.dart';

enum WorkflowStep {
  analysis,
  findingAlternative,
  alternativeFound,
  checkingPrices,
  pricingFound,
  findingOriginalStore,
  originalStoreFound,
}

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  WorkflowStep _currentStep = WorkflowStep.analysis;
  List<Product> _alternatives = [];
  Product? _selectedAlternative;
  SwapProposal? _swapProposal;
  LocatedProduct? _locatedOriginal;
  String? _errorMessage;
  bool _hasAutoTriggered = false;

  Future<void> _findAlternatives(Product originalProduct) async {
    setState(() {
      _currentStep = WorkflowStep.findingAlternative;
      _errorMessage = null;
    });

    try {
      final userProfile = await ref.read(userProfileProvider.future);
      final engine = ref.read(ghostSwapEngineProvider);

      final results =
          await engine.findAlternatives(originalProduct, userProfile);

      if (results.isNotEmpty) {
        setState(() {
          _alternatives = results;
          _selectedAlternative = results.first;
          _currentStep = WorkflowStep.alternativeFound;
        });
      } else {
        setState(() {
          _errorMessage =
              "No healthier alternative found in this category that matches your diet.";
          _currentStep = WorkflowStep.analysis;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error finding alternatives: $e";
        _currentStep = WorkflowStep.analysis;
      });
    }
  }

  Future<void> _checkPrices(Product originalProduct) async {
    if (_selectedAlternative == null) return;

    // Gate: only prompt for zip if GPS is also unavailable
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile.defaultZipCode.isEmpty) {
      // Check if GPS is available before bothering with zip
      final locationService = ref.read(locationServiceProvider);
      final gpsPosition = await locationService.getCurrentLocation();
      if (gpsPosition == null) {
        final zipEntered = await _promptForZipCode();
        if (!zipEntered) {
          return;
        }
      }
    }

    setState(() {
      _currentStep = WorkflowStep.checkingPrices;
      _errorMessage = null;
    });

    try {
      final freshProfile = await ref.read(userProfileProvider.future);
      final engine = ref.read(ghostSwapEngineProvider);

      final proposal = await engine.fetchPricing(
          originalProduct, _selectedAlternative!, freshProfile);

      if (proposal != null) {
        setState(() {
          _swapProposal = proposal;
          _currentStep = WorkflowStep.pricingFound;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to fetch pricing information.";
          _currentStep = WorkflowStep.alternativeFound;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error checking prices: $e";
        _currentStep = WorkflowStep.alternativeFound;
      });
    }
  }

  /// Prompts user for their zip code. Returns true if entered.
  Future<bool> _promptForZipCode() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Location Required"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "We need your ZIP code to find local store prices. Without it, pricing may not be available.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "ZIP Code",
                hintText: "e.g. 90210",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Skip"),
          ),
          ElevatedButton(
            onPressed: () {
              final zip = controller.text.trim();
              if (zip.isNotEmpty) {
                ref.read(userProfileProvider.notifier).updateZipCode(zip);
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save & Continue"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _acceptSwap() {
    if (_swapProposal != null) {
      ref.read(staplesListProvider.notifier).addItem(_swapProposal);
      context.go('/');
    }
  }

  Future<void> _keepOriginal(Product product) async {
    // Gate: prompt for zip code if needed
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile.defaultZipCode.isEmpty) {
      final locationService = ref.read(locationServiceProvider);
      final gpsPosition = await locationService.getCurrentLocation();
      if (gpsPosition == null) {
        final zipEntered = await _promptForZipCode();
        if (!zipEntered) {
          // User skipped zip — add bare product
          ref.read(staplesListProvider.notifier).addItem(product);
          if (mounted) context.go('/');
          return;
        }
      }
    }

    setState(() {
      _currentStep = WorkflowStep.findingOriginalStore;
      _errorMessage = null;
    });

    try {
      final freshProfile = await ref.read(userProfileProvider.future);
      final engine = ref.read(ghostSwapEngineProvider);

      final located = await engine.fetchOriginalPricing(product, freshProfile);

      if (located != null) {
        setState(() {
          _locatedOriginal = located;
          _currentStep = WorkflowStep.originalStoreFound;
        });
      } else {
        // No store found — add bare product and go home
        ref.read(staplesListProvider.notifier).addItem(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'No local pricing found. Item added without store info.')),
          );
          context.go('/');
        }
      }
    } catch (e) {
      // Error — add bare product and go home
      ref.read(staplesListProvider.notifier).addItem(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding stores: $e')),
        );
        context.go('/');
      }
    }
  }

  void _addLocatedOriginal() {
    if (_locatedOriginal != null) {
      ref.read(staplesListProvider.notifier).addItem(_locatedOriginal);
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannedProduct = ref.watch(scanResultProvider) as Product?;
    final userProfileAsync = ref.watch(userProfileProvider);

    if (scannedProduct == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Analysis")),
        body: const Center(child: Text("No product scanned.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Analysis"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == WorkflowStep.alternativeFound) {
              setState(() {
                _currentStep = WorkflowStep.analysis;
                _alternatives = [];
                _selectedAlternative = null;
              });
            } else if (_currentStep == WorkflowStep.pricingFound) {
              setState(() {
                _currentStep = WorkflowStep.alternativeFound;
                _swapProposal = null;
              });
            } else {
              context.go('/scan');
            }
          },
        ),
      ),
      body: userProfileAsync.when(
        data: (user) {
          final filter = ref.read(customHealthFilterProvider);
          final isViolation = filter.isViolation(scannedProduct, user);
          final violationReason =
              filter.generateViolationReason(scannedProduct, user);

          // Auto-trigger alternative search on violation
          if (isViolation &&
              !_hasAutoTriggered &&
              _currentStep == WorkflowStep.analysis) {
            _hasAutoTriggered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _findAlternatives(scannedProduct);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Original Product Card
                _buildProductCard(scannedProduct),
                const SizedBox(height: 24),

                // 2. Health Analysis Result
                if (isViolation) ...[
                  _buildWarningBanner(violationReason),
                  const SizedBox(height: 24),
                ] else ...[
                  _buildApprovalBanner(user.dietaryPreferences.isNotEmpty
                      ? user.dietaryPreferences
                          .map((e) => e.displayName)
                          .join(', ')
                      : "General"),
                  const SizedBox(height: 24),
                ],

                // 3. Error Messages
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),

                // 4. Interactive Workflow
                _buildWorkflowUI(scannedProduct),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  // ─── Product Card ──────────────────────────────────────────────

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (product.imageUrl != null)
              Image.network(product.imageUrl!, height: 120, fit: BoxFit.contain)
            else
              const Icon(Icons.fastfood, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(product.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            Text(product.brand,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBadge("NutriScore",
                    product.nutriScore?.toUpperCase() ?? "?", Colors.blue),
                _buildBadge("Nova Group", product.novaGroup?.toString() ?? "?",
                    Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Health Banners ────────────────────────────────────────────

  Widget _buildWarningBanner(String reason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Dietary Warning",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(reason, style: TextStyle(color: Colors.red.shade900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBanner(String dietName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text("Looks good! This fits your $dietName diet perfectly.",
                style: TextStyle(
                    color: Colors.green.shade900, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── Workflow Steps ────────────────────────────────────────────

  Widget _buildWorkflowUI(Product originalProduct) {
    if (_currentStep == WorkflowStep.analysis) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _keepOriginal(originalProduct),
            child: const Text("Keep Original"),
          ),
        ],
      );
    }

    if (_currentStep == WorkflowStep.findingAlternative) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Searching for healthier alternatives...",
              style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (_currentStep == WorkflowStep.alternativeFound &&
        _alternatives.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Text(
              "Found ${_alternatives.length} Healthier Alternative${_alternatives.length > 1 ? 's' : ''}:",
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Tap one to select, then check local prices.",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          // Selectable alternative cards
          ..._alternatives.map((alt) => _buildAlternativeCard(alt)),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectedAlternative != null
                ? () => _checkPrices(originalProduct)
                : null,
            icon: const Icon(Icons.storefront),
            label: const Text("Find Near Me"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final zip =
                  ref.watch(userProfileProvider).valueOrNull?.defaultZipCode ??
                      '';
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    zip.isEmpty ? Icons.location_off : Icons.location_on,
                    size: 14,
                    color: zip.isEmpty ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    zip.isEmpty
                        ? "No location set — you'll be prompted"
                        : "Using ZIP: $zip",
                    style: TextStyle(
                      fontSize: 12,
                      color: zip.isEmpty ? Colors.red.shade300 : Colors.grey,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      );
    }

    if (_currentStep == WorkflowStep.checkingPrices) {
      return const Column(
        children: [
          CircularProgressIndicator(color: Colors.black),
          SizedBox(height: 16),
          Text("Querying local stores for availability...",
              style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (_currentStep == WorkflowStep.findingOriginalStore) {
      return const Column(
        children: [
          CircularProgressIndicator(color: Colors.black),
          SizedBox(height: 16),
          Text('Finding stores near you…',
              style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    if (_currentStep == WorkflowStep.originalStoreFound &&
        _locatedOriginal != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 16),
          _buildLocatedProductCard(_locatedOriginal!),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addLocatedOriginal,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to List'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    if (_currentStep == WorkflowStep.pricingFound && _swapProposal != null) {
      return Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          GhostSwapCard(
            proposal: _swapProposal!,
            onAcceptSwap: _acceptSwap,
          ),
          TextButton(
            onPressed: () => _keepOriginal(originalProduct),
            child: const Text("Keep original and add to list"),
          )
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ─── Alternative Card ──────────────────────────────────────────

  Widget _buildAlternativeCard(Product alt) {
    final isSelected = _selectedAlternative?.id == alt.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedAlternative = alt),
      child: Card(
        color: isSelected ? Colors.green.shade50 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection indicator
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),

              // Image
              if (alt.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(alt.imageUrl!,
                      width: 48, height: 48, fit: BoxFit.contain),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.fastfood, size: 24, color: Colors.grey),
                ),
              const SizedBox(width: 12),

              // Name + brand
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alt.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (alt.brand.isNotEmpty)
                      Text(alt.brand,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    if (alt.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Ingredients: ${alt.ingredients.take(3).join(', ')}...',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // NutriScore + Nova badges
              Column(
                children: [
                  _buildMiniBadge(
                      alt.nutriScore?.toUpperCase() ?? "?", Colors.blue),
                  const SizedBox(height: 4),
                  _buildMiniBadge("N${alt.novaGroup ?? '?'}", Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Badges ────────────────────────────────────────────────────

  Widget _buildBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  // ─── Located Product Card ────────────────────────────────────

  Widget _buildLocatedProductCard(LocatedProduct located) {
    return Card(
      elevation: 2,
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
                Icon(Icons.storefront, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text('Nearest Store Found',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
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
                    const SizedBox(height: 6),
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

  Widget _buildMiniBadge(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(value,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
