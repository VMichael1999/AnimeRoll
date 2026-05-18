import 'package:anime_roll/features/home/data/anime_repository.dart';
import 'package:anime_roll/features/home/data/home_provider.dart';
import 'package:anime_roll/features/player/data/ai_recap_provider.dart';
import 'package:anime_roll/features/player/data/player_provider.dart';
import 'package:anime_roll/features/schedule/data/schedule_provider.dart';
import 'package:anime_roll/features/search/data/search_provider.dart';
import 'package:anime_roll/features/settings/data/settings_provider.dart';
import 'package:anime_roll/shared/models/anime_model.dart';
import 'package:anime_roll/shared/models/catalog_page.dart';
import 'package:anime_roll/shared/models/episode_model.dart';
import 'package:anime_roll/shared/models/schedule_anime_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const anime = AnimeModel(
    title: 'Frieren',
    url: 'anime-url',
    cover: 'cover.jpg',
    genres: ['Fantasy'],
  );
  const hentai = AnimeModel(title: 'Adult', url: 'hentai-url');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('home providers use normal and HentaiLA sources', () async {
    final repo = _Repo();
    final normal = ProviderContainer(
      overrides: [
        animeRepositoryProvider.overrideWithValue(repo),
        availableProvidersProvider.overrideWith(
          (ref) async => ['animeav1.com'],
        ),
        providerPrefProvider.overrideWith(
          (ref) => PersistedSettingNotifier(
            key: 'provider',
            defaultValue: 'animeav1.com',
          ),
        ),
      ],
    );
    addTearDown(normal.dispose);

    expect(
      (await normal.read(popularAnimeProvider.future)).single.title,
      anime.title,
    );
    expect(
      (await normal.read(latestAnimeProvider.future)).single.title,
      anime.title,
    );
    expect(
      (await normal.read(genreAnimeProvider('Accion').future)).single.title,
      anime.title,
    );

    final adult = ProviderContainer(
      overrides: [
        animeRepositoryProvider.overrideWithValue(repo),
        providerPrefProvider.overrideWith(
          (ref) => PersistedSettingNotifier(
            key: 'provider',
            defaultValue: 'hentaila.com',
          ),
        ),
      ],
    );
    addTearDown(adult.dispose);

    expect(
      (await adult.read(popularAnimeProvider.future)).single.title,
      hentai.title,
    );
    expect(
      (await adult.read(latestAnimeProvider.future)).single.title,
      hentai.title,
    );
    expect(
      (await adult.read(genreAnimeProvider('Drama').future)).single.title,
      hentai.title,
    );
  });

  test(
    'search providers choose image-first, specific domain, mood and catalog',
    () async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          animeRepositoryProvider.overrideWithValue(repo),
          availableProvidersProvider.overrideWith(
            (ref) async => ['animeav1.com'],
          ),
          providerPrefProvider.overrideWith(
            (ref) => PersistedSettingNotifier(
              key: 'provider',
              defaultValue: 'animeav1.com',
            ),
          ),
          queryProvider.overrideWith((ref) => 'frieren'),
        ],
      );
      addTearDown(container.dispose);

      final searchSub = container.listen(
        searchResultsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(searchSub.close);
      expect(
        (await container.read(searchResultsProvider.future)).single.title,
        anime.title,
      );

      container.read(domainProvider.notifier).state = 'animeav1.com';
      expect(
        (await container.refresh(searchResultsProvider.future)).single.title,
        anime.title,
      );

      final moodSub = container.listen(
        moodResultsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(moodSub.close);
      expect(await container.read(moodResultsProvider.future), hasLength(1));

      container.read(searchModeProvider.notifier).state = SearchMode.catalog;
      expect(
        (await container.read(
          catalogResultsProvider.future,
        )).results.single.title,
        anime.title,
      );
    },
  );

  test('schedule and player providers transform repository data', () async {
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        animeRepositoryProvider.overrideWithValue(repo),
        preferredPlaybackServerProvider.overrideWith(
          (ref) => PersistedSettingNotifier(
            key: 'server',
            defaultValue: 'yourupload',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(scheduleDayProvider.notifier).state = 5;
    expect(await container.read(scheduleResultsProvider.future), hasLength(1));

    final servers = await container.read(serversProvider('episode-url').future);
    expect(servers.first.name.toLowerCase(), contains('yourupload'));
    expect(servers.map((server) => server.url), isNot(contains('')));
  });

  test('ai recap provider delegates request fields', () async {
    final container = ProviderContainer(
      overrides: [animeRepositoryProvider.overrideWithValue(_Repo())],
    );
    addTearDown(container.dispose);

    final recap = await container.read(
      aiRecapProvider(
        const AiRecapRequest(
          animeTitle: 'Frieren',
          episodeTitle: 'Episode 1',
          percent: 0.5,
          synopsis: 'synopsis',
          episodeNumber: 1,
          detail: 'long',
        ),
      ).future,
    );

    expect(recap.recap, 'Recap');
    expect(recap.highlights, ['A']);
    expect(recap.ai, isTrue);
  });
}

class _Repo extends AnimeRepository {
  @override
  Future<List<AnimeModel>> searchImageFirst(
    String query, {
    int limit = 24,
    List<String>? domains,
  }) async => const [
    AnimeModel(title: 'Frieren', url: 'anime-url', cover: 'cover.jpg'),
  ];

  @override
  Future<List<AnimeModel>> search(String query, {String? domain}) async {
    if (domain == 'hentaila.com') {
      return const [AnimeModel(title: 'Adult', url: 'hentai-url')];
    }
    return const [
      AnimeModel(title: 'Frieren', url: 'anime-url', cover: 'cover.jpg'),
    ];
  }

  @override
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
  }) async => const [
    AnimeModel(title: 'Frieren', url: 'anime-url', cover: 'cover.jpg'),
  ];

  @override
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
  }) async => const CatalogPage(
    results: [
      AnimeModel(title: 'Frieren', url: 'anime-url', cover: 'cover.jpg'),
    ],
  );

  @override
  Future<HentailaHubData> hentailaHub() async => const HentailaHubData(
    featured: [AnimeModel(title: 'Adult', url: 'hentai-url')],
    latestMedia: [AnimeModel(title: 'Adult', url: 'hentai-url')],
    latestEpisodes: [AnimeModel(title: 'Adult', url: 'hentai-url')],
    genres: ['Drama'],
  );

  @override
  Future<List<MoodAnimeResult>> moodSearch(
    String query, {
    String? domain,
  }) async => const [
    MoodAnimeResult(
      anime: AnimeModel(title: 'Frieren', url: 'anime-url'),
      match: 90,
      reason: 'calm',
    ),
  ];

  @override
  Future<List<ScheduleAnimeModel>> schedule({int? day}) async => [
    ScheduleAnimeModel(
      title: 'Frieren',
      url: 'anime-url',
      episodeUrl: 'episode-url',
      emittedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<VideoServerModel>> getVideoServers(String episodeUrl) async =>
      const [
        VideoServerModel(name: 'Mega', url: 'https://mega.nz/file'),
        VideoServerModel(name: 'HLS', url: 'https://cdn/video.m3u8'),
        VideoServerModel(name: 'YourUpload', url: 'https://cdn/video.mp4'),
        VideoServerModel(name: 'Broken', url: ''),
      ];

  @override
  Future<AiRecapResult> recapEpisode({
    required String animeTitle,
    required String episodeTitle,
    required double percent,
    String? synopsis,
    int? episodeNumber,
    String detail = 'medium',
  }) async => const AiRecapResult(recap: 'Recap', highlights: ['A'], ai: true);
}
