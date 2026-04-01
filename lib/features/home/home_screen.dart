import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/config/app_config.dart';
import 'package:alt/core/domain/models/user_profile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(40.7128, -74.0060), // Default to NYC
    zoom: 14.4746,
  );

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      context.push('/scan');
    } else if (index == 2) {
      context.push('/list'); // Favorites/Staples
    }
  }

  Future<void> _moveToZipCode(String zipCode) async {
    final locService = ref.read(locationServiceProvider);
    final position = await locService.getFallbackLocation(zipCode);
    if (position != null) {
      final controller = await _controller.future;
      if (!mounted) return;
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.0,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    ref.listen(userProfileProvider, (previous, next) {
      final oldZip = previous?.valueOrNull?.defaultZipCode;
      final newZip = next.valueOrNull?.defaultZipCode;
      if (newZip != null && newZip.isNotEmpty && oldZip != newZip) {
        _moveToZipCode(newZip);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Background
          _MapBackground(
            onMapCreated: (GoogleMapController controller) async {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }
              // Initially move to zip code if it exists
              final initialProfile = await ref.read(userProfileProvider.future);
              if (!mounted) return;
              if (initialProfile.defaultZipCode.isNotEmpty) {
                _moveToZipCode(initialProfile.defaultZipCode);
              }
            },
          ),

          // Draggable bottom sheet for main interactions
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 10, spreadRadius: 0)
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          icon: Icon(Icons.search, color: Colors.grey),
                          hintText: 'Search product or recipe...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dietary Alerts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Personalized Dietary Alerts',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            context.push('/onboarding'); // or profile edit
                          },
                          child: const Text('See Profile'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Dynamically show user's dietary preferences
                    userProfileAsync.when(
                      data: (profile) {
                        return Wrap(
                          spacing: 8,
                          children: profile.dietaryPreferences.isEmpty
                              ? [
                                  Chip(
                                    label: const Text('General Diet'),
                                    backgroundColor: Colors.grey[200],
                                    labelStyle:
                                        TextStyle(color: Colors.grey[800]),
                                  )
                                ]
                              : profile.dietaryPreferences.map((diet) {
                                  return Chip(
                                    avatar: const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16),
                                    label: Text(diet.displayName),
                                    backgroundColor: Colors.orange[50],
                                    labelStyle:
                                        TextStyle(color: Colors.orange[800]),
                                    side:
                                        BorderSide(color: Colors.orange[200]!),
                                  );
                                }).toList(),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (err, stack) =>
                          Text('Error loading profile: $err'),
                    ),
                    const SizedBox(height: 24),

                    // Giant Scan Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Vibrant green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        context.push('/scan');
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Scan Product',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recommended Swaps placeholder
                    const Text(
                      'Recommended Swaps',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildSwapCard('Regular Pasta', 'Chickpea Pasta',
                              'Gluten-Free, 23g Protein', '\$4.99'),
                          _buildSwapCard('Potato Chips', 'Veggie Crisps',
                              'Low Sodium, Baked', '\$3.49'),
                          _buildSwapCard('White Bread', 'Sprouted Wheat',
                              'High Fiber, No Sugar', '\$5.99'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSwapCard(
      String badItem, String goodItem, String benefits, String price) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badItem,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            goodItem,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
          ),
          const SizedBox(height: 4),
          Text(
            benefits,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.swap_horiz, color: Colors.green, size: 16),
              Text(
                price,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _MapBackground extends StatelessWidget {
  final MapCreatedCallback onMapCreated;

  const _MapBackground({required this.onMapCreated});

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: HomeScreen._initialPosition,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      cloudMapId: AppConfig.googleMapsMapId,
      onMapCreated: onMapCreated,
    );
  }
}
