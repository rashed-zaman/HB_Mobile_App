import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/pos_settlement_dto.dart';
import 'auth_session.dart';
import 'bound_device_store.dart';
import 'pos_sign_in_helper.dart' show resolvePosTerminalCode;
import 'pos_shift_service.dart' show PosShiftStatus;

class PosSettlementException implements Exception {
  const PosSettlementException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Result after submitting a settlement. The backend returns a signin-status
/// snapshot; we extract the settlement id from it so the caller can fetch
/// the full slip.
class PosSettlementSubmitResult {
  const PosSettlementSubmitResult({
    required this.settlementId,
    required this.pendingSettlement,
    this.shiftStatus,
  });

  final int settlementId;
  final bool pendingSettlement;
  final PosShiftStatus? shiftStatus;
}

class PosSettlementService {
  PosSettlementService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Submits a settlement for the current shift.
  /// Returns the new settlement id on success.
  Future<PosSettlementSubmitResult> submitSettlement() async {
    final terminalCode = await resolvePosTerminalCode();
    if (terminalCode == null || terminalCode.isEmpty) {
      throw const PosSettlementException(
          'No terminal found. Please sign in first.');
    }
    final employeeId = AuthSession.employeeId;
    if (employeeId == null) {
      throw const PosSettlementException(
          'No employee linked to this session.');
    }

    final headers = await _buildHeaders(terminalCode: terminalCode);
    final body = jsonEncode({
      'employeeId': employeeId,
      'terminalCode': terminalCode,
    });

    _debugLog('POST ${ApiConfig.posSettlementSubmit}');

    try {
      final response = await _client
          .post(ApiConfig.posSettlementSubmit, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      final decoded = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosSettlementException(
            _errorMessage(decoded) ?? 'Settlement submit failed.');
      }
      if (decoded['status'] != true) {
        throw PosSettlementException(
            _errorMessage(decoded) ?? 'Settlement submit failed.');
      }

      final data = decoded['data'] as Map<String, dynamic>?;
      final rawId = data?['settlementId'] as num?;
      if (rawId == null) {
        throw const PosSettlementException(
            'Server did not return a settlement id.');
      }
      return PosSettlementSubmitResult(
        settlementId: rawId.toInt(),
        pendingSettlement: data?['pendingSettlement'] as bool? ?? true,
        shiftStatus: data != null ? PosShiftStatus.fromApiData(data) : null,
      );
    } on TimeoutException {
      throw const PosSettlementException(
          'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw PosSettlementException('Cannot reach server: ${e.message}');
    } on PosSettlementException {
      rethrow;
    }
  }

  /// Fetches the full settlement slip for a given id.
  Future<PosSettlementDto> getSettlementById(int id) async {
    final terminalCode = await resolvePosTerminalCode();
    final headers = await _buildHeaders(terminalCode: terminalCode);
    final url = ApiConfig.posSettlementById(id);

    _debugLog('GET $url');

    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      final decoded = _decodeObject(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PosSettlementException(
            _errorMessage(decoded) ?? 'Could not fetch settlement.');
      }
      if (decoded['status'] != true) {
        throw PosSettlementException(
            _errorMessage(decoded) ?? 'Could not fetch settlement.');
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const PosSettlementException(
            'Unexpected settlement response format.');
      }
      return PosSettlementDto.fromJson(data);
    } on TimeoutException {
      throw const PosSettlementException(
          'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw PosSettlementException('Cannot reach server: ${e.message}');
    } on PosSettlementException {
      rethrow;
    }
  }

  /// Fetches the pending settlement for the current shift, if any.
  Future<PosSettlementDto?> getCurrentSettlement() async {
    final terminalCode = await resolvePosTerminalCode();
    if (terminalCode == null || terminalCode.isEmpty) return null;

    final headers = await _buildHeaders(terminalCode: terminalCode);
    final url = ApiConfig.posSettlementCurrent(terminalCode: terminalCode);

    _debugLog('GET $url');

    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) return null;

      final decoded = _decodeObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      if (decoded['status'] != true) return null;

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;
      return PosSettlementDto.fromJson(data);
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  Future<Map<String, String>> _buildHeaders({String? terminalCode}) async {
    final deviceUuid = AuthSession.deviceUuid?.trim() ??
        await _resolveDeviceUuid();

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (AuthSession.authorizationHeader != null)
        'Authorization': AuthSession.authorizationHeader!,
      if (deviceUuid != null && deviceUuid.isNotEmpty)
        'X-Device-Id': deviceUuid,
      if (terminalCode != null && terminalCode.isNotEmpty)
        'X-Pos-Terminal-Code': terminalCode,
    };
  }

  Future<String?> _resolveDeviceUuid() async {
    try {
      final bound = await getBoundDeviceData();
      return bound?.deviceUuid.trim();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Expected JSON object');
  }

  String? _errorMessage(Map<String, dynamic> body) {
    final msg = body['message'] ?? body['error'] ?? body['detail'];
    return msg?.toString().trim();
  }

  static void _debugLog(String message) {
    if (!kDebugMode) return;
    debugPrint('──────── SETTLEMENT API ────────');
    debugPrint(message);
    debugPrint('────────────────────────────────');
  }

  void close() => _client.close();
}
