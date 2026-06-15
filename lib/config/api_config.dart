class ApiConfig {
  ApiConfig._();

  /// API server on the LAN (e.g. machine at 192.168.7.72).
  static const String lanBaseUrl = 'http://192.168.7.72:8081';

  /// Only when API runs on the **same PC** as the Android emulator (not a remote server).
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:8081';

  /// API is on another machine (192.168.7.72); app runs from 192.168.7.76 — use LAN IP.
  static const String baseUrl = lanBaseUrl;

  static Uri endpoint(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }

  /// Login `paymentMethods.providers[].imageUrl` → full URL for [Image.network].
  ///
  /// Example: `/uploads/payment-method-images/abc.jpg`
  /// → `http://192.168.7.72:8081/uploads/payment-method-images/abc.jpg`
  static String? resolveImageUrl(String? imageUrl) {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return endpoint(raw).toString();
  }

  static final Uri login = endpoint('/api/mobile/auth/login');
  static final Uri posSignIn = endpoint('/api/mobile/pos/signin');
  static final Uri deviceBind = endpoint('/api/mobile/pos/devices/bind');
  static final Uri deviceUnbind = endpoint('/api/mobile/pos/devices/unbind');

  /// GET `/api/mobile/inventory/items?page=&size=&search=`
  static Uri inventoryItems({
    required int page,
    required int size,
    String search = '',
  }) {
    return endpoint('/api/mobile/inventory/items').replace(
      queryParameters: <String, String>{
        'page': '$page',
        'size': '$size',
        'search': search,
      },
    );
  }
}
