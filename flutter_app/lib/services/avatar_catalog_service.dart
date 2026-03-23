import 'supabase_service.dart';

class AvatarCatalogService {
  Future<List<String>> fetchMatchingUrls({
    required String gender,
    required String bodyType,
    required String skinTone,
    int limit = 100,
  }) async {
    await SupabaseService.ensureInitialized();

    final rows = await SupabaseService.client
        .from('avatar_catalog')
        .select('public_url')
        .eq('gender', gender)
        .eq('body_type', bodyType)
        .eq('skin_tone', skinTone)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows)
        .map((row) => row['public_url'])
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();
  }
}
