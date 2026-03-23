import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';
import '../services/supabase_service.dart';

class SupabaseAuthRepository implements AuthRepository {
  @override
  Future<String?> getCurrentUserId() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Future<void> signInWithGoogle() async {
    throw UnimplementedError('Google sign-in wiring is planned in later auth phase.');
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null && displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
  }

  Future<void> syncCurrentUserToSupabase({String? displayName}) async {
    await SupabaseService.ensureInitialized();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No Firebase user available for sync.');
    }

    final response = await SupabaseService.client.functions.invoke(
      'sync-user',
      headers: {'x-fitcity-uid': uid},
      body: {
        if (displayName != null && displayName.trim().isNotEmpty) 'name': displayName.trim(),
      },
    );

    if (response.status >= 400) {
      throw Exception('sync-user failed: ${response.data}');
    }
  }

  Future<String> resolvePostAuthRouteForCurrentUser() async {
    await SupabaseService.ensureInitialized();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return '/auth';
    }

    final rows = await SupabaseService.client
        .from('users')
        .select('onboarding_completed,archetype')
        .eq('uid', uid)
        .limit(1);

    final hasRow = rows.isNotEmpty;
    final onboardingCompleted = hasRow && rows.first['onboarding_completed'] == true;
    final hasArchetype = hasRow && rows.first['archetype'] != null;

    if (onboardingCompleted) {
      return '/home';
    }
    if (hasArchetype) {
      return '/tasks';
    }
    return '/character';
  }

  @override
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
