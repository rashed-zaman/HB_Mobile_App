import '../config/api_config.dart';
import 'auth_session.dart';
import 'bound_device_store.dart';
import 'login_payload_store.dart';
import 'pos_shift_service.dart';

class PosSignInRequest {
  const PosSignInRequest({
    this.employeeId,
    this.terminalCode,
    this.deviceUuid,
    this.validationError,
  });

  final int? employeeId;
  final String? terminalCode;
  final String? deviceUuid;
  final String? validationError;

  bool get isValid =>
      validationError == null &&
      employeeId != null &&
      employeeId! > 0 &&
      terminalCode != null &&
      terminalCode!.trim().isNotEmpty &&
      deviceUuid != null &&
      deviceUuid!.trim().isNotEmpty;

  Map<String, dynamic> get body => {
        if (employeeId != null) 'employeeId': employeeId,
        if (terminalCode != null && terminalCode!.trim().isNotEmpty)
          'terminalCode': terminalCode!.trim(),
        if (deviceUuid != null && deviceUuid!.trim().isNotEmpty)
          'deviceUuid': deviceUuid!.trim(),
      };

  PosSignInDebugSnapshot toDebugSnapshot({
    int? statusCode,
    String? responseBody,
    String? error,
  }) {
    final uuid = deviceUuid?.trim();
    final hasDevice = uuid != null && uuid.isNotEmpty;
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': hasDevice ? uuid : 'null',
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    return PosSignInDebugSnapshot(
      url: ApiConfig.posSignIn,
      method: 'POST',
      headers: headers,
      body: body,
      statusCode: statusCode,
      responseBody: responseBody,
      error: error ?? validationError,
    );
  }
}

/// Resolves `X-Pos-Terminal-Code` from the active shift, bound device, or login.
Future<String?> resolvePosTerminalCode() async {
  final fromShift = AuthSession.deviceShift?.terminalCode?.trim();
  if (fromShift != null && fromShift.isNotEmpty) return fromShift;

  final bound = await getBoundDeviceData();
  final fromBound = bound?.terminalCode.trim();
  if (fromBound != null && fromBound.isNotEmpty) return fromBound;

  final fromSession = AuthSession.terminalCode?.trim();
  if (fromSession != null && fromSession.isNotEmpty) return fromSession;

  final signIn = AuthSession.posSignInPayload;
  final fromSignIn = signIn?['data'];
  if (fromSignIn is Map<String, dynamic>) {
    final code = fromSignIn['terminalCode']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;
  }

  final login = await getStoredLoginPayload();
  if (login != null) {
    return _terminalCodeFromLoginPayload(login);
  }

  return null;
}

Future<PosSignInRequest> resolvePosSignInRequest() async {
  final bound = await getBoundDeviceData();
  final login = await getStoredLoginPayload();

  int? employeeId = AuthSession.employeeId;
  if (employeeId == null || employeeId <= 0) {
    final fromLogin = login?['employeeId'];
    if (fromLogin is int) {
      employeeId = fromLogin;
    } else if (fromLogin != null) {
      employeeId = int.tryParse(fromLogin.toString());
    }
  }

  final terminalCode = await resolvePosTerminalCode();

  String? deviceUuid = AuthSession.deviceUuid?.trim();
  if (deviceUuid == null || deviceUuid.isEmpty) {
    final fromBound = bound?.deviceUuid.trim();
    if (fromBound != null && fromBound.isNotEmpty) {
      deviceUuid = fromBound;
    }
  }
  if (deviceUuid == null || deviceUuid.isEmpty) {
    deviceUuid = await getSavedDeviceIdForLogin();
  }

  String? validationError;
  if (employeeId == null || employeeId <= 0) {
    validationError = 'Invalid employee id. Please login again.';
  } else if (terminalCode == null || terminalCode.trim().isEmpty) {
    validationError = 'No POS terminal assigned. Bind device or contact admin.';
  } else if (deviceUuid == null || deviceUuid.trim().isEmpty) {
    validationError = 'Device Id is required. Set it in Settings first.';
  }

  return PosSignInRequest(
    employeeId: employeeId,
    terminalCode: terminalCode?.trim(),
    deviceUuid: deviceUuid?.trim(),
    validationError: validationError,
  );
}

String? _terminalCodeFromLoginPayload(Map<String, dynamic> login) {
  final posAccess = login['posAccess'];
  if (posAccess is! Map<String, dynamic>) return null;

  final terminals = posAccess['terminals'];
  if (terminals is! List || terminals.isEmpty) return null;

  for (final item in terminals) {
    if (item is Map<String, dynamic>) {
      final code = item['terminalCode']?.toString().trim();
      if (code != null && code.isNotEmpty) return code;
    }
  }
  return null;
}
