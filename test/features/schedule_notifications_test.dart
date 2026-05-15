import 'package:anime_roll/features/schedule/data/schedule_notifications_provider.dart';
import 'package:anime_roll/shared/models/schedule_anime_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'toggles schedule notification key without scheduling past episodes',
    () async {
      final item = ScheduleAnimeModel(
        title: 'Frieren',
        url: 'anime-url',
        episodeUrl: 'episode-url',
        episode: 1,
        emittedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final notifier = ScheduleNotificationsNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.isEnabled(item), isFalse);
      expect(await notifier.toggle(item), isTrue);
      expect(notifier.isEnabled(item), isTrue);
    },
  );

  test('loads persisted keys', () async {
    final emittedAt = DateTime(2024, 1, 1);
    final item = ScheduleAnimeModel(
      title: 'Frieren',
      url: 'anime-url',
      episodeUrl: 'episode-url',
      emittedAt: emittedAt,
    );
    SharedPreferences.setMockInitialValues({
      'scheduleNotificationKeys': [
        'episode-url|${emittedAt.millisecondsSinceEpoch}',
      ],
    });

    final notifier = ScheduleNotificationsNotifier();
    await Future<void>.delayed(Duration.zero);

    expect(notifier.isEnabled(item), isTrue);
  });
}
