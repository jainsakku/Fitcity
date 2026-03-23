abstract class StreakRepository {
  Future<Map<String, dynamic>> recoverStreak(String userTaskId);
  Future<Map<String, dynamic>> buyShield(String userTaskId);
}
