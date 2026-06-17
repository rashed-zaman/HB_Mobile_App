import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_session.dart';

class PosShiftException implements Exception {
  const PosShiftException(this.message, {this.debug});

  final String message;
  final PosSignInDebugSnapshot? debug;

  @override
  String toString() => message;
}

class PosShiftStatus {
  const PosShiftStatus({
    required this.canSignOutWeb,
    this.pendingSettlement = false,
    this.settlementAccepted = false,
    this.canSubmitSettlement = false,
    this.settlementRequired = false,
    this.changeMoneyBlocksBilling = false,
    this.currentUserSignedIn = false,
    this.raw,
  });

  final bool canSignOutWeb;
  final bool pendingSettlement;
  final bool settlementAccepted;
  final bool canSubmitSettlement;
  final bool settlementRequired;
  final bool changeMoneyBlocksBilling;
  final bool currentUserSignedIn;
  final Map<String, dynamic>? raw;

  factory PosShiftStatus.fromApiData(Map<String, dynamic>? data) {
    if (data == null) {
      return const PosShiftStatus(canSignOutWeb: false);
    }
    return PosShiftStatus(
      canSignOutWeb: data['canSignOutWeb'] == true,
      pendingSettlement: data['pendingSettlement'] == true,
      settlementAccepted: data['settlementAccepted'] == true,
      canSubmitSettlement: data['canSubmitSettlement'] == true,
      settlementRequired: data['settlementRequired'] == true,
      changeMoneyBlocksBilling: data['changeMoneyBlocksBilling'] == true,
      currentUserSignedIn: data['currentUserSignedIn'] == true,
      raw: data,
    );
  }

  String? get signOffBlockedReason {
    if (canSignOutWeb) return null;
    if (!currentUserSignedIn) {
      return 'You are not signed in on this terminal.';
    }
    if (pendingSettlement) {
      return 'Settlement is awaiting manager approval.';
    }
    if (settlementRequired) {
      return 'Submit settlement before ending billing.';
    }
    if (changeMoneyBlocksBilling) {
      return 'Accept change money before ending billing.';
    }
    return 'End billing is not available right now.';
  }
}

class PosSignInDebugSnapshot {
  const PosSignInDebugSnapshot({
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
    this.statusCode,
    this.responseBody,
    this.error,
  });

  final Uri url;
  final String method;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
  final int? statusCode;
  final String? responseBody;
  final String? error;

  String format() {
    final buffer = StringBuffer()
      ..writeln('─── POS SHIFT REQUEST ───')
      ..writeln('$method $url')
      ..writeln('')
      ..writeln('Headers:')
      ..writeln(_prettyMap(headers))
      ..writeln('')
      ..writeln('Body:')
      ..writeln(_prettyJson(body));

    if (statusCode != null || responseBody != null) {
      buffer
        ..writeln('')
        ..writeln('─── POS SHIFT RESPONSE ───')
        ..writeln('Status: ${statusCode ?? '—'}')
        ..writeln('')
        ..writeln('Body:');
      if (responseBody != null && responseBody!.trim().isNotEmpty) {
        buffer.writeln(_prettyJson(responseBody!));
      } else {
        buffer.writeln('(empty)');
      }
    }

    if (error != null && error!.trim().isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('─── ERROR ───')
        ..writeln(error);
    }

    return buffer.toString();
  }

  static String _prettyMap(Map<String, String> map) {
    return map.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
  }

  static String _prettyJson(Object value) {
    try {
      final dynamic decoded = value is String ? jsonDecode(value) : value;
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value.toString();
    }
  }
}

class PosShiftSignInResult {
  const PosShiftSignInResult({
    required this.status,
    this.message,
    this.raw,
    required this.debug,
    this.data,
  });

  final bool status;
  final String? message;
  final Map<String, dynamic>? raw;
  final PosSignInDebugSnapshot debug;
  final Map<String, dynamic>? data;
}

class PosShiftService {
  PosShiftService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PosShiftSignInResult> signIn({
    required int employeeId,
    required String terminalCode,
    required String deviceUuid,
  }) async {
    return _postShiftAction(
      url: ApiConfig.posSignIn,
      requestBody: {
        'employeeId': employeeId,
        'terminalCode': terminalCode,
        'deviceUuid': deviceUuid,
      },
      terminalCode: terminalCode,
      deviceUuid: deviceUuid,
      failureMessage: 'Sign in failed. Please try again.',
    );
  }

