import 'package:anime_roll/shared/models/anime_model.dart';
import 'package:anime_roll/shared/models/download_model.dart';
import 'package:anime_roll/shared/models/episode_model.dart';
import 'package:anime_roll/shared/models/schedule_anime_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimeModel', () {
    test('parses provider aliases and derived fields', () {
      final anime = AnimeModel.fromJson({
        'title': 'Frieren',
        'url': 'https://animeav1.com/media/frieren',
        'image': 'cover.jpg',
        'description': 'Journey after the party.',
        'status': 2,
        'type': 1,
        'startDate': '2023-09-29',
        'genres': [
          {'name': 'Fantasy'},
          'Drama',
          null,
        ],
        'episodes': [{}, {}, {}],
        'score': 9,
        'votes': 1200,
      });

      expect(anime.title, 'Frieren');
      expect(anime.cover, 'cover.jpg');
      expect(anime.synopsis, 'Journey after the party.');
      expect(anime.status, 'En emisión');
      expect(anime.type, '1');
      expect(anime.year, '2023');
      expect(anime.genres, ['Fantasy', 'Drama']);
      expect(anime.episodeCount, 3);
      expect(anime.score, 9.0);
      expect(anime.votes, 1200);
      expect(anime.toJson()['title'], 'Frieren');
    });

    test('uses safe defaults for missing data', () {
      final anime = AnimeModel.fromJson({});

      expect(anime.title, '');
      expect(anime.url, '');
      expect(anime.genres, isEmpty);
      expect(anime.status, isNull);
      expect(anime.year, isNull);
    });
  });

  group('EpisodeModel and VideoServerModel', () {
    test('parse aliases and HLS detection', () {
      final episode = EpisodeModel.fromJson({
        'title': 'Episode 1',
        'url': 'episode-url',
        'image': 'thumb.jpg',
        'number': 1.0,
        'duration': '24m',
      });
      final server = VideoServerModel.fromJson({
        'server': 'HLS',
        'url': 'https://cdn/video.m3u8',
        'quality': '1080p',
      });

      expect(episode.thumbnail, 'thumb.jpg');
      expect(episode.number, 1);
      expect(server.name, 'HLS');
      expect(server.variant, 'SUB');
      expect(server.isHls, isTrue);
    });
  });

  group('DownloadModel', () {
    test('parses status and computed labels', () {
      final download = DownloadModel.fromJson({
        'downloadId': 'd1',
        'status': 'completed',
        'progress': 100,
        'url': 'episode-url',
        'title': 'Frieren · Episode 2',
        'episodeNumber': 2,
        'localStatus': 'saved',
        'localPath': '/videos/frieren.mp4',
        'fileSize': 12345,
      });

      expect(download.id, 'd1');
      expect(download.isRunning, isFalse);
      expect(download.isSavedOnDevice, isTrue);
      expect(download.albumTitle, 'Frieren');
      expect(download.albumKey, 'frieren');
      expect(download.displayEpisodeTitle, 'Episode 2');
      expect(download.fileSize, '12345');
      expect(download.effectiveProgress, 100);
      expect(download.toJson()['id'], 'd1');
    });

    test('copyWith updates selected fields', () {
      final original = DownloadModel.fromJson({
        'id': 'd1',
        'status': 'downloading',
        'url': 'episode-url',
      });
      final copy = original.copyWith(
        status: 'completed',
        localStatus: 'saving',
        localProgress: 45,
      );

      expect(original.isRunning, isTrue);
      expect(copy.status, 'completed');
      expect(copy.isLocalRunning, isTrue);
      expect(copy.effectiveProgress, 45);
    });
  });

  group('BatchDownloadModel', () {
    test('parses item list', () {
      final batch = BatchDownloadModel.fromJson({
        'batchId': 'b1',
        'status': 'running',
        'progress': 50,
        'total': 2,
        'completed': 1,
        'failed': 0,
        'items': [
          {'episode': 1, 'downloadId': 'd1', 'status': 'completed'},
        ],
      });

      expect(batch.id, 'b1');
      expect(batch.items.single.episode, 1);
      expect(batch.items.single.status, 'completed');
    });
  });

  group('ScheduleAnimeModel', () {
    test('parses cover aliases and emitted date', () {
      final schedule = ScheduleAnimeModel.fromJson({
        'title': 'Frieren',
        'url': 'anime-url',
        'episodeUrl': 'episode-url',
        'poster': 'poster.jpg',
        'type': 'TV',
        'episode': 4,
        'emittedAt': '2024-01-01T12:00:00Z',
      });

      expect(schedule.cover, 'poster.jpg');
      expect(schedule.episode, 4);
      expect(schedule.emittedAt, isNotNull);
    });
  });
}
