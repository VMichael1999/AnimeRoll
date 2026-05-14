import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/models/schedule_anime_model.dart';

final scheduleNotificationsProvider =
    StateNotifierProvider<ScheduleNotificationsNotifier, Set<String>>(
      (ref) => ScheduleNotificationsNotifier(),
    );

class ScheduleNotificationsNotifier extends StateNotifier<Set<String>> {
  static const _storageKey = 'scheduleNotificationKeys';

  ScheduleNotificationsNotifier() : super(const {}) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_storageKey)?.toSet() ?? const {};
  }

  bool isEnabled(ScheduleAnimeModel item) => state.contains(_keyFor(item));

  Future<bool> toggle(ScheduleAnimeModel item) async {
    final key = _keyFor(item);
    if (state.contains(key)) {
      await NotificationService.instance.cancel(_idFor(key));
      state = {...state}..remove(key);
      await _persist();
      return false;
    }

    final emittedAt = item.emittedAt;
    if (emittedAt == null || !emittedAt.isAfter(DateTime.now())) {
      return false;
    }
    await NotificationService.instance.scheduleEpisodeReminder(
      id: _idFor(key),
      title: item.title,
      at: emittedAt,
      body: item.episode == null
          ? 'Nuevo episodio programado'
          : 'Episodio ${item.episode} está por emitirse',
    );
    state = {...state, key};
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, state.toList());
  }

  String _keyFor(ScheduleAnimeModel item) {
    final time = item.emittedAt?.millisecondsSinceEpoch ?? 0;
    return '${item.episodeUrl}|$time';
  }

  int _idFor(String key) => key.hashCode & 0x7fffffff;
}
