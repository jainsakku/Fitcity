import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _initialized = false;

  static Future<void> init({required String url, required String anonKey}) {
    _initialized = true;
    return Supabase.initialize(url: url, anonKey: anonKey);
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Supabase is not configured. Run with --dart-define=SUPABASE_URL=... '
        'and --dart-define=SUPABASE_ANON_KEY=...'
      );
    }

    await init(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
