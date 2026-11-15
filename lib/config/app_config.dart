abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sipp.tik.ung.ac.id/api/v1',
  );
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration uploadTimeout = Duration(minutes: 3);
  static const int perPage = 20;
  static const String appName = 'SIPP';
  static const String appFullName = 'Sistem Informasi Pendataan Perangkat';
  static const String institution = 'Universitas Negeri Gorontalo';
  static const String appVersion = '1.0.0'; // keep in sync with pubspec
}
