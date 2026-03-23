import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  try {
    await SupabaseService.ensureInitialized();
  } catch (_) {
    // Supabase can be initialized lazily when the integration flow runs.
  }

  runApp(const ProviderScope(child: FitCityApp()));
}
