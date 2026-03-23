abstract class TaskRepository {
  Future<List<Map<String, dynamic>>> fetchCatalog();
  Future<List<Map<String, dynamic>>> fetchDashboard(String userId);
  Future<void> createUserTasks(List<Map<String, dynamic>> payload);
}
