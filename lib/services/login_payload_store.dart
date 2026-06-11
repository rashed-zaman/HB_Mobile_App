import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.hb_sales/device_id');

Map<String, dynamic>? _memoryLoginPayload;

/// Saves the full login API response for later app operations.
Future<void> saveLoginPayload(Map<String, dynamic> payload) async {
  _memoryLoginPayload = Map<String, dynamic>.from(payload);
  final encoded = jsonEncode(_memoryLoginPayload);

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await _channel.invokeMethod<void>('setLoginPayload', encoded);
    } on PlatformException {
      // Memory cache still updated.
    } on MissingPluginException {
      // Memory cache still updated.
    }
  }
}

/// Returns the last saved login API response, or null if none stored.
Future<Map<String, dynamic>?> getStoredLoginPayload() async {
  if (_memoryLoginPayload != null) {
    return Map<String, dynamic>.from(_memoryLoginPayload!);
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final raw = await _channel.invokeMethod<String>('getLoginPayload');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _memoryLoginPayload = decoded;
          return Map<String, dynamic>.from(decoded);
        }
      }
    } on PlatformException {
      // Fall through.
    } on MissingPluginException {
      // Fall through.
    }
  }

  return null;
}

Future<void> clearLoginPayload() async {
  _memoryLoginPayload = null;

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await _channel.invokeMethod<void>('clearLoginPayload');
    } on PlatformException {
      // Ignore.
    } on MissingPluginException {
      // Ignore.
    }
  }
}
