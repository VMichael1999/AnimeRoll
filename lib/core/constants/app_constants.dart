class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'ANIME_API_BASE_URL',
    defaultValue: 'https://animea1v-api-production.up.railway.app/api/v1',
  );
  static const String apiKey = String.fromEnvironment(
    'ANIME_API_KEY',
    defaultValue: 'dev-anime1v-key',
  );
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  // Providers
  static const List<String> providers = [
    'animeflv.net',
    'animeav1.com',
    'tioanime.com',
    'jkanime.net',
    'monoschinos2.net',
    'hentaila.com',
  ];

  // Quality options
  static const List<String> qualities = ['480p', '720p', '1080p'];

  // Variants
  static const List<String> variants = ['SUB', 'DUB'];
}
