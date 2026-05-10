class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://68.183.181.148';

  static Uri endpoint(String path) => Uri.parse('$baseUrl$path');

  static final Uri login = endpoint('/api/mobile/auth/login');
}
