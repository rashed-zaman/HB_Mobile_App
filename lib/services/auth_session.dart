/// Holds auth credentials for authenticated API calls after login.
class AuthSession {
  AuthSession._();

  static String? accessToken;
  static String? tokenType;

  /// Value for the `Authorization` header, e.g. `Bearer eyJ...`, or null if not logged in.
  static String? get authorizationHeader {
    final token = accessToken;
    if (token == null || token.isEmpty) return null;
    final type =
        (tokenType != null && tokenType!.trim().isNotEmpty) ? tokenType!.trim() : 'Bearer';
    return '$type $token';
  }

  static void clear() {
    accessToken = null;
    tokenType = null;
  }
}
