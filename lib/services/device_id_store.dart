import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.hb_sales/device_id');

String? _memoryCache;

/// Stable per-install identifier used as `device_id` (e.g. for `X-Device-Id`).
Future<String> getOrCreateDeviceId() async {
  if (_memoryCache != null && _memoryCache!.isNotEmpty) {
    return _memoryCache!;
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      final id = await _channel.invokeMethod<String>('getOrCreateDeviceId');
      if (id != null && id.isNotEmpty) {
        _memoryCache = id;
        return id;
      }
    } on PlatformException {
      // Fall through to generated id.
    } on MissingPluginException {
      // Fall through to generated id.
    }
  }

  _memoryCache = _generateLocalId();
  return _memoryCache!;
}

String _generateLocalId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final r = DateTime.now().hashCode;
  return 'local-$now-$r';
}
