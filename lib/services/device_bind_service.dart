import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/bound_device_data.dart';
import 'auth_session.dart';

class DeviceBindException implements Exception {
  const DeviceBindException(this.message, {this.debug});

  final String message;
  final DeviceBindDebugSnapshot? debug;

  @override
  String toString() => message;
}

/// Request/response details for device bind debug (debug builds only).
class DeviceBindDebugSnapshot {
  const DeviceBindDebugSnapshot({
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
      ..writeln('─── DEVICE BIND REQUEST ───')
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
        ..writeln('─── DEVICE BIND RESPONSE ───')
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

class DeviceBindService {
  DeviceBindService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<({BoundDeviceData data, DeviceBindDebugSnapshot debug})> bind({
    required String deviceUuid,
  }) async {
    final trimmed = deviceUuid.trim();
    if (trimmed.isEmpty) {
      throw const DeviceBindException('Device Id is required.');
    }

    final requestBody = <String, dynamic>{'deviceUuid': trimmed};
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': trimmed,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    DeviceBindDebugSnapshot debugSnapshot = DeviceBindDebugSnapshot(
      url: ApiConfig.deviceBind,
      method: 'POST',
      headers: headers,
      body: requestBody,
    );

    _debugLog(debugSnapshot.format());

    try {
      final response = await _client
          .post(
            ApiConfig.deviceBind,
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      debugSnapshot = DeviceBindDebugSnapshot(
        url: ApiConfig.deviceBind,
        method: 'POST',
        headers: headers,
        body: requestBody,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
      _debugLog(debugSnapshot.format());

      final body = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DeviceBindException(
          _readErrorMessage(body) ?? 'Device bind failed. Please try again.',
          debug: debugSnapshot,
        );
      }

      if (body['status'] != true) {
        throw DeviceBindException(
          _readErrorMessage(body) ?? 'Device bind failed. Please try again.',
          debug: debugSnapshot,
        );
      }

      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw DeviceBindException(
          'Invalid bind response from server.',
          debug: debugSnapshot,
        );
      }

      return (
        data: BoundDeviceData.fromJson(data),
        debug: debugSnapshot,
      );
    } on TimeoutException {
      debugSnapshot = DeviceBindDebugSnapshot(
        url: ApiConfig.deviceBind,
        method: 'POST',
        headers: headers,
        body: requestBody,
        error: 'Request timed out',
      );
      _debugLog(debugSnapshot.format());
      throw DeviceBindException(
        'Request timed out. Please try again.',
        debug: debugSnapshot,
      );
    } on http.ClientException catch (error) {
      debugSnapshot = DeviceBindDebugSnapshot(
        url: ApiConfig.deviceBind,
        method: 'POST',
        headers: headers,
        body: requestBody,
        error: error.message,
      );
      _debugLog(debugSnapshot.format());
      throw DeviceBindException(
        'Unable to connect to the server: ${error.message}',
        debug: debugSnapshot,
      );
    } on FormatException catch (error) {
      debugSnapshot = DeviceBindDebugSnapshot(
        url: ApiConfig.deviceBind,
        method: 'POST',
        headers: headers,
        body: requestBody,
        error: 'Invalid JSON: $error',
      );
      _debugLog(debugSnapshot.format());
      throw DeviceBindException(
        'Invalid server response.',
        debug: debugSnapshot,
      );
    } on DeviceBindException {
      rethrow;
    }
  }

  static void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('──────── DEVICE BIND API ────────');
    debugPrint(message);
    debugPrint('──────────────────────────────────');
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Expected JSON object');
  }

  String? _readErrorMessage(Map<String, dynamic> body) {
    final message = body['message'] ?? body['error'] ?? body['detail'];
    return message?.toString();
  }

  Future<String> unbind({required String deviceUuid}) async {
    final trimmed = deviceUuid.trim();
    if (trimmed.isEmpty) {
      throw const DeviceBindException('Device Id is required.');
    }

    final requestBody = <String, dynamic>{'deviceUuid': trimmed};
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': trimmed,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    try {
      final response = await _client
          .post(
            ApiConfig.deviceUnbind,
            headers: headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      final body = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DeviceBindException(
          _readErrorMessage(body) ?? 'Device unbind failed. Please try again.',
        );
      }

      if (body['status'] != true) {
        throw DeviceBindException(
          _readErrorMessage(body) ?? 'Device unbind failed. Please try again.',
        );
      }

      final message = body['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      return 'Device Id removed successfully.';
    } on TimeoutException {
      throw const DeviceBindException('Request timed out. Please try again.');
    } on http.ClientException catch (error) {
      throw DeviceBindException(
        'Unable to connect to the server: ${error.message}',
      );
    } on FormatException {
      throw const DeviceBindException('Invalid server response.');
    } on DeviceBindException {
      rethrow;
    }
  }

  void close() {
    _client.close();
  }
}
