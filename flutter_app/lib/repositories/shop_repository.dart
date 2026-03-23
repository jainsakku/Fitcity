abstract class ShopRepository {
  Future<List<Map<String, dynamic>>> fetchShopItems();
  Future<List<Map<String, dynamic>>> fetchInventory(String userId);
  Future<Map<String, dynamic>> purchaseItem(String itemId);
}
