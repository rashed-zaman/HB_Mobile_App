import '../models/mobile_session.dart';
import 'login_payload_store.dart';

/// In-memory session for login credentials, org context, and POS shift state.
class AuthSession {
  AuthSession._();

  static String? accessToken;
  static String? tokenType;
  static String? fullname;
  static String? username;
  static String? email;
  static int? employeeId;
  static List<String> roles = [];

  static String? deviceUuid;
  static bool deviceActive = false;
  static String? deviceMessage;
  static PosAccessInfo? posAccess;
  static DeviceShiftInfo? deviceShift;
  static List<EmployeeOrgMapping> orgMappings = [];
  static List<PaymentMethodGroup> paymentMethods = [];
  static Map<String, dynamic>? loginShiftSnapshot;
  static Map<String, dynamic>? rawLoginPayload;

  /// Display values for profile menu.
  static String organization = '—';
  static String businessUnit = '—';
  static String outlet = '—';
  static String store = '—';

  /// True after successful `POST /api/mobile/pos/signin`.
  static bool posSignedIn = false;
  static Map<String, dynamic>? posSignInPayload;

  /// Value for the `Authorization` header, e.g. `Bearer eyJ...`, or null if not logged in.
  static String? get authorizationHeader {
    final token = accessToken;
    if (token == null || token.isEmpty) return null;
    final type =
        (tokenType != null && tokenType!.trim().isNotEmpty) ? tokenType!.trim() : 'Bearer';
    return '$type $token';
  }

  /// Terminal code sent on POS sign-in (first MOBILE terminal from login `posAccess`).
  static String? get terminalCode => posAccess?.defaultTerminal?.terminalCode;

  /// True when this device has an active shift owned by the logged-in employee.
  static bool get deviceShiftOperationsEnabled {
    final shift = deviceShift;
    if (shift == null || !shift.active) return false;
    final currentEmployeeId = employeeId;
    if (currentEmployeeId == null) return false;
    return shift.employeeId == currentEmployeeId;
  }

  static EmployeeOrgMapping? get defaultOrgMapping {
    if (orgMappings.isEmpty) return null;
    return orgMappings.firstWhere(
      (m) => m.isDefault,
      orElse: () => orgMappings.first,
    );
  }

  /// Default store from login org mapping (order submit).
  static int? get defaultStoreId => defaultOrgMapping?.storeId;

  /// Default location from login org mapping.
  static int? get defaultLocationId => defaultOrgMapping?.locationId;

  /// Active payment providers for a method type (`CASH`, `MFS`, `CARD`, `BANK`).
  static List<PaymentMethodProvider> providersForMethod(String methodType) {
    final normalized = methodType.trim().toUpperCase();
    for (final group in paymentMethods) {
      if (group.methodType == normalized) {
        return group.activeProviders;
      }
    }
    return const [];
  }

  static PaymentMethodProvider? defaultProviderForMethod(String methodType) {
    final normalized = methodType.trim().toUpperCase();
    for (final group in paymentMethods) {
      if (group.methodType == normalized) {
        return group.defaultProvider;
      }
    }
    return null;
  }

  static List<PaymentMethodGroup> _parsePaymentMethods(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethodGroup.fromJson)
        .where((g) => g.methodType.isNotEmpty)
        .toList();
  }

  static void applyLoginPayload(Map<String, dynamic> json) {
    rawLoginPayload = Map<String, dynamic>.from(json);

    accessToken = json['token'] as String?;
    tokenType = json['type'] as String? ?? 'Bearer';
    fullname = json['fullname'] as String?;
    username = json['username'] as String?;
    email = json['email'] as String?;
    employeeId = json['employeeId'] as int?;
    roles = (json['roles'] as List<dynamic>? ?? const [])
        .map((role) => role.toString())
        .toList();

    deviceUuid = json['deviceUuid'] as String?;
    deviceActive = json['deviceBound'] as bool? ??
        json['isBind'] as bool? ??
        json['deviceActive'] as bool? ??
        false;
    deviceMessage = json['deviceMessage'] as String?;

    paymentMethods = _parsePaymentMethods(json['paymentMethods']);

    final pos = json['posAccess'];
    posAccess = pos is Map<String, dynamic> ? PosAccessInfo.fromJson(pos) : null;

    final mappings = json['employeeOrgBuLocationStoreMappings'];
    orgMappings = mappings is List
        ? mappings
            .whereType<Map<String, dynamic>>()
            .map(EmployeeOrgMapping.fromJson)
            .toList()
        : [];

    final shift = json['shift'];
    loginShiftSnapshot = shift is Map<String, dynamic> ? Map<String, dynamic>.from(shift) : null;

    final deviceShiftJson = json['deviceShift'];
    deviceShift = deviceShiftJson is Map<String, dynamic>
        ? DeviceShiftInfo.fromJson(deviceShiftJson)
        : null;

    final mapping = defaultOrgMapping;
    if (mapping != null) {
      organization = mapping.organizationName;
      businessUnit = mapping.businessUnitName;
      final locCode = mapping.locationCode.trim();
      final locName = mapping.locationName.trim();
      outlet = locCode.isNotEmpty && locName.isNotEmpty
          ? '$locCode - $locName'
          : (locName.isNotEmpty ? locName : locCode);
      final storeCode = mapping.storeCode.trim();
      final storeName = mapping.storeName.trim();
      store = storeCode.isNotEmpty && storeName.isNotEmpty
          ? '$storeCode — $storeName'
          : (storeName.isNotEmpty ? storeName : storeCode);
    }

    posSignedIn = deviceShiftOperationsEnabled;
    posSignInPayload = null;
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

  static void applyPosSignInPayload(Map<String, dynamic> json) {
    posSignInPayload = Map<String, dynamic>.from(json);

    final deviceShiftJson = json['deviceShift'];
    if (deviceShiftJson is Map<String, dynamic>) {
      deviceShift = DeviceShiftInfo.fromJson(deviceShiftJson);
    } else if (json['status'] == true) {
      deviceShift = (deviceShift ?? const DeviceShiftInfo(active: false)).copyWith(
        active: true,
        employeeId: employeeId,
        employeeName: fullname,
        username: username,
        terminalCode: terminalCode,
        shiftOpen: true,
      );
    }

    posSignedIn = deviceShiftOperationsEnabled;
    final shift = json['shift'];
    if (shift is Map<String, dynamic>) {
      loginShiftSnapshot = Map<String, dynamic>.from(shift);
    }
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      loginShiftSnapshot ??= <String, dynamic>{};
      loginShiftSnapshot!['signInData'] = data;
    }
  }

  static void clearPosSignIn() {
    posSignedIn = false;
    posSignInPayload = null;
    if (deviceShift != null) {
      deviceShift = deviceShift!.copyWith(
        active: false,
        shiftOpen: false,
      );
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
    deviceUuid = null;
    deviceActive = false;
    deviceMessage = null;
    posAccess = null;
    deviceShift = null;
    orgMappings = [];
    paymentMethods = [];
    loginShiftSnapshot = null;
    rawLoginPayload = null;
    posSignInPayload = null;
    posSignedIn = false;
    organization = '—';
    businessUnit = '—';
    outlet = '—';
    store = '—';
    clearLoginPayload();
  }

  /// Restores session fields from persisted login API response.
  static Future<bool> restoreFromStoredLoginPayload() async {
    final stored = await getStoredLoginPayload();
    if (stored == null) return false;
    applyLoginPayload(stored);
    return true;
  }

  static bool get shiftStatus => posSignedIn;

  static void setShiftStatus(bool status) {
    posSignedIn = status;
  }
}
