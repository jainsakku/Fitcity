import 'package:firebase_auth/firebase_auth.dart';

import 'supabase_service.dart';

class Phase1IntegrationTestService {
  const Phase1IntegrationTestService();

  Future<Map<String, dynamic>> run() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No Firebase user found. Sign in first.');
    }

    await SupabaseService.ensureInitialized();
    final client = SupabaseService.client;
    final uid = currentUser.uid;
    final displayName = currentUser.displayName ?? 'FitCity User';

    await client.functions.invoke(
      'sync-user',
      headers: {'x-fitcity-uid': uid},
      body: {'name': displayName},
    );

    final row = await client
        .from('users')
        .select('uid,name,title,created_at,updated_at')
        .eq('uid', uid)
        .single();

    return Map<String, dynamic>.from(row);
  }
}
