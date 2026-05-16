import 'package:anime_roll/features/detail/data/detail_provider.dart';
import 'package:anime_roll/features/detail/presentation/detail_screen.dart';
import 'package:anime_roll/features/downloads/presentation/downloads_screen.dart';
import 'package:anime_roll/features/favorites/presentation/favorites_screen.dart';
import 'package:anime_roll/features/history/presentation/history_screen.dart';
import 'package:anime_roll/features/home/data/home_provider.dart';
import 'package:anime_roll/features/home/presentation/home_screen.dart';
import 'package:anime_roll/features/library/presentation/offline_library_screen.dart';
import 'package:anime_roll/features/profile/presentation/profile_screen.dart';
import 'package:anime_roll/features/schedule/data/schedule_provider.dart';
import 'package:anime_roll/features/schedule/presentation/schedule_screen.dart';
import 'package:anime_roll/features/search/data/search_provider.dart';
import 'package:anime_roll/features/search/presentation/search_screen.dart';
import 'package:anime_roll/features/settings/data/settings_provider.dart';
import 'package:anime_roll/features/settings/presentation/settings_screen.dart';
import 'package:anime_roll/features/watchlist/presentation/watchlist_screen.dart';
import 'package:anime_roll/shared/models/anime_model.dart';
import 'package:anime_roll/shared/models/episode_model.dart';
import 'package:anime_roll/shared/models/schedule_anime_model.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const anime = AnimeModel(
    title: 'Frieren',
    url: 'anime-url',
    cover: 'https://example.com/cover.jpg',
    synopsis: 'A thoughtful fantasy journey.',
    status: 'Finalizado',
    type: 'TV',
    year: '2023',
    genres: ['Fantasy', 'Drama'],
    episodeCount: 2,
    score: 9.3,
    votes: 1000,
  );
  const animeTwo = AnimeModel(
    title: 'Naruto',
    url: 'naruto-url',
    cover: 'https://example.com/naruto.jpg',
    genres: ['Action'],
  );
  const episode = EpisodeModel(
    title: 'Episode 1',
    url: 'episode-url',
    thumbnail: 'https://example.com/episode.jpg',
    number: 1,
    duration: '24m',
  );
  final scheduleItem = ScheduleAnimeModel(
    title: 'Frieren',
    url: 'anime-url',
    episodeUrl: 'episode-url',
    cover: 'https://example.com/schedule.jpg',
    episode: 3,
    emittedAt: DateTime.now().add(const Duration(hours: 2)),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen renders standard branch', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HomeScreen(),
        overrides: [
          popularAnimeProvider.overrideWith((ref) async => [anime, animeTwo]),
          latestAnimeProvider.overrideWith((ref) async => [animeTwo]),
          recentlyAddedAnimeProvider.overrideWith((ref) async => [animeTwo]),
          genreAnimeProvider.overrideWith((ref, genre) async => [anime]),
          providerPrefProvider.overrideWith(
            (ref) => _StringNotifier('animeav1.com'),
          ),
        ],
      ),
    );
    await _pumpUi(tester);
    expect(find.text('Frieren'), findsWidgets);
  });

  testWidgets('HomeScreen renders HentaiLA branch', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HomeScreen(),
        overrides: [
          popularAnimeProvider.overrideWith((ref) async => [anime]),
          latestAnimeProvider.overrideWith((ref) async => [animeTwo]),
          recentlyAddedAnimeProvider.overrideWith((ref) async => [anime]),
          genreAnimeProvider.overrideWith((ref, genre) async => [anime]),
          providerPrefProvider.overrideWith(
            (ref) => _StringNotifier('hentaila.com'),
          ),
        ],
      ),
    );
    await _pumpUi(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('SearchScreen renders search and mood modes', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SearchScreen(),
        overrides: [
          availableProvidersProvider.overrideWith(
            (ref) async => ['animeav1.com'],
          ),
          searchResultsProvider.overrideWith((ref) async => [anime]),
          moodResultsProvider.overrideWith((ref) async => []),
          catalogResultsProvider.overrideWith((ref) async => [animeTwo]),
        ],
      ),
    );
    await _pumpUi(tester);
    expect(find.text('Buscar'), findsWidgets);

    await tester.tap(find.text('Mood'));
    await _pumpUi(tester);
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('DetailScreen renders detail data', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DetailScreen(animeUrl: 'anime-url'),
        overrides: [
          animeDetailProvider.overrideWith(
            (ref, url) async => (anime: anime, episodes: [episode]),
          ),
          relatedAnimeProvider.overrideWith((ref, anime) async => [animeTwo]),
        ],
      ),
    );
    await _pumpUi(tester);
    expect(find.text('Frieren'), findsWidgets);
    expect(find.text('Episode 1'), findsWidgets);
  });

  testWidgets('ScheduleScreen renders list and empty state', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ScheduleScreen(),
        overrides: [
          scheduleResultsProvider.overrideWith((ref) async => [scheduleItem]),
        ],
      ),
    );
    await _pumpUi(tester);
    expect(find.text('Horario'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        const ScheduleScreen(),
        overrides: [scheduleResultsProvider.overrideWith((ref) async => [])],
      ),
    );
    await _pumpUi(tester);
    expect(find.byType(ScheduleScreen), findsOneWidget);
  });

  testWidgets('SettingsScreen renders provider picker', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SettingsScreen(),
        overrides: [
          availableProvidersProvider.overrideWith(
            (ref) async => ['animeav1.com', 'hentaila.com'],
          ),
        ],
      ),
    );
    await _pumpUi(tester);
    expect(find.text('Ajustes'), findsOneWidget);

    await tester.tap(find.text('Proveedor activo'));
    await _pumpUi(tester);
    expect(find.text('Seleccionar proveedor'), findsOneWidget);
  });

  testWidgets('Library, downloads and profile screens render', (tester) async {
    await tester.pumpWidget(_wrap(const DownloadsScreen()));
    await _pumpUi(tester);
    expect(find.text('Descargas'), findsOneWidget);

    await tester.pumpWidget(_wrap(const OfflineLibraryScreen()));
    await _pumpUi(tester);
    expect(find.textContaining('Biblioteca'), findsWidgets);

    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await _pumpUi(tester);
    expect(find.text('Michael'), findsWidgets);
  });

  testWidgets('Favorites, watchlist and history screens render', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FavoritesScreen()));
    await _pumpUi(tester);
    expect(find.textContaining('Favoritos'), findsWidgets);

    await tester.pumpWidget(_wrap(const WatchlistScreen()));
    await _pumpUi(tester);
    expect(find.textContaining('Lista'), findsWidgets);

    await tester.pumpWidget(_wrap(const HistoryScreen()));
    await _pumpUi(tester);
    expect(find.textContaining('Historial'), findsWidgets);
  });

  testWidgets('Collection screens render populated states', (tester) async {
    SharedPreferences.setMockInitialValues({
      'favoriteAnime': jsonEncode([anime.toJson(), animeTwo.toJson()]),
      'watchlist_v1': jsonEncode([
        {
          'anime': anime.toJson(),
          'status': 'watching',
          'addedAt': '2024-01-01T00:00:00.000',
        },
        {
          'anime': animeTwo.toJson(),
          'status': 'completed',
          'addedAt': '2024-01-02T00:00:00.000',
        },
      ]),
      'watchHistory_v1': jsonEncode([
        {
          'episodeUrl': 'episode-url',
          'episodeTitle': 'Episode 1',
          'animeTitle': 'Frieren',
          'animeUrl': 'anime-url',
          'thumbnail': 'https://example.com/episode.jpg',
          'episodeNumber': 1,
          'positionMs': 1200000,
          'durationMs': 1440000,
          'percent': 0.83,
          'completed': false,
          'source': 'stream',
          'updatedAt': '2024-01-03T00:00:00.000',
        },
      ]),
      'downloadHistory': jsonEncode([
        {
          'id': 'active',
          'status': 'downloading',
          'progress': 35,
          'url': 'episode-url',
          'animeTitle': 'Frieren',
          'animeUrl': 'anime-url',
          'episodeTitle': 'Episode 1',
          'episodeNumber': 1,
          'quality': '1080p',
          'variant': 'SUB',
        },
        {
          'id': 'saved',
          'status': 'completed',
          'progress': 100,
          'url': 'episode-2-url',
          'animeTitle': 'Frieren',
          'animeUrl': 'anime-url',
          'episodeTitle': 'Episode 2',
          'episodeNumber': 2,
          'quality': '1080p',
          'variant': 'SUB',
          'localStatus': 'saved',
          'localPath': 'C:/videos/frieren-2.mp4',
        },
        {
          'id': 'failed',
          'status': 'failed',
          'progress': 0,
          'url': 'episode-3-url',
          'animeTitle': 'Frieren',
          'animeUrl': 'anime-url',
          'episodeTitle': 'Episode 3',
          'episodeNumber': 3,
          'quality': '720p',
          'variant': 'SUB',
          'error': 'broken',
        },
      ]),
    });

    await tester.pumpWidget(_wrap(const FavoritesScreen()));
    await _pumpUi(tester);
    expect(find.text('Frieren'), findsWidgets);

    await tester.pumpWidget(_wrap(const WatchlistScreen()));
    await _pumpUi(tester);
    expect(find.byType(WatchlistScreen), findsOneWidget);

    await tester.pumpWidget(_wrap(const HistoryScreen()));
    await _pumpUi(tester);
    expect(find.text('Episode 1'), findsWidgets);

    await tester.pumpWidget(_wrap(const DownloadsScreen()));
    await _pumpUi(tester);
    expect(find.text('Episode 1'), findsWidgets);
    await tester.tap(find.text('Guardados'));
    await _pumpUi(tester);
    expect(find.byType(DownloadsScreen), findsOneWidget);
    await tester.tap(find.text('Errores'));
    await _pumpUi(tester);
    expect(find.byType(DownloadsScreen), findsOneWidget);
  });
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: child),
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}

class _StringNotifier extends PersistedSettingNotifier<String> {
  _StringNotifier(String value)
    : super(key: 'test-provider', defaultValue: value);
}
