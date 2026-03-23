import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/neighborhood_repository.dart';
import '../repositories/shop_repository.dart';
import '../repositories/streak_repository.dart';
import '../repositories/supabase_auth_repository.dart';
import '../repositories/supabase_task_repository.dart';
import '../repositories/task_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return SupabaseTaskRepository();
});

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  throw UnimplementedError('Wire StreakRepository implementation in Phase 2');
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  throw UnimplementedError('Wire LeaderboardRepository implementation in Phase 3');
});

final neighborhoodRepositoryProvider = Provider<NeighborhoodRepository>((ref) {
  throw UnimplementedError('Wire NeighborhoodRepository implementation in Phase 4');
});

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  throw UnimplementedError('Wire ShopRepository implementation in Phase 4');
});
