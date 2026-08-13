class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static String resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final root = baseUrl.replaceFirst(RegExp(r'/api$'), '');
    return '$root/${path.replaceFirst(RegExp(r'^/'), '')}';
  }
}
