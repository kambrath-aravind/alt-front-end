import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/scan/scanner_screen.dart';
import '../presentation/results/staples_list_screen.dart';
import '../presentation/results/product_details_screen.dart';
import '../presentation/admin/admin_screen.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/notepad/notepad_screen.dart';
import '../presentation/notepad/optimized_list_screen.dart';
import '../presentation/onboarding/onboarding_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final userProfileState = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // If we are still fetching GPS/defaults on startup, hold at splash or block
      if (userProfileState.isLoading) return null;

      final profile = userProfileState.valueOrNull;
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';

      if (profile == null) return null;

      if (!profile.hasCompletedOnboarding && !isGoingToOnboarding) {
        return '/onboarding';
      }

      if (profile.hasCompletedOnboarding && isGoingToOnboarding) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/list',
        builder: (context, state) => const StaplesListScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/product',
        builder: (context, state) => const ProductDetailsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/notepad',
        builder: (context, state) => const NotepadScreen(),
      ),
      GoRoute(
        path: '/notepad_results',
        builder: (context, state) {
          final rawList = state.extra as String? ?? '';
          return OptimizedListScreen(rawList: rawList);
        },
      ),
    ],
  );
});

class AltApp extends ConsumerWidget {
  const AltApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'alt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
