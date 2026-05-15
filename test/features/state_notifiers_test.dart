import 'dart:convert';

import 'package:anime_roll/features/favorites/data/favorites_provider.dart';
import 'package:anime_roll/features/history/data/watch_history_provider.dart';
import 'package:anime_roll/features/marathon/data/marathon_provider.dart';
import 'package:anime_roll/features/watchlist/data/watchlist_provider.dart';
import 'package:anime_roll/shared/models/anime_model.dart';
import 'package:anime_roll/shared/models/watch_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const anime = AnimeModel(title: 'Frieren', url: 'anime-url');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoritesNotifier', () {
    test('loads, toggles and removes favorites', () async {
      SharedPreferences.setMockInitialValues({
        'favoriteAnime': jsonEncode([
          {'title': 'Loaded', 'url': 'loaded-url'},
          {'title': 'Broken', 'url': ''},
        ]),
      });
      final notifier = FavoritesNotifier();
      await _settle();

      expect(notifier.state.map((item) => item.url), ['loaded-url']);
      expect(notifier.contains('loaded-url'), isTrue);

      await notifier.toggle(anime);
      expect(notifier.state.first.url, 'anime-url');

      await notifier.toggle(anime);
      expect(notifier.contains('anime-url'), isFalse);

      await notifier.remove('loaded-url');
      expect(notifier.state, isEmpty);
    });
  });

  group('WatchlistNotifier', () {
    test('loads persisted entries and updates status', () async {
      SharedPreferences.setMockInitialValues({
        'watchlist_v1': jsonEncode([
          {
            'anime': {'title': 'Loaded', 'url': 'loaded-url'},
            'status': 'completed',
            'addedAt': '2024-01-01T00:00:00.000',
          },
        ]),
      });
      final notifier = WatchlistNotifier();
      await _settle();

      expect(notifier.statusFor('loaded-url'), WatchStatus.completed);
      expect(notifier.statusFor('missing'), isNull);

      await notifier.setStatus(anime, WatchStatus.planToWatch);
      expect(notifier.statusFor('anime-url'), WatchStatus.planToWatch);

      await notifier.setStatus(anime, WatchStatus.dropped);
      expect(notifier.statusFor('anime-url'), WatchStatus.dropped);

      await notifier.remove('anime-url');
      expect(notifier.statusFor('anime-url'), isNull);
    });

    test('ignores malformed persisted data', () async {
      SharedPreferences.setMockInitialValues({'watchlist_v1': 'not-json'});
      final notifier = WatchlistNotifier();
      await _settle();

      expect(notifier.state, isEmpty);
    });
  });

  group('WatchHistoryNotifier', () {
    test('loads, upserts, completes and clears progress', () async {
      SharedPreferences.setMockInitialValues({
        'watchHistory_v1': jsonEncode([
          {
            'episodeUrl': 'loaded-episode',
            'episodeTitle': 'Loaded episode',
            'animeTitle': 'Loaded anime',
            'animeUrl': 'loaded-anime',
            'positionMs': 1000,
            'durationMs': 10000,
            'percent': 0.1,
            'completed': false,
            'source': 'stream',
            'updatedAt': '2024-01-01T00:00:00.000',
          },
          {'episodeUrl': ''},
        ]),
      });
      final notifier = WatchHistoryNotifier();
      await _settle();

      expect(notifier.find('loaded-episode'), isNotNull);
      expect(notifier.find(''), isNull);

      await notifier.upsertProgress(
        episodeUrl: 'episode-1',
        episodeTitle: 'Episode 1',
        animeTitle: 'Frieren',
        animeUrl: 'anime-url',
        episodeNumber: 1,
        position: const Duration(minutes: 23, seconds: 40),
        duration: const Duration(minutes: 24),
        source: 'stream',
      );

      final entry = notifier.find('episode-1');
      expect(entry, isNotNull);
      expect(entry!.completed, isTrue);
      expect(entry.percent, greaterThan(0.9));

      await notifier.upsertProgress(
        episodeUrl: '',
        episodeTitle: 'Ignored',
        animeTitle: 'Ignored',
        animeUrl: 'ignored',
        position: Duration.zero,
        duration: Duration.zero,
        source: 'stream',
      );
      expect(notifier.state.length, 2);

      await notifier.remove('episode-1');
      expect(notifier.find('episode-1'), isNull);

      await notifier.clear();
      expect(notifier.state, isEmpty);
    });
  });

  group('MarathonSession and MarathonNotifier', () {
    test('computes progress, break state and records playback', () async {
      final session = MarathonSession.fromJson({
        'startedAt': '2024-01-01T00:00:00.000',
        'updatedAt': DateTime.now().toIso8601String(),
        'watchedMs': const Duration(hours: 3).inMilliseconds,
        'episodeKeys': ['a', 'b'],
        'recordEpisodeCount': 1,
      });

      expect(session.watched, const Duration(hours: 3));
      expect(session.episodeCount, 2);
      expect(session.isActive, isTrue);
      expect(session.breakRecommended, isTrue);
      expect(session.isNewRecord, isTrue);
      expect(session.breakProgress, 1.0);
      expect(session.nextBreakIn, isA<Duration>());
      expect(session.toJson()['watchedMs'], session.watchedMs);

      final notifier = MarathonNotifier();
      await _settle();
      await notifier.recordPlayback(
        episodeKey: 'episode-1',
        delta: const Duration(seconds: 10),
      );
      await notifier.recordPlayback(
        episodeKey: '',
        delta: const Duration(seconds: 10),
      );
      await notifier.recordPlayback(
        episodeKey: 'episode-2',
        delta: const Duration(seconds: 30),
      );

      expect(notifier.state.episodeKeys, {'episode-1'});
      expect(
        notifier.state.watchedMs,
        const Duration(seconds: 10).inMilliseconds,
      );

      await notifier.reset();
      expect(notifier.state.watchedMs, 0);
      expect(notifier.state.recordEpisodeCount, 1);
    });
  });

  group('WatchStatusX', () {
    test('exposes labels, icons and colors for every status', () {
      for (final status in WatchStatus.values) {
        expect(status.label, isNotEmpty);
        expect(status.icon, isNotNull);
        expect(status.color, isNotNull);
      }
    });
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);
