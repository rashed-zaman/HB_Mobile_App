import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/customer.dart';
import 'auth_session.dart';

class CustomerException implements Exception {
  const CustomerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomerPageResult {
  const CustomerPageResult({
    required this.customers,
    required this.page,
    required this.size,
    required this.last,
    required this.totalPages,
  });

  final List<Customer> customers;
  final int page;
  final int size;
  final bool last;
  final int totalPages;
}

class CustomerService {
  CustomerService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<CustomerPageResult> fetchCustomers({
    required int page,
    required int size,
    String search = '',
    String? customerType,
  }) async {
    final uri = ApiConfig.stakeholdersCustomer(
      page: page,
      size: size,
      search: search,
      customerType: customerType,
    );

    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final auth = AuthSession.authorizationHeader;
    if (auth != null) {
      headers['Authorization'] = auth;
    }

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      final body = response.body;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = _tryParseError(body);
        throw CustomerException(
          err ?? 'Could not load customers (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(body);
      return _parsePage(decoded);
    } on TimeoutException {
      throw const CustomerException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      debugPrint('Customer API connection error: ${e.message}');
      throw CustomerException('Unable to connect: ${e.message}');
    } on FormatException {
      throw const CustomerException('Invalid server response.');
    }
  }

  CustomerPageResult _parsePage(dynamic decoded) {
    if (decoded is List) {
      final customers = decoded
          .whereType<Map<String, dynamic>>()
          .map(Customer.fromStakeholderJson)
          .toList();
      return CustomerPageResult(
        customers: customers,
        page: 0,
        size: customers.length,
        last: true,
        totalPages: 1,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CustomerException('Unexpected response format.');
    }

    final root = decoded;

    if (root['status'] == false || root['success'] == false) {
      final msg = root['message']?.toString() ?? 'Could not load customers.';
      throw CustomerException(msg);
    }

    Map<String, dynamic> pageMap = root;
    if (root['data'] is Map<String, dynamic>) {
      pageMap = root['data'] as Map<String, dynamic>;
    }

    List<dynamic>? rawList;
    if (pageMap['content'] is List) {
      rawList = pageMap['content'] as List<dynamic>;
    } else if (root['content'] is List) {
      rawList = root['content'] as List<dynamic>;
    } else if (root['data'] is List) {
      rawList = root['data'] as List<dynamic>;
    } else if (pageMap['items'] is List) {
      rawList = pageMap['items'] as List<dynamic>;
    }

    rawList ??= const [];

    final customers = rawList
        .whereType<Map<String, dynamic>>()
        .map(Customer.fromStakeholderJson)
        .where((c) => c.name.isNotEmpty)
        .toList();

    final page = _readInt(pageMap, const ['number', 'page']) ?? 0;
    final size =
        _readInt(pageMap, const ['size', 'pageSize']) ?? customers.length;
    final totalPages = _readInt(pageMap, const ['totalPages']) ?? 1;

    bool last;
    if (pageMap['last'] is bool) {
      last = pageMap['last'] as bool;
    } else if (root['last'] is bool) {
      last = root['last'] as bool;
    } else {
      last = page >= totalPages - 1;
    }

    return CustomerPageResult(
      customers: customers,
      page: page,
      size: size,
      last: last,
      totalPages: totalPages,
    );
  }

  String? _tryParseError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
        return m?.toString();
      }
    } catch (_) {}
    return null;
  }

  void close() {
    _client.close();
  }
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    if (v is int) return v;
    if (v is double) return v.round();
    final p = int.tryParse(v.toString());
    if (p != null) return p;
  }
  return null;
}
