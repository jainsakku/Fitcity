abstract class NeighborhoodRepository {
  Future<List<Map<String, dynamic>>> fetchNeighborhoods();
  Future<Map<String, dynamic>> joinNeighborhood(String neighborhoodId);
  Future<Map<String, dynamic>> foundNeighborhood({required String name, required String type});
}
