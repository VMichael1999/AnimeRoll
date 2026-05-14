import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/download_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/models/schedule_anime_model.dart';

class AnimeRepository {
  final Dio _dio = DioClient.create();

  static const List<String> imageFirstDomains = [
    'monoschinos2.com',
    'tioanime.com',
    'jkanime.net',
    'animeflv.net',
  ];

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

  Future<List<AnimeModel>> catalog({
    String letter = '#',
    String? type,
    String? genre,
    String? year,
    String? status,
    String? sort,
    int limit = 40,
  }) async {
    final response = await _dio.get(
      '/anime/catalog',
      queryParameters: {
        'domain': 'animeav1.com',
        'letter': letter,
        'type': type,
        'genre': genre,
        'year': year,
        'status': status,
        'sort': sort,
        'limit': limit,
      }..removeWhere((_, v) => v == null || v == ''),
    );
    final data = _responseData(response);
    final results = data['results'];
    final List items = results is List ? results : const [];
    return items
        .map((e) => AnimeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ScheduleAnimeModel>> schedule({required int day}) async {
    final response = await _dio.get(
      '/anime/schedule',
      queryParameters: {'domain': 'animeav1.com', 'day': day},
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
  }) async {
    final results = <AnimeModel>[];
    final seen = <String>{};
    final minimumUsableResults = limit < 12 ? limit : 12;

    for (final domain in imageFirstDomains) {
      try {
        final items = await search(query, domain: domain);
        for (final item in items) {
          if (item.cover == null || item.url.isEmpty || !seen.add(item.url)) {
            continue;
          }
          results.add(item);
          if (results.length >= limit) return results;
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

    return results;
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
