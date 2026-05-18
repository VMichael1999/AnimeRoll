import 'dart:async';
import 'dart:convert';

import 'package:anime_roll/features/home/data/anime_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimeRepository', () {
    late _FakeAdapter adapter;
    late AnimeRepository repo;

    setUp(() {
      adapter = _FakeAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = adapter;
      repo = AnimeRepository(dio: dio);
    });

    test('parses search, mood, catalog and schedule responses', () async {
      adapter.stub('GET', '/anime/search', {
        'success': true,
        'data': {
          'results': [
            {'title': 'Naruto', 'url': 'anime-url', 'image': 'cover.jpg'},
          ],
        },
      });
      adapter.stub('GET', '/anime/mood-search', {
        'data': {
          'results': [
            {
              'title': 'Frieren',
              'url': 'mood-url',
              'match': 96,
              'reason': 'Calm fantasy',
            },
          ],
        },
      });
      adapter.stub('GET', '/anime/catalog', {
        'data': {
          'results': [
            {'title': 'Catalog item', 'url': 'catalog-url'},
          ],
        },
      });
      adapter.stub('GET', '/anime/schedule', {
        'data': {
          'results': [
            {'title': 'Today', 'url': 'anime-url', 'episodeUrl': 'ep-url'},
          ],
        },
      });

      expect(
        (await repo.search('naruto', domain: 'animeav1.com')).single.title,
        'Naruto',
      );
      final mood = await repo.moodSearch('calm', domain: 'animeav1.com');
      expect(mood.single.match, 96);
      expect(mood.single.reason, 'Calm fantasy');
      expect(
        (await repo.catalog(
          domain: 'hentaila.com',
          uncensored: true,
        )).single.url,
        'catalog-url',
      );
      expect((await repo.schedule(day: 1)).single.episodeUrl, 'ep-url');
    });

    test('parses info, episodes, servers and recap responses', () async {
      adapter.stub('GET', '/anime/info', {
        'data': {
          'title': 'Frieren',
          'url': 'anime-url',
          'episodes': [
            {'title': 'Episode 1', 'url': 'episode-url', 'number': 1},
          ],
        },
      });
      adapter.stub('GET', '/anime/episode', {
        'data': {
          'servers': {
            'sub': [
              {'name': 'Sub HLS', 'url': 'https://cdn/sub.m3u8'},
            ],
            'dub': [
              {'name': 'Dub MP4', 'url': 'https://cdn/dub.mp4'},
            ],
          },
        },
      });
      adapter.stub('POST', '/anime/recap', {
        'data': {
          'recap': 'A concise recap.',
          'highlights': ['Moment one'],
          'ai': true,
        },
      });

      final anime = await repo.getInfo('anime-url');
      final withEpisodes = await repo.getInfoWithEpisodes('anime-url');
      final episodes = await repo.getEpisodes('anime-url');
      final servers = await repo.getVideoServers('episode-url');
      final recap = await repo.recapEpisode(
        animeTitle: 'Frieren',
        episodeTitle: 'Episode 1',
        percent: 50,
      );

      expect(anime.title, 'Frieren');
      expect(withEpisodes.episodes.single.number, 1);
      expect(episodes.single.title, 'Episode 1');
      expect(
        servers.map((server) => server.variant),
        containsAll(['SUB', 'DUB']),
      );
      expect(recap.ai, isTrue);
      expect(recap.highlights, ['Moment one']);
    });

    test('parses downloads and batch responses', () async {
      adapter.stub('POST', '/anime/download', {
        'success': true,
        'data': {'id': 'd1', 'status': 'queued', 'url': 'episode-url'},
      });
      adapter.stub('GET', '/anime/download/d1', {
        'data': {'id': 'd1', 'status': 'completed', 'url': 'episode-url'},
      });
      adapter.stub('POST', '/anime/batch-download', {
        'data': {'batchId': 'b1', 'status': 'queued', 'total': 2},
      });
      adapter.stub('GET', '/anime/batch/b1', {
        'data': {'batchId': 'b1', 'status': 'completed', 'completed': 2},
      });

      expect(
        (await repo.createDownload(
          episodeUrl: 'episode-url',
          quality: '1080p',
          variant: 'SUB',
        )).id,
        'd1',
      );
      expect((await repo.getDownloadStatus('d1')).status, 'completed');
      expect(
        (await repo.createBatchDownload(
          animeUrl: 'anime-url',
          episodes: [1, 2],
          quality: '720p',
          variant: 'SUB',
        )).id,
        'b1',
      );
      expect((await repo.getBatchStatus('b1')).completed, 2);
    });

    test('parses HentaiLA hub and server provider config', () async {
      adapter.stub('GET', '/anime/hub', {
        'data': {
          'featured': [
            {'title': 'Featured', 'url': 'featured-url'},
          ],
          'latestMedia': [
            {'title': 'Media', 'url': 'media-url'},
          ],
          'latestEpisodes': [
            {'title': 'Episode', 'url': 'episode-url'},
          ],
          'genres': [
            {'name': 'Drama'},
            'Action',
          ],
        },
      });
      adapter.stub('GET', '/anime/providers', {
        'data': {
          'enabled': ['animeav1.com', 'hentaila.com'],
          'disabled': ['jkanime.net'],
        },
      });
      adapter.stub('GET', '/anime/search', {
        'data': {
          'results': [
            {'title': 'Available', 'url': 'available-url'},
          ],
        },
      });

      final hub = await repo.hentailaHub();
      expect(hub.featured.single.title, 'Featured');
      expect(hub.genres, ['Drama', 'Action']);
      expect(await repo.serverEnabledProviders(), [
        'animeav1.com',
        'hentaila.com',
      ]);
      expect(await repo.isProviderAvailable('hentaila.com'), isTrue);
      expect(
        await repo.availableProviders([
          'animeav1.com',
          'jkanime.net',
          'hentaila.com',
        ]),
        ['animeav1.com', 'hentaila.com'],
      );
    });

    test(
      'searchImageFirst skips failures, duplicates and coverless fallback',
      () async {
        adapter.stubError(
          'GET',
          '/anime/search',
          statusCode: 500,
          query: {'domain': 'bad.com'},
        );
        adapter.stub(
          'GET',
          '/anime/search',
          {
            'data': {
              'results': [
                {'title': 'No cover', 'url': 'same-url'},
                {
                  'title': 'With cover',
                  'url': 'same-url',
                  'cover': 'cover.jpg',
                },
                {'title': 'Second', 'url': 'second-url', 'cover': 'second.jpg'},
              ],
            },
          },
          query: {'domain': 'animeav1.com'},
        );

        final results = await repo.searchImageFirst(
          'naruto',
          limit: 2,
          domains: ['bad.com', 'animeav1.com'],
        );

        expect(results.map((anime) => anime.title), ['With cover', 'Second']);
      },
    );

    test('searchImageFirst keeps cover-friendly provider priority', () async {
      adapter.stub(
        'GET',
        '/anime/search',
        {
          'data': {
            'results': [
              {
                'title': 'AnimeAV1 cover',
                'url': 'animeav1-url',
                'image': 'https://cdn.animeav1.com/covers/1.jpg',
              },
            ],
          },
        },
        query: {'domain': 'animeav1.com'},
      );
      adapter.stub(
        'GET',
        '/anime/search',
        {
          'data': {
            'results': [
              {
                'title': 'AnimeFLV cover',
                'url': 'animeflv-url',
                'image': 'https://animeflv.net/uploads/animes/covers/1.jpg',
              },
            ],
          },
        },
        query: {'domain': 'animeflv.net'},
      );

      final results = await repo.searchImageFirst(
        'a',
        limit: 1,
        domains: ['animeflv.net', 'animeav1.com'],
      );

      expect(results.single.title, 'AnimeAV1 cover');
      expect(results.single.cover, 'https://cdn.animeav1.com/covers/1.jpg');
    });

    test(
      'returns disabled server candidates when health checks find none',
      () async {
        adapter.stub('GET', '/anime/providers', {
          'data': {
            'providers': [
              {'domain': 'animeav1.com', 'enabled': true},
              {'domain': 'hentaila.com', 'enabled': false},
            ],
          },
        });
        adapter.stub('GET', '/anime/search', {
          'data': {'results': []},
        });

        expect(
          await repo.availableProviders(['animeav1.com', 'hentaila.com']),
          ['animeav1.com'],
        );
        expect(await repo.isProviderAvailable('animeav1.com'), isFalse);
      },
    );

    test('keeps CineHax when server config enables it', () async {
      adapter.stub('GET', '/anime/providers', {
        'data': {
          'enabled': ['animeav1.com', 'cinehax.com'],
        },
      });
      adapter.stub(
        'GET',
        '/anime/search',
        {
          'data': {
            'results': [
              {'title': 'Available', 'url': 'available-url'},
            ],
          },
        },
        query: {'domain': 'animeav1.com'},
      );

      expect(await repo.availableProviders(['animeav1.com', 'cinehax.com']), [
        'animeav1.com',
        'cinehax.com',
      ]);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  final _stubs = <_Stub>[];

  void stub(
    String method,
    String path,
    Object? body, {
    Map<String, Object?> query = const {},
  }) {
    _stubs.add(_Stub(method, path, query, body, null));
  }

  void stubError(
    String method,
    String path, {
    int statusCode = 500,
    Map<String, Object?> query = const {},
  }) {
    _stubs.add(_Stub(method, path, query, null, statusCode));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final stub = _stubs.lastWhere(
      (stub) => stub.matches(options),
      orElse: () => throw StateError(
        'No stub for ${options.method} ${options.path} ${options.queryParameters}',
      ),
    );
    if (stub.statusCode != null && stub.statusCode! >= 400) {
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'message': 'error'}),
        stub.statusCode!,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(stub.body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Stub {
  final String method;
  final String path;
  final Map<String, Object?> query;
  final Object? body;
  final int? statusCode;

  const _Stub(this.method, this.path, this.query, this.body, this.statusCode);

  bool matches(RequestOptions options) {
    if (method != options.method || path != options.path) return false;
    for (final entry in query.entries) {
      if (options.queryParameters[entry.key]?.toString() !=
          entry.value?.toString()) {
        return false;
      }
    }
    return true;
  }
}
