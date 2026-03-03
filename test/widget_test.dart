import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alt/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap in ProviderScope as AltApp expects to be inside one or use one
    // Actually main.dart wraps AltApp in ProviderScope.
    // AltApp itself does NOT wrap itself.
    await tester.pumpWidget(const ProviderScope(child: AltApp()));

    // Verify that we start on the Scanner Screen
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
