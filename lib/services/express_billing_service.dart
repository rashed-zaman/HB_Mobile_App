import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_session.dart';
import 'bound_device_store.dart';
import 'pos_sign_in_helper.dart' show resolvePosTerminalCode;

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

  Future<String?> peekNextBillNumber({
    required String terminalCode,
    int? storeId,
    DateTime? saleDate,
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
      'X-Pos-Terminal-Code': trimmedTerminal,
      if (deviceId != null && deviceId.isNotEmpty) 'X-Device-Id': deviceId,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    final effectiveDate = saleDate ?? DateTime.now();
    final saleDateParam =
        '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}';

    try {
      final response = await _client
          .get(
            ApiConfig.expressNextDocumentNumbers(
              saleDate: saleDateParam,
              terminalCode: trimmedTerminal,
              storeId: storeId,
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      final decoded = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ExpressBillingException(
          _readErrorMessage(decoded) ??
              'Failed to load bill number (${response.statusCode}).',
        );
      }

      if (decoded['status'] != true) {
        throw ExpressBillingException(
          _readErrorMessage(decoded) ?? 'Failed to load bill number.',
        );
      }

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final billNo = data['billNo']?.toString().trim();
        if (billNo != null && billNo.isNotEmpty) {
          return billNo;
        }
      }
      return null;
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

  Future<Map<String, dynamic>> searchBill({
    required String invoiceNumber,
    required int employeeId,
    String? terminalCode,
    String? deviceUuid,
  }) async {
    final trimmed = invoiceNumber.trim();
    if (trimmed.isEmpty) {
      throw const ExpressBillingException('Invoice number is required.');
    }
    if (employeeId <= 0) {
      throw const ExpressBillingException('Employee is not linked to this session.');
    }

    final resolvedTerminal = terminalCode?.trim();
    final terminal = (resolvedTerminal != null && resolvedTerminal.isNotEmpty)
        ? resolvedTerminal
        : await resolvePosTerminalCode();

    var deviceId = deviceUuid?.trim();
    deviceId ??= AuthSession.deviceUuid?.trim();
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = await getSavedDeviceIdForLogin();
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (terminal != null && terminal.isNotEmpty) 'X-Pos-Terminal-Code': terminal,
      if (deviceId != null && deviceId.isNotEmpty) 'X-Device-Id': deviceId,
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    final body = jsonEncode({
      'invoiceNumber': trimmed,
      'employeeId': employeeId,
      'billType': 'EXPRESS',
    });

    try {
      final response = await _client
          .post(ApiConfig.expressBillSearch, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      final decoded = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ExpressBillingException(
          _readErrorMessage(decoded) ??
              'Bill search failed (${response.statusCode}).',
        );
      }

      if (decoded['status'] != true) {
        throw ExpressBillingException(
          _readErrorMessage(decoded) ?? 'Bill search failed.',
        );
      }

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw const ExpressBillingException('Unexpected bill search response.');
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
