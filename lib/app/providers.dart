import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:alt/core/domain/logic/custom_health_filter.dart';
import 'package:alt/core/domain/logic/ghost_swap_engine.dart';
import 'package:alt/core/data/services/location_service.dart';
import 'package:alt/core/data/services/omni_store_service.dart';
import 'package:alt/core/data/services/throttling_service.dart';
import 'package:alt/core/data/repositories/product_repository.dart';
import 'package:alt/core/data/repositories/rag_cache_repository.dart';
import 'package:alt/core/domain/models/user_profile.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:alt/core/domain/logic/semantic_service.dart';
import 'package:alt/core/domain/logic/scoring/candidate_scorer.dart';
import 'package:alt/core/domain/logic/scoring/composite_scorer.dart';
import 'package:alt/core/domain/logic/scoring/distance_scorer.dart';
import 'package:alt/core/domain/logic/scoring/health_scorer.dart';
import 'package:alt/core/domain/logic/scoring/price_scorer.dart';
import 'package:alt/core/domain/logic/notepad_optimization_engine.dart';

// Repositories & Services
final productRepositoryProvider = Provider((ref) => ProductRepository());
final locationServiceProvider = Provider((ref) => LocationService());
final omniStoreServiceProvider = Provider((ref) => OmniStoreService());
final ragCacheRepositoryProvider = Provider((ref) => RagCacheRepository());
final throttlingServiceProvider = Provider((ref) => ThrottlingService());

// Logic
final customHealthFilterProvider = Provider((ref) => CustomHealthFilter());

// Notice: SemanticService requires async initialization.
// We provide an uninitialized instance here and will initialize it in main or on demand.
final semanticServiceProvider = Provider((ref) => SemanticService());

// Scoring Strategies (GoF Strategy Pattern)
final healthScorerProvider = Provider<CandidateScorer>(
    (ref) => HealthScorer(ref.watch(customHealthFilterProvider)));
final priceScorerProvider = Provider<CandidateScorer>((ref) => PriceScorer());
final distanceScorerProvider =
    Provider<CandidateScorer>((ref) => DistanceScorer());

// Composite Scorer (GoF Composite Pattern)
final compositeScorerProvider = Provider<CandidateScorer>((ref) {
  return CompositeScorer([
    ref.watch(healthScorerProvider),
    ref.watch(priceScorerProvider),
    ref.watch(distanceScorerProvider),
  ]);
});

final notepadOptimizationEngineProvider = Provider((ref) {
  return NotepadOptimizationEngine(
    ref.watch(productRepositoryProvider),
    ref.watch(compositeScorerProvider),
  );
});

final ghostSwapEngineProvider = Provider((ref) {
  return GhostSwapEngine(
    ref.watch(productRepositoryProvider),
    ref.watch(customHealthFilterProvider),
    ref.watch(semanticServiceProvider),
    ref.watch(omniStoreServiceProvider),
    ref.watch(ragCacheRepositoryProvider),
  );
});

// User State (Real GPS-based or prompt fallback)
class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final profile = UserProfile(
      id: 'guest_user',
      dietaryPreferences: [],
      searchRadiusMiles: 5.0,
      defaultZipCode: '',
    );

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return profile; // Return with empty zip
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint('Geolocator timeout/error: $e. Falling back to last known.');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final zip = placemarks.first.postalCode ?? '';
          if (zip.isNotEmpty) {
            return profile.copyWith(defaultZipCode: zip);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }

    return profile;
  }

  Future<void> updateZipCode(String newZip) async {
    if (state.hasValue && state.value != null) {
      state = AsyncData(state.value!.copyWith(defaultZipCode: newZip));
    }
  }

  Future<void> updateProfile({
    String? zip,
    List<DietRestriction>? diets,
    bool? hasCompletedOnboarding,
  }) async {
    if (state.hasValue && state.value != null) {
      state = AsyncData(state.value!.copyWith(
        defaultZipCode: zip ?? state.value!.defaultZipCode,
        dietaryPreferences: diets ?? state.value!.dietaryPreferences,
        hasCompletedOnboarding:
            hasCompletedOnboarding ?? state.value!.hasCompletedOnboarding,
      ));
    }
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile>(() {
  return UserProfileNotifier();
});

// Staples List State (Holds Products and SwapProposals)
final staplesListProvider =
    StateNotifierProvider<StaplesListNotifier, List<dynamic>>((ref) {
  return StaplesListNotifier();
});

class StaplesListNotifier extends StateNotifier<List<dynamic>> {
  StaplesListNotifier() : super([]);

  void addItem(dynamic item) {
    state = [...state, item];
  }

  void replaceItem(int index, dynamic newItem) {
    final newList = [...state];
    newList[index] = newItem;
    state = newList;
  }

  void removeItem(int index) {
    final newList = [...state];
    newList.removeAt(index);
    state = newList;
  }

  void clearAll() {
    state = [];
  }
}
