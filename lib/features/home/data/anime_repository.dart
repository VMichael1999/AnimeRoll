import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/available_filters.dart';
import '../../../shared/models/catalog_page.dart';
import '../../../shared/models/cinehax_hub.dart';
import '../../../shared/models/download_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/models/monoschinos_hub.dart';
import '../../../shared/models/schedule_anime_model.dart';

class AnimeRepository {
  final Dio _dio;

  AnimeRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  static const List<String> imageFirstDomains = [
    'animeav1.com',
    'monoschinos2.net',
    'tioanime.com',
    'jkanime.net',
    'animeflv.net',
  ];

  static const Map<String, String> providerProbeQueries = {'hentaila.com': 'a'};

  Future<List<AnimeModel>> search(String query, {String? domain}) async {
    final response = await _dio.get(
      '/anime/search',
      queryParameters: {'q': query, 'domain': domain}
        ..removeWhere((_, v) => v == null),
    );
    final data = _responseData(response);
    final results = data['results'];
    final List items = results is List ? results : const [];
    return items
        .map((e) => AnimeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MoodAnimeResult>> moodSearch(
    String query, {
    String? domain,
  }) async {
    final response = await _dio.get(
      '/anime/mood-search',
      queryParameters: {'q': query, 'domain': domain, 'limit': 12}
        ..removeWhere((_, v) => v == null || v == ''),
    );
    final data = _responseData(response);
    final results = data['results'];
    final List items = results is List ? results : const [];
    return items
        .map((e) => MoodAnimeResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AiRecapResult> recapEpisode({
    required String animeTitle,
    required String episodeTitle,
    required double percent,
    String? synopsis,
    int? episodeNumber,
    String detail = 'medium',
  }) async {
    final response = await _dio.post(
      '/anime/recap',
      data: {
        'animeTitle': animeTitle,
        'episodeTitle': episodeTitle,
        'percent': percent,
        'synopsis': synopsis,
        'episodeNumber': episodeNumber,
        'detail': detail,
      }..removeWhere((_, v) => v == null),
    );
    return AiRecapResult.fromJson(_responseData(response));
  }

  /// Pide al backend la lista canonica de filtros que SI funcionan en el
  /// proveedor indicado. Devuelve solo categorias con opciones, p.ej. para
  /// AnimeAV1 vienen 46 generos + 3 estados; tipos/años/orden llegan vacios
  /// porque el sitio los ignora server-side.
  Future<AvailableFilters> availableFilters({
    String domain = 'animeav1.com',
  }) async {
    final response = await _dio.get(
      '/anime/filters',
      queryParameters: {'domain': domain},
    );
    return AvailableFilters.fromJson(_responseData(response));
  }

  /// Versión "rica" del catálogo que devuelve `CatalogPage` con `results` +
  /// opcionalmente `months`. Algunos proveedores (hentaitk + año) agrupan
  /// por mes; los demás caen al flujo plano. La UI usa `isGroupedByMonth`
  /// para decidir cómo renderizar.
  Future<CatalogPage> catalogPage({
    String domain = 'animeav1.com',
    String letter = '#',
    String? type,
    String? genre,
    String? year,
    String? status,
    String? sort,
    bool uncensored = false,
    String? search,
    int limit = 40,
  }) async {
    final response = await _dio.get(
      '/anime/catalog',
      queryParameters: {
        'domain': domain,
        'letter': letter,
        'type': type,
        'genre': genre,
        'year': year,
        'status': status,
        'sort': sort,
        'uncensored': uncensored ? true : null,
        'search': search,
        'limit': limit,
      }..removeWhere((_, v) => v == null || v == ''),
    );
    return CatalogPage.fromJson(_responseData(response));
  }

  /// Wrapper de compatibilidad: devuelve solo la lista plana. Lo usan los
  /// providers que NO necesitan saber del grouping por mes.
  Future<List<AnimeModel>> catalog({
    String domain = 'animeav1.com',
    String letter = '#',
    String? type,
    String? genre,
    String? year,
    String? status,
    String? sort,
    bool uncensored = false,
    String? search,
    int limit = 40,
  }) async {
    final page = await catalogPage(
      domain: domain,
      letter: letter,
      type: type,
      genre: genre,
      year: year,
      status: status,
      sort: sort,
      uncensored: uncensored,
      search: search,
      limit: limit,
    );
    return page.results;
  }

  /// Hub de CineHax: hero + secciones (películas por género, series, top, etc.)
  /// servidas por el backend a partir de la API de TMDB.
  Future<CinehaxHubData> cinehaxHub() async {
    final response = await _dio.get(
      '/anime/hub',
      queryParameters: {'domain': 'cinehax.com'},
    );
    final data = _responseData(response);
    return CinehaxHubData.fromJson(data);
  }

  /// Catálogo paginado de CineHax (películas o series filtradas por género/orden).
  /// Devuelve `AnimeModel` plano + el total de páginas para scroll infinito.
  Future<({List<AnimeModel> items, int totalPages})> cinehaxCatalog({
    String type = 'movie',
    String? genre,
    String sort = 'popular',
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '/anime/catalog',
      queryParameters: {
        'domain': 'cinehax.com',
        'type': type,
        if (genre != null && genre.isNotEmpty) 'genre': genre,
        'sort': sort,
        'page': page,
        'limit': limit,
      },
    );
    final data = _responseData(response);
    final rawResults = data['results'];
    final List items = rawResults is List ? rawResults : const [];
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
    return (
      items: items
          .whereType<Map>()
          .map((e) => AnimeModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      totalPages: totalPages,
    );
  }

  /// Hub de MonosChinos: últimos capítulos publicados en la home del sitio.
  /// El backend scrapea la home y normaliza al shape
  /// `{ latestEpisodes: [{title, slug, url, episodeUrl, episode, poster, genre}] }`.
  Future<MonosChinosHubData> monosChinosHub() async {
    final response = await _dio.get(
      '/anime/hub',
      queryParameters: {'domain': 'monoschinos2.net'},
    );
    final data = _responseData(response);
    final rawEpisodes = data['latestEpisodes'];
    final List items = rawEpisodes is List ? rawEpisodes : const [];
    return MonosChinosHubData(
      latestEpisodes: items
          .whereType<Map>()
          .map(
            (e) => MonosChinosLatestEpisode.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  /// Hub de HentaiTK. Reusa `HentailaHubData` porque ambos comparten shape
  /// (latestEpisodes + latestMedia), pero el backend lo sirve desde su
  /// propio scraper de hentaitk.net.
  Future<HentailaHubData> hentaitkHub() async {
    final response = await _dio.get(
      '/anime/hub',
      queryParameters: {'domain': 'hentaitk.net'},
    );
    final data = _responseData(response);

    List<AnimeModel> animeList(String key) {
      final raw = data[key];
      final List items = raw is List ? raw : const [];
      return items
          .map((e) => AnimeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return HentailaHubData(
      featured: const [],
      latestMedia: animeList('latestMedia'),
      latestEpisodes: animeList('latestEpisodes'),
      genres: const [],
    );
  }

  Future<HentailaHubData> hentailaHub() async {
    final response = await _dio.get(
      '/anime/hub',
      queryParameters: {'domain': 'hentaila.com'},
    );
    final data = _responseData(response);

    List<AnimeModel> animeList(String key) {
      final raw = data[key];
      final List items = raw is List ? raw : const [];
      return items
          .map((e) => AnimeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final rawGenres = data['genres'];
    final List genreItems = rawGenres is List ? rawGenres : const [];
    final genres = genreItems
        .map((genre) {
          if (genre is Map<String, dynamic>) {
            return genre['name']?.toString();
          }
          return genre?.toString();
        })
        .whereType<String>()
        .toList();

    return HentailaHubData(
      featured: animeList('featured'),
      latestMedia: animeList('latestMedia'),
      latestEpisodes: animeList('latestEpisodes'),
      genres: genres,
    );
  }

  Future<List<ScheduleAnimeModel>> schedule({int? day}) async {
    final response = await _dio.get(
      '/anime/schedule',
      queryParameters: {'domain': 'animeav1.com', 'day': day}
        ..removeWhere((_, v) => v == null),
    );
    final data = _responseData(response);
    final results = data['results'];
    final List items = results is List ? results : const [];
    return items
        .map((e) => ScheduleAnimeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AnimeModel>> searchImageFirst(
    String query, {
    int limit = 24,
    List<String>? domains,
  }) async {
    final results = <AnimeModel>[];
    final fallbackResults = <AnimeModel>[];
    final seen = <String>{};
    final fallbackSeen = <String>{};
    final minimumUsableResults = limit < 12 ? limit : 12;
    final searchDomains = _orderedImageDomains(domains ?? imageFirstDomains);

    for (final domain in searchDomains) {
      try {
        final items = await search(query, domain: domain);
        for (final item in items) {
          if (item.url.isEmpty) {
            continue;
          }
          if (item.cover == null) {
            if (fallbackSeen.add(item.url)) fallbackResults.add(item);
          } else if (seen.add(item.url)) {
            results.add(item);
            if (results.length >= limit) return results;
          }
        }
        if (results.length >= minimumUsableResults) return results;
      } catch (_) {
        continue;
      }
    }

    if (results.isNotEmpty) return results;

    try {
      final fallbackItems = await search(query);
      for (final item in fallbackItems) {
        if (item.url.isEmpty || !seen.add(item.url)) {
          continue;
        }
        results.add(item);
        if (results.length >= limit) return results;
      }
    } catch (_) {
      // Keep the image-first behavior best-effort; callers already handle empty lists.
    }

    if (results.isNotEmpty) return results;
    if (fallbackResults.isNotEmpty) {
      return fallbackResults.take(limit).toList();
    }

    return results;
  }

  Future<List<String>> availableProviders(List<String> providers) async {
    final serverEnabled = await serverEnabledProviders();
    final candidates = serverEnabled == null
        ? providers
        : providers.where(serverEnabled.contains).toList();
    final trustedServerEnabled = serverEnabled == null
        ? const <String>{}
        : const <String>{'cinehax.com'};
    final available = <String>[];
    await Future.wait(
      candidates.map((domain) async {
        if (trustedServerEnabled.contains(domain)) {
          available.add(domain);
          return;
        }
        if (await isProviderAvailable(domain)) {
          available.add(domain);
        }
      }),
    );
    available.sort(
      (a, b) => providers.indexOf(a).compareTo(providers.indexOf(b)),
    );
    if (available.isNotEmpty) return available;
    return serverEnabled == null ? providers : candidates;
  }

  List<String> _orderedImageDomains(List<String> domains) {
    final available = domains.toSet();
    return [
      ...imageFirstDomains.where(available.contains),
      ...domains.where((domain) => !imageFirstDomains.contains(domain)),
    ];
  }

  Future<List<String>?> serverEnabledProviders() async {
    try {
      final response = await _dio.get('/anime/providers');
      final data = _responseData(response);
      final enabled = data['enabled'];
      if (enabled is List) {
        return enabled.map((item) => item.toString()).toList();
      }

      final providers = data['providers'];
      if (providers is List) {
        return providers
            .whereType<Map>()
            .where((item) => item['enabled'] == true)
            .map((item) => item['domain']?.toString())
            .whereType<String>()
            .toList();
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<bool> isProviderAvailable(String domain) async {
    try {
      if (domain == 'hentaila.com') {
        final hub = await hentailaHub();
        return hub.featured.isNotEmpty ||
            hub.latestMedia.isNotEmpty ||
            hub.latestEpisodes.isNotEmpty ||
            hub.genres.isNotEmpty;
      }
      final query = providerProbeQueries[domain] ?? 'naruto';
      final results = await search(query, domain: domain);
      return results.any((anime) => anime.url.isNotEmpty);
    } on Object {
      return false;
    }
  }

  Map<String, dynamic> _responseData(Response<dynamic> response) {
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      return data is Map<String, dynamic> ? data : body;
    }
    return const {};
  }

  List<Map<String, dynamic>> _serverItems(Map<String, dynamic> data) {
    final servers = data['servers'];
    if (servers is List) {
      return servers.cast<Map<String, dynamic>>();
    }
    if (servers is Map<String, dynamic>) {
      return [
        ..._variantServers('DUB', servers['dub'] ?? servers['DUB']),
        ..._variantServers('SUB', servers['sub'] ?? servers['SUB']),
      ];
    }
    return const [];
  }

  List<Map<String, dynamic>> _variantServers(String variant, Object? items) {
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => {...item.cast<String, dynamic>(), 'variant': variant})
        .toList();
  }

  Future<AnimeModel> getInfo(String url) async {
    final response = await _dio.get(
      '/anime/info',
      queryParameters: {'url': url},
    );
    return AnimeModel.fromJson(_responseData(response));
  }

  Future<({AnimeModel anime, List<EpisodeModel> episodes})> getInfoWithEpisodes(
    String url,
  ) async {
    final response = await _dio.get(
      '/anime/info',
      queryParameters: {'url': url},
    );
    final data = _responseData(response);
    final List eps = data['episodes'] ?? [];
    return (
      anime: AnimeModel.fromJson(data),
      episodes: eps
          .map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<EpisodeModel>> getEpisodes(String animeUrl) async {
    final response = await _dio.get(
      '/anime/info',
      queryParameters: {'url': animeUrl},
    );
    final List eps = _responseData(response)['episodes'] ?? [];
    return eps
        .map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VideoServerModel>> getVideoServers(String episodeUrl) async {
    final response = await _dio.get(
      '/anime/episode',
      queryParameters: {'url': episodeUrl, 'includeMega': true},
    );
    return _serverItems(
      _responseData(response),
    ).map(VideoServerModel.fromJson).toList();
  }

  Future<DownloadModel> createDownload({
    required String episodeUrl,
    required String quality,
    required String variant,
    String? preferredServer,
    bool includeMega = false,
  }) async {
    final response = await _dio.post(
      '/anime/download',
      data: {
        'url': episodeUrl,
        'quality': quality,
        'variant': variant,
        'includeMega': includeMega,
        ...preferredServer == null
            ? const {}
            : {'preferredServer': preferredServer},
      },
    );
    return DownloadModel.fromJson(_responseData(response));
  }

  Future<DownloadModel> getDownloadStatus(String downloadId) async {
    final response = await _dio.get('/anime/download/$downloadId');
    return DownloadModel.fromJson(_responseData(response));
  }

  Future<DownloadModel> pauseDownload(String downloadId) async {
    final response = await _dio.post('/anime/download/$downloadId/pause');
    return DownloadModel.fromJson(_responseData(response));
  }

  Future<DownloadModel> resumeDownload(String downloadId) async {
    final response = await _dio.post('/anime/download/$downloadId/resume');
    return DownloadModel.fromJson(_responseData(response));
  }

  Future<void> deleteDownload(String downloadId) async {
    await _dio.delete('/anime/download/$downloadId');
  }

  Future<BatchDownloadModel> createBatchDownload({
    required String animeUrl,
    required List<int> episodes,
    required String quality,
    required String variant,
    bool includeMega = false,
  }) async {
    final response = await _dio.post(
      '/anime/batch-download',
      data: {
        'animeUrl': animeUrl,
        'episodes': episodes,
        'quality': quality,
        'variant': variant,
        'includeMega': includeMega,
      },
    );
    return BatchDownloadModel.fromJson(_responseData(response));
  }

  Future<BatchDownloadModel> getBatchStatus(String batchId) async {
    final response = await _dio.get('/anime/batch/$batchId');
    return BatchDownloadModel.fromJson(_responseData(response));
  }
}

class MoodAnimeResult {
  final AnimeModel anime;
  final int match;
  final String reason;

  const MoodAnimeResult({
    required this.anime,
    required this.match,
    required this.reason,
  });

  factory MoodAnimeResult.fromJson(Map<String, dynamic> json) {
    return MoodAnimeResult(
      anime: AnimeModel.fromJson(json),
      match: (json['match'] as num?)?.toInt() ?? 80,
      reason: json['reason'] as String? ?? 'Coincide con tu mood',
    );
  }
}

class AiRecapResult {
  final String recap;
  final List<String> highlights;
  final bool ai;

  const AiRecapResult({
    required this.recap,
    required this.highlights,
    required this.ai,
  });

  factory AiRecapResult.fromJson(Map<String, dynamic> json) {
    final highlights = json['highlights'];
    return AiRecapResult(
      recap: json['recap'] as String? ?? '',
      highlights: highlights is List
          ? highlights.map((item) => item.toString()).toList()
          : const [],
      ai: json['ai'] as bool? ?? false,
    );
  }
}

class HentailaHubData {
  final List<AnimeModel> featured;
  final List<AnimeModel> latestMedia;
  final List<AnimeModel> latestEpisodes;
  final List<String> genres;

  const HentailaHubData({
    required this.featured,
    required this.latestMedia,
    required this.latestEpisodes,
    required this.genres,
  });
}
