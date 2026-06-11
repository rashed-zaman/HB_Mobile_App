import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.type,
    required this.username,
    required this.fullname,
    required this.email,
    required this.employeeId,
    required this.roles,
    this.organizationName = '',
    this.businessUnitName = '',
    this.locationName = '',
    this.storeName = '',
  });

  final String token;
  final String type;
  final String username;
  final String fullname;
  final String email;
  final int employeeId;
  final List<String> roles;
  final String organizationName;
  final String businessUnitName;
  final String locationName;
  final String storeName;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final mappings = json['employeeOrgBuLocationStoreMappings'];
    final Map<String, dynamic>? defaultMapping = mappings is List
        ? mappings.whereType<Map<String, dynamic>>().firstWhere(
            (entry) => entry['isDefault'] == true,
            orElse: () => mappings.whereType<Map<String, dynamic>>().isNotEmpty
                ? mappings.whereType<Map<String, dynamic>>().first
                : <String, dynamic>{},
          )
        : null;

    return LoginResponse(
      token: json['token'] as String? ?? '',
      type: json['type'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullname: json['fullname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      employeeId: json['employeeId'] as int? ?? 0,
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((role) => role.toString())
          .toList(),
      organizationName: defaultMapping?['organizationName'] as String? ?? '',
      businessUnitName: defaultMapping?['businessUnitName'] as String? ?? '',
      locationName: defaultMapping?['locationName'] as String? ?? '',
      storeName: defaultMapping?['storeName'] as String? ?? '',
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message, {this.debug});

  final String message;
  final LoginDebugSnapshot? debug;

  @override
  String toString() => message;
}

class LoginDebugSnapshot {
  const LoginDebugSnapshot({
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
      ..writeln('─── LOGIN REQUEST ───')
      ..writeln('$method $url')
      ..writeln('')
      ..writeln('Headers:')
      ..writeln(_prettyMap(headers))
      ..writeln('')
      ..writeln('Body:')
      ..writeln(_prettyJson(body, redactPassword: true));

    if (statusCode != null || responseBody != null) {
      buffer
        ..writeln('')
        ..writeln('─── LOGIN RESPONSE ───')
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

  static String _prettyJson(Object value, {bool redactPassword = false}) {
    try {
      final dynamic decoded = value is String ? jsonDecode(value) : value;
      if (decoded is Map<String, dynamic> && redactPassword) {
        final copy = Map<String, dynamic>.from(decoded);
        if (copy.containsKey('password')) {
          copy['password'] = '***';
        }
        return const JsonEncoder.withIndent('  ').convert(copy);
      }
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value.toString();
    }
  }
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<({
    LoginResponse user,
    Map<String, dynamic> raw,
    LoginDebugSnapshot debug,
  })> login({
    required String username,
    required String password,
    String? deviceId,
  }) async {
    final trimmedDeviceId = deviceId?.trim();
    final hasDeviceId =
        trimmedDeviceId != null && trimmedDeviceId.isNotEmpty;

    final requestBody = <String, dynamic>{
      'username': username,
      'password': password,
      'deviceId': hasDeviceId ? trimmedDeviceId : null,
    };
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': hasDeviceId ? trimmedDeviceId : 'null',
    };

    LoginDebugSnapshot debugSnapshot = LoginDebugSnapshot(
      url: ApiConfig.login,
      method: 'POST',
      headers: requestHeaders,
      body: requestBody,
    );

    _debugLog(debugSnapshot.format());

    try {
      final response = await _client
          .post(
            ApiConfig.login,
            headers: requestHeaders,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      debugSnapshot = LoginDebugSnapshot(
        url: ApiConfig.login,
        method: 'POST',
        headers: requestHeaders,
        body: requestBody,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      _debugLog(debugSnapshot.format());

      final responseBody = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _readErrorMessage(responseBody) ?? 'Login failed. Please try again.',
          debug: debugSnapshot,
        );
      }

      if (responseBody['status'] != true) {
        throw AuthException(
          _readErrorMessage(responseBody) ?? 'Login failed. Please try again.',
          debug: debugSnapshot,
        );
      }

      final token = responseBody['token'] as String?;
      if (token == null || token.trim().isEmpty) {
        throw AuthException(
          'Login failed: no token received.',
          debug: debugSnapshot,
        );
      }

      return (
        user: LoginResponse.fromJson(responseBody),
        raw: responseBody,
        debug: debugSnapshot,
      );
    } on TimeoutException {
      debugSnapshot = LoginDebugSnapshot(
        url: ApiConfig.login,
        method: 'POST',
        headers: requestHeaders,
        body: requestBody,
        error: 'Request timed out',
      );
      _debugLog(debugSnapshot.format());
      throw AuthException(
        'Request timed out. Please try again.',
        debug: debugSnapshot,
      );
    } on http.ClientException catch (error) {
      debugSnapshot = LoginDebugSnapshot(
        url: ApiConfig.login,
        method: 'POST',
        headers: requestHeaders,
        body: requestBody,
        error: error.message,
      );
      _debugLog(debugSnapshot.format());
      throw AuthException(
        'Unable to reach ${ApiConfig.login}. '
        'Check that the API is running, the device is on the same network, '
        'and [ApiConfig.baseUrl] matches your setup '
        '(use androidEmulatorBaseUrl for Android emulator). '
        'Details: ${error.message}',
        debug: debugSnapshot,
      );
    } on FormatException catch (error) {
      debugSnapshot = LoginDebugSnapshot(
        url: ApiConfig.login,
        method: 'POST',
        headers: requestHeaders,
        body: requestBody,
        error: 'Invalid JSON: $error',
      );
      _debugLog(debugSnapshot.format());
      throw AuthException(
        'Invalid server response.',
        debug: debugSnapshot,
      );
    } on AuthException {
      rethrow;
    }
  }

  static void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('──────── LOGIN API ────────');
    debugPrint(message);
    debugPrint('───────────────────────────');
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException('Expected JSON object');
  }

  String? _readErrorMessage(Map<String, dynamic> body) {
    if (body['status'] == false) {
      final detail = body['message'] ?? body['error'] ?? body['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }
      return 'Invalid username or password.';
    }

    final message = body['message'] ?? body['error'];
    return message?.toString();
  }

  void close() {
    _client.close();
  }
}
