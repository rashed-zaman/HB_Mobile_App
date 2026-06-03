import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_session.dart';

class PosShiftException implements Exception {
  const PosShiftException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PosShiftSignInResult {
  const PosShiftSignInResult({
    required this.status,
    this.message,
    this.raw,
  });

  final bool status;
  final String? message;
  final Map<String, dynamic>? raw;
}

class PosShiftService {
  PosShiftService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PosShiftSignInResult> signIn({
    required int employeeId,
    required String terminalCode,
    required String deviceUuid,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': deviceUuid,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    try {
      final response = await _client
          .post(
            ApiConfig.posSignIn,
            headers: headers,
            body: jsonEncode({
              'employeeId': employeeId,
              'terminalCode': terminalCode,
              'deviceUuid': deviceUuid,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosShiftException(
          _readErrorMessage(decoded) ?? 'Sign in failed. Please try again.',
        );
      }

      final status = decoded['status'] == true;
      final message = decoded['message']?.toString();
      return PosShiftSignInResult(
        status: status,
        message: message,
        raw: decoded,
      );
    } on TimeoutException {
      throw const PosShiftException('Request timed out. Please try again.');
    } on http.ClientException catch (error) {
      debugPrint('POS sign-in API connection error: ${error.message}');
      throw PosShiftException('Unable to connect to the server: ${error.message}');
    } on FormatException {
      throw const PosShiftException('Invalid server response.');
    }
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
