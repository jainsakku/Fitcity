import 'package:firebase_auth/firebase_auth.dart';

import 'supabase_service.dart';

class Phase4Service {
  Future<String> _uid() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('No Firebase user found');
    }
    return uid;
  }

  Future<Map<String, dynamic>> getLeaderboard({required String timeFrame, int limit = 50}) async {
    await SupabaseService.ensureInitialized();
    final uid = await _uid();

    final res = await SupabaseService.client.functions.invoke(
      'get-leaderboard',
      headers: {'x-fitcity-uid': uid},
      body: {'timeFrame': timeFrame, 'limit': limit},
    );

    if (res.status >= 400) {
      throw Exception('get-leaderboard failed: ${res.data}');
    }

    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>?> getUserProfile({String? uid}) async {
    await SupabaseService.ensureInitialized();
    final effectiveUid = uid ?? await _uid();

    final rows = await SupabaseService.client
        .from('users')
        .select('uid,name,title,level,status_total,coins,body_age,real_age,lifespan_added,avatar_config')
        .eq('uid', effectiveUid)
        .limit(1);

    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getAchievements({String? uid}) async {
    await SupabaseService.ensureInitialized();
    final effectiveUid = uid ?? await _uid();

    final defs = await SupabaseService.client
        .from('achievement_definitions')
        .select('id,name,description,reward_status,reward_coins')
        .order('condition_value');

    final unlockedRows = await SupabaseService.client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', effectiveUid);

    final unlocked = unlockedRows
        .map((e) => e['achievement_id'] as String)
        .toSet();

    return List<Map<String, dynamic>>.from(defs).map((row) {
      final id = row['id'] as String;
      return {
        ...row,
        'unlocked': unlocked.contains(id),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getNeighborhoods() async {
    await SupabaseService.ensureInitialized();
    final rows = await SupabaseService.client
        .from('neighborhoods')
        .select('id,name,motto,type,theme,member_count,active_members,collective_hours,mayor_uid')
        .order('member_count', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> getPrimaryNeighborhood() async {
    await SupabaseService.ensureInitialized();
    final uid = await _uid();

    final memberships = await SupabaseService.client
        .from('neighborhood_members')
        .select('neighborhood_id,status_in_neighborhood')
        .eq('user_id', uid)
        .limit(1);

    if (memberships.isEmpty) return null;

    final neighborhoodId = memberships.first['neighborhood_id'] as String;
    final rows = await SupabaseService.client
        .from('neighborhoods')
        .select('id,name,motto,type,theme,member_count,active_members,collective_hours,mayor_uid')
        .eq('id', neighborhoodId)
        .limit(1);

    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getRaidBosses(String neighborhoodId) async {
    await SupabaseService.ensureInitialized();
    final rows = await SupabaseService.client
        .from('raid_bosses')
        .select('id,title,description,target_value,current_progress,unit,reward_status,reward_coins,deadline,is_active')
        .eq('neighborhood_id', neighborhoodId)
        .eq('is_active', true)
        .order('deadline')
        .limit(5);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getNeighborhoodMembers(String neighborhoodId) async {
    await SupabaseService.ensureInitialized();
    final members = await SupabaseService.client
        .from('neighborhood_members')
        .select('user_id,status_in_neighborhood,role')
        .eq('neighborhood_id', neighborhoodId)
        .order('status_in_neighborhood', ascending: false)
        .limit(20);

    final ids = members.map((m) => m['user_id'] as String).toList();
    if (ids.isEmpty) return const [];

    final users = await SupabaseService.client
        .from('users')
        .select('uid,name,level')
        .inFilter('uid', ids);

    final userById = {
      for (final u in users) (u['uid'] as String): Map<String, dynamic>.from(u),
    };

    return members.map((m) {
      final uid = m['user_id'] as String;
      final user = userById[uid] ?? const <String, dynamic>{};
      return {
        'uid': uid,
        'name': user['name'] ?? 'Member',
        'level': user['level'] ?? 1,
        'status_in_neighborhood': m['status_in_neighborhood'] ?? 0,
        'role': m['role'] ?? 'member',
      };
    }).toList();
  }

  Future<Map<String, dynamic>> joinNeighborhood(String neighborhoodId) async {
    await SupabaseService.ensureInitialized();
    final uid = await _uid();

    final res = await SupabaseService.client.functions.invoke(
      'join-neighborhood',
      headers: {'x-fitcity-uid': uid},
      body: {'neighborhoodId': neighborhoodId},
    );

    if (res.status >= 400) {
      throw Exception('join-neighborhood failed: ${res.data}');
    }

    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> foundNeighborhood({required String name, required String motto, required String type}) async {
    await SupabaseService.ensureInitialized();
    final uid = await _uid();

    final res = await SupabaseService.client.functions.invoke(
      'found-neighborhood',
      headers: {'x-fitcity-uid': uid},
      body: {'name': name, 'motto': motto, 'type': type},
    );

    if (res.status >= 400) {
      throw Exception('found-neighborhood failed: ${res.data}');
    }

    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> getShopItems() async {
    await SupabaseService.ensureInitialized();
    final rows = await SupabaseService.client
        .from('shop_items')
        .select('id,name,category,price,description,preview_url,is_active')
        .eq('is_active', true)
        .order('price');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<String>> getOwnedItems() async {
    await SupabaseService.ensureInitialized();
    final uid = await _uid();

    final rows = await SupabaseService.client
        .from('user_inventory')
        .select('item_id')
        .eq('user_id', uid);

    return rows.map((r) => r['item_id'] as String).toList();
  }

  Future<Map<String, dynamic>> purchaseItem(String itemId) async {
    await SupabaseService.ensureInitialized();
    final uid = await _uid();

    final res = await SupabaseService.client.functions.invoke(
      'purchase-item',
      headers: {'x-fitcity-uid': uid},
      body: {'itemId': itemId},
    );

    if (res.status >= 400) {
      throw Exception('purchase-item failed: ${res.data}');
    }

    return Map<String, dynamic>.from(res.data as Map);
  }
}