  Future<PosShiftSignInResult> signOut({
    required int employeeId,
    required String terminalCode,
  }) async {
    return _postShiftAction(
      url: ApiConfig.posSignOut,
      requestBody: {
        'employeeId': employeeId,
        'terminalCode': terminalCode,
      },
      terminalCode: terminalCode,
      failureMessage: 'Sign off failed. Please try again.',
    );
  }

  Future<PosShiftStatus?> getShiftStatus({required String terminalCode}) async {
    final headers = _buildHeaders(terminalCode: terminalCode);
    final url = ApiConfig.posSignInStatus(terminalCode: terminalCode);

    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = _decodeObject(response.body);
      if (decoded['status'] != true) return null;

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;
      return PosShiftStatus.fromApiData(data);
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<PosShiftSignInResult> _postShiftAction({
    required Uri url,
    required Map<String, dynamic> requestBody,
    required String terminalCode,
    String? deviceUuid,
    required String failureMessage,
  }) async {
    final headers = _buildHeaders(
      terminalCode: terminalCode,
      deviceUuid: deviceUuid,
    );

    PosSignInDebugSnapshot debugSnapshot = PosSignInDebugSnapshot(
      url: url,
      method: 'POST',
      headers: headers,
      body: requestBody,
    );

    _debugLog(debugSnapshot.format());

    try {
      final response = await _client
          .post(url, headers: headers, body: jsonEncode(requestBody))
          .timeout(const Duration(seconds: 30));

      debugSnapshot = PosSignInDebugSnapshot(
        url: url,
        method: 'POST',
        headers: headers,
        body: requestBody,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      _debugLog(debugSnapshot.format());

      final decoded = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosShiftException(
          _readErrorMessage(decoded) ?? failureMessage,
          debug: debugSnapshot,
        );
      }

      final status = decoded['status'] == true;
      final message = decoded['message']?.toString();
      final data = decoded['data'];
      return PosShiftSignInResult(
        status: status,
        message: message,
        raw: decoded,
        data: data is Map<String, dynamic> ? data : null,
        debug: debugSnapshot,
      );
    } on TimeoutException {
      debugSnapshot = PosSignInDebugSnapshot(
        url: url,
        method: 'POST',
        headers: headers,
        body: requestBody,
        error: 'Request timed out',
      );
      _debugLog(debugSnapshot.format());
      throw PosShiftException(
        'Request timed out. Please try again.',
        debug: debugSnapshot,
      );
    } on http.ClientException catch (error) {
      debugSnapshot = PosSignInDebugSnapshot(
        url: url,
        method: 'POST',
        headers: headers,
        body: requestBody,
        error: error.message,
      );
      _debugLog(debugSnapshot.format());
      throw PosShiftException(
        'Unable to connect to the server: ${error.message}',
        debug: debugSnapshot,
      );
    } on FormatException catch (error) {
      debugSnapshot = PosSignInDebugSnapshot(
        url: url,
        method: 'POST',
        headers: headers,
        body: requestBody,
        error: 'Invalid JSON: $error',
      );
      _debugLog(debugSnapshot.format());
      throw PosShiftException(
        'Invalid server response.',
        debug: debugSnapshot,
      );
    } on PosShiftException {
      rethrow;
    }
  }

  Map<String, String> _buildHeaders({
    required String terminalCode,
    String? deviceUuid,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Pos-Terminal-Code': terminalCode,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }
    final uuid = deviceUuid?.trim();
    if (uuid != null && uuid.isNotEmpty) {
      headers['X-Device-Id'] = uuid;
    }
    return headers;
  }

  static void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('──────── POS SHIFT API ────────');
    debugPrint(message);
    debugPrint('────────────────────────────────');
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  String? _readErrorMessage(Map<String, dynamic> body) {
    final message =
        body['message'] ?? body['error'] ?? body['detail'] ?? body['title'];
    return message?.toString();
  }

  void close() {
    _client.close();
  }
}
