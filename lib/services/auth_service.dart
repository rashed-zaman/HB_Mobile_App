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
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LoginResponse> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      final response = await _client
          .post(
            ApiConfig.login,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Device-Id': deviceId,
            },
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      final responseBody = _decodeResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _readErrorMessage(responseBody) ?? 'Login failed. Please try again.',
        );
      }

      return LoginResponse.fromJson(responseBody);
    } on TimeoutException {
      throw const AuthException('Request timed out. Please try again.');
    } on http.ClientException catch (error) {
      debugPrint('Login API connection error: ${error.message}');
      throw AuthException('Unable to connect to the server: ${error.message}');
    } on FormatException {
      throw const AuthException('Invalid server response.');
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException('Expected JSON object');
  }

  String? _readErrorMessage(Map<String, dynamic> body) {
    final message = body['message'] ?? body['error'];
    return message?.toString();
  }

  void close() {
    _client.close();
  }
}
