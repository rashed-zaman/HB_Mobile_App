/// Holds auth credentials and user context for authenticated API calls after login.
class AuthSession {
  AuthSession._();

  static String? accessToken;
  static String? tokenType;
  static String? fullname;
  static String? username;
  static String? email;
  static int? employeeId;
  static List<String> roles = [];

  /// Display values for profile menu (can be replaced when API provides them).
  static String organization = 'Helal & Brothers';
  static String businessUnit = 'Hellal & Brothers (Baburhat) [HBB]';
  static String outlet = 'LOC-001 - Amanat Shah Tower';
  static String store = 'ST-001 — AST-FG';

  /// Value for the `Authorization` header, e.g. `Bearer eyJ...`, or null if not logged in.
  static String? get authorizationHeader {
    final token = accessToken;
    if (token == null || token.isEmpty) return null;
    final type =
        (tokenType != null && tokenType!.trim().isNotEmpty) ? tokenType!.trim() : 'Bearer';
    return '$type $token';
  }

  static void setUser({
    required String token,
    required String type,
    required String fullname,
    required String username,
    required String email,
    required int employeeId,
    required List<String> roles,
  }) {
    accessToken = token;
    tokenType = type;
    AuthSession.fullname = fullname;
    AuthSession.username = username;
    AuthSession.email = email;
    AuthSession.employeeId = employeeId;
    AuthSession.roles = List<String>.from(roles);
  }

  static void clear() {
    accessToken = null;
    tokenType = null;
    fullname = null;
    username = null;
    email = null;
    employeeId = null;
    roles = [];
  }
}
