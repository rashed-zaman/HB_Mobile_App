class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://68.183.181.148';

  static Uri endpoint(String path) => Uri.parse('$baseUrl$path');

  static final Uri login = endpoint('/api/mobile/auth/login');
  static final Uri posSignIn = endpoint('/api/mobile/pos/signin');

  /// GET `/api/mobile/inventory/items?page=&size=&search=`
  static Uri inventoryItems({
    required int page,
    required int size,
    String search = '',
  }) {
    return Uri.parse('$baseUrl/api/mobile/inventory/items').replace(
      queryParameters: <String, String>{
        'page': '$page',
        'size': '$size',
        'search': search,
      },
    );
  }
}
