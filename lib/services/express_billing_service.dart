import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_session.dart';
import 'bound_device_store.dart';
export 'pos_sign_in_helper.dart' show resolvePosTerminalCode;

class ExpressBillingException implements Exception {
  const ExpressBillingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExpressBillingService {
  ExpressBillingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> saveAndPrint({
    required Map<String, dynamic> body,
    required String terminalCode,
    String? deviceUuid,
  }) async {
    final trimmedTerminal = terminalCode.trim();
    if (trimmedTerminal.isEmpty) {
      throw const ExpressBillingException('POS terminal code is required.');
    }

    var deviceId = deviceUuid?.trim();
    deviceId ??= AuthSession.deviceUuid?.trim();
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = await getSavedDeviceIdForLogin();
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Pos-Terminal-Code': trimmedTerminal,
      if (deviceId != null && deviceId.isNotEmpty) 'X-Device-Id': deviceId,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    try {
      final response = await _client
          .post(
            ApiConfig.expressSavePrint,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

      final decoded = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ExpressBillingException(
          _readErrorMessage(decoded) ?? 'Save & print failed (${response.statusCode}).',
        );
      }

      if (decoded['status'] != true) {
        throw ExpressBillingException(
          _readErrorMessage(decoded) ?? 'Save & print failed.',
        );
      }

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return decoded;
    } on TimeoutException {
      throw const ExpressBillingException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw ExpressBillingException(
        'Unable to reach server: ${e.message}',
      );
    } on FormatException {
      throw const ExpressBillingException('Invalid server response.');
    } on ExpressBillingException {
      rethrow;
    }
  }

  void close() {
    _client.close();
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object');
  }

  String? _readErrorMessage(Map<String, dynamic> body) {
    final message = body['message'] ?? body['error'] ?? body['detail'];
    return message?.toString().trim();
  }
}
