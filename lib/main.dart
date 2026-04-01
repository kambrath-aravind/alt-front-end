import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_config_plus/flutter_config_plus.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterConfigPlus.loadEnvVariables();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('[App] Loaded environment variables.');
  } catch (e) {
    debugPrint(
        '[App] WARNING: Could not load .env file. Real API calls may fail.');
  }

  await Firebase.initializeApp();
  runApp(
    const ProviderScope(
      child: AltApp(),
    ),
  );
}
