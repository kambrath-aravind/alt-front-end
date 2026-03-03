import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/scan/scanner_screen.dart';
import '../presentation/results/results_screen.dart';
import '../presentation/admin/admin_screen.dart';

class AltApp extends StatelessWidget {
  const AltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'alt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), // "Healthy" vibe
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
  ],
);
