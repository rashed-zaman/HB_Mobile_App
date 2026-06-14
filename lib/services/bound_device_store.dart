import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/bound_device_data.dart';

const _channel = MethodChannel('com.example.hb_sales/device_id');

BoundDeviceData? _memoryBoundDevice;

/// Persists bound device data on the handset (survives logout).
Future<BoundDeviceData?> getBoundDeviceData() async {
  if (_memoryBoundDevice != null) {
    return _memoryBoundDevice;
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final raw = await _channel.invokeMethod<String>('getBoundDeviceData');
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _memoryBoundDevice = BoundDeviceData.fromJson(decoded);
          return _memoryBoundDevice;
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

/// Device UUID saved from Settings → Set Device Id (bind). Null if not bound yet.
Future<String?> getSavedDeviceIdForLogin() async {
  final bound = await getBoundDeviceData();
  if (bound != null && bound.isSaved) {
    return bound.deviceUuid.trim();
  }
  return null;
}

Future<void> clearBoundDeviceData() async {
  _memoryBoundDevice = null;

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await _channel.invokeMethod<void>('clearBoundDeviceData');
    } on PlatformException {
      // Ignore.
    } on MissingPluginException {
      // Ignore.
    }
  }
}

Future<void> saveBoundDeviceData(BoundDeviceData data) async {
  _memoryBoundDevice = data;
  final encoded = jsonEncode(data.toJson());

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await _channel.invokeMethod<void>('setBoundDeviceData', encoded);
    } on PlatformException {
      // Memory cache still updated.
    } on MissingPluginException {
      // Memory cache still updated.
    }
  }
}
