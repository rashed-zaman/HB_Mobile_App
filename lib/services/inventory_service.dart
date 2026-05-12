import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/product.dart';
import 'auth_session.dart';

class InventoryException implements Exception {
  const InventoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InventoryPageResult {
  const InventoryPageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.last,
    required this.totalPages,
  });

  final List<Product> items;
  final int page;
  final int size;
  final bool last;
  final int totalPages;
}

class InventoryService {
  InventoryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<InventoryPageResult> fetchItems({
    required int page,
    required int size,
    String search = '',
  }) async {
    final uri = ApiConfig.inventoryItems(page: page, size: size, search: search);

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
        throw InventoryException(
          err ??
              'Could not load products (${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(body);
      return _parsePage(decoded);
    } on TimeoutException {
      throw const InventoryException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      debugPrint('Inventory API connection error: ${e.message}');
      throw InventoryException('Unable to connect: ${e.message}');
    } on FormatException {
      throw const InventoryException('Invalid server response.');
    }
  }

  InventoryPageResult _parsePage(dynamic decoded) {
    if (decoded is List) {
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(Product.fromInventoryJson)
          .toList();
      return InventoryPageResult(
        items: items,
        page: 0,
        size: items.length,
        last: true,
        totalPages: 1,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const InventoryException('Unexpected response format.');
    }

    final root = decoded;

    if (root['status'] == false) {
      final msg =
          root['message']?.toString() ?? 'Could not load products.';
      throw InventoryException(msg);
    }

    // Supports `{ "data": { "content": [...], "last": true } }` (your API shape)
    // and flat `{ "content": [...] }` Spring pages.
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
    } else if (root['items'] is List) {
      rawList = root['items'] as List<dynamic>;
    } else if (root['results'] is List) {
      rawList = root['results'] as List<dynamic>;
    }

    rawList ??= const [];

    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(Product.fromInventoryJson)
        .toList();

    final page = _readInt(pageMap, const ['number', 'page']) ?? 0;
    final size = _readInt(pageMap, const ['size', 'pageSize']) ?? items.length;
    final totalPages = _readInt(pageMap, const ['totalPages']) ?? 1;

    bool last;
    if (pageMap['last'] is bool) {
      last = pageMap['last'] as bool;
    } else if (root['last'] is bool) {
      last = root['last'] as bool;
    } else if (pageMap['isLast'] is bool) {
      last = pageMap['isLast'] as bool;
    } else if (root['isLast'] is bool) {
      last = root['isLast'] as bool;
    } else {
      last = page >= totalPages - 1;
    }

    return InventoryPageResult(
      items: items,
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
