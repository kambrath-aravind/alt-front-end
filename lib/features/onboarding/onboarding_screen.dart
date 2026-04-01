import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import '../../app/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _zipController = TextEditingController();
  final List<DietRestriction> _selectedDiets = [];
  bool _isLoading = false;
  bool _isFetchingLocation = false;

  @override
  void dispose() {
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final zip = _zipController.text.trim();
    if (zip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Zip Code.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    await ref.read(userProfileProvider.notifier).updateProfile(
          zip: zip,
          diets: _selectedDiets,
          hasCompletedOnboarding: true,
        );

    // The Riverpod-powered GoRouter handles the redirect to '/' automatically
    // once 'hasCompletedOnboarding' becomes true.
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      final locService = ref.read(locationServiceProvider);
      final position = await locService.getCurrentLocation();

      if (position != null) {
        // Reverse geocoding happens in provider or we can do it here.
        // LocationService currently returns Position. Let's use geocoding here.
        final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final zip = placemarks.first.postalCode;
          if (zip != null && zip.isNotEmpty) {
            _zipController.text = zip;
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Zip Code $zip found!'),
                  backgroundColor: Colors.green),
            );
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not determine location. Please ensure permissions are granted in device settings.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding local zip: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to alt',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.eco, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                "Let's get your profile set up so we can find the best healthy alternatives near you.",
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text(
                "Location",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                "Your Zip Code is used to find local store prices and availability.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _zipController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "ZIP Code",
                  hintText: "e.g. 90210",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _isFetchingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon:
                              const Icon(Icons.my_location, color: Colors.blue),
                          onPressed: _fetchLocation,
                          tooltip: "Get Current Location",
                        ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Health & Dietary Preferences",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select any health focuses you'd like us to strictly adhere to when finding alternatives. Clean Ingredients are always prioritized.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: DietRestriction.values.map((diet) {
                    final isSelected = _selectedDiets.contains(diet);
                    return CheckboxListTile(
                      title: Text(diet.displayName),
                      value: isSelected,
                      activeColor: Colors.black,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedDiets.add(diet);
                          } else {
                            _selectedDiets.remove(diet);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black))
                  : ElevatedButton(
                      onPressed: _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save & Continue',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
