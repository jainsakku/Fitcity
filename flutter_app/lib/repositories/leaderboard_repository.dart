abstract class LeaderboardRepository {
  Future<Map<String, dynamic>> getLeaderboard({String timeFrame = 'global', int limit = 50});
}
