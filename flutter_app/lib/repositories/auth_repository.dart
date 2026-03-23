abstract class AuthRepository {
  Future<String?> getCurrentUserId();
  Future<void> signInWithGoogle();
  Future<void> signOut();
}
