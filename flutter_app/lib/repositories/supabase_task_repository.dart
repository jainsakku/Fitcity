import 'package:firebase_auth/firebase_auth.dart';

import 'task_repository.dart';
import '../services/supabase_service.dart';

class SupabaseTaskRepository implements TaskRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCatalog() async {
    await SupabaseService.ensureInitialized();
    final data = await SupabaseService.client
        .from('task_catalog')
        .select('*')
        .order('category')
        .order('base_difficulty', ascending: false);

    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isEmpty) {
      throw Exception(
        'task_catalog is empty. Seed data is missing or not visible to client role. '
        'Run seed.sql and verify read policy/grants for task_catalog.'
      );
    }

    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDashboard(String userId) async {
    await SupabaseService.ensureInitialized();
    final data = await SupabaseService.client
        .from('v_user_dashboard')
        .select('*')
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Future<void> createUserTasks(List<Map<String, dynamic>> payload) async {
    await SupabaseService.ensureInitialized();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No Firebase user found.');
    }

    final response = await SupabaseService.client.functions.invoke(
      'save-user-tasks',
      headers: {'x-fitcity-uid': uid},
      body: {'tasks': payload},
    );

    if (response.status >= 400) {
      throw Exception('save-user-tasks failed: ${response.data}');
    }
  }
}
