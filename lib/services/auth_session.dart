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
  static bool shiftStatus = false;

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
    String? organization,
    String? businessUnit,
    String? outlet,
    String? store,
  }) {
    accessToken = token;
    tokenType = type;
    AuthSession.fullname = fullname;
    AuthSession.username = username;
    AuthSession.email = email;
    AuthSession.employeeId = employeeId;
    AuthSession.roles = List<String>.from(roles);
    if (organization != null && organization.trim().isNotEmpty) {
      AuthSession.organization = organization.trim();
    }
    if (businessUnit != null && businessUnit.trim().isNotEmpty) {
      AuthSession.businessUnit = businessUnit.trim();
    }
    if (outlet != null && outlet.trim().isNotEmpty) {
      AuthSession.outlet = outlet.trim();
    }
    if (store != null && store.trim().isNotEmpty) {
      AuthSession.store = store.trim();
    }
  }

  static void clear() {
    accessToken = null;
    tokenType = null;
    fullname = null;
    username = null;
    email = null;
    employeeId = null;
    roles = [];
    organization = 'Helal & Brothers';
    businessUnit = 'Hellal & Brothers (Baburhat) [HBB]';
    outlet = 'LOC-001 - Amanat Shah Tower';
    store = 'ST-001 — AST-FG';
    shiftStatus = false;
  }

  static void setShiftStatus(bool status) {
    shiftStatus = status;
  }
}
