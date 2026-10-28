class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'QUAKELINK_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  static String get wsBaseUrl {
    return apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }
}
