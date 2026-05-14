import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final marathonProvider =
    StateNotifierProvider<MarathonNotifier, MarathonSession>(
      (ref) => MarathonNotifier(),
    );

class MarathonSession {
  final String startedAt;
  final String updatedAt;
  final int watchedMs;
  final Set<String> episodeKeys;
  final int recordEpisodeCount;

  const MarathonSession({
    required this.startedAt,
    required this.updatedAt,
    required this.watchedMs,
    required this.episodeKeys,
    this.recordEpisodeCount = 0,
  });

  factory MarathonSession.empty({int record = 0}) {
    final now = DateTime.now().toIso8601String();
    return MarathonSession(
      startedAt: now,
      updatedAt: now,
      watchedMs: 0,
      episodeKeys: const {},
      recordEpisodeCount: record,
    );
  }

  factory MarathonSession.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toIso8601String();
    final keys = json['episodeKeys'];
    return MarathonSession(
      startedAt: json['startedAt'] as String? ?? now,
      updatedAt: json['updatedAt'] as String? ?? now,
      watchedMs: (json['watchedMs'] as num?)?.toInt() ?? 0,
      episodeKeys: keys is List
          ? keys.map((item) => item.toString()).toSet()
          : const {},
      recordEpisodeCount:
          (json['recordEpisodeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Duration get watched => Duration(milliseconds: watchedMs);
  int get episodeCount => episodeKeys.length;
  bool get isActive => watchedMs >= const Duration(minutes: 5).inMilliseconds;
  bool get breakRecommended =>
      watchedMs >= const Duration(hours: 2, minutes: 30).inMilliseconds;
  bool get isNewRecord =>
      episodeCount > 0 && episodeCount > recordEpisodeCount;
  Duration get nextBreakIn {
    const breakEvery = Duration(hours: 2, minutes: 30);
    final remainder = watched.inMilliseconds % breakEvery.inMilliseconds;
    return breakEvery - Duration(milliseconds: remainder);
  }

  double get breakProgress {
    final breakEveryMs =
        const Duration(hours: 2, minutes: 30).inMilliseconds;
    return (watchedMs / breakEveryMs).clamp(0.0, 1.0);
  }

  MarathonSession copyWith({
    String? startedAt,
    String? updatedAt,
    int? watchedMs,
    Set<String>? episodeKeys,
    int? recordEpisodeCount,
  }) {
    return MarathonSession(
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      watchedMs: watchedMs ?? this.watchedMs,
      episodeKeys: episodeKeys ?? this.episodeKeys,
      recordEpisodeCount: recordEpisodeCount ?? this.recordEpisodeCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt,
    'updatedAt': updatedAt,
    'watchedMs': watchedMs,
    'episodeKeys': episodeKeys.toList(),
    'recordEpisodeCount': recordEpisodeCount,
  };
}

class MarathonNotifier extends StateNotifier<MarathonSession> {
  static const _storageKey = 'marathonSession_v1';
  static const _maxIdle = Duration(minutes: 45);

  MarathonNotifier() : super(MarathonSession.empty()) {
    unawaited(_load());
  }

  Future<void> recordPlayback({
    required String episodeKey,
    required Duration delta,
  }) async {
    if (episodeKey.isEmpty || delta <= Duration.zero) return;
    if (delta > const Duration(seconds: 25)) return;

    final now = DateTime.now();
    final lastUpdated = DateTime.tryParse(state.updatedAt);
    final shouldReset =
        lastUpdated == null || now.difference(lastUpdated) > _maxIdle;
    final prevRecord = max(state.recordEpisodeCount, state.episodeCount);
    final base = shouldReset
        ? MarathonSession.empty(record: prevRecord)
        : state;
    final newKeys = {...base.episodeKeys, episodeKey};
    state = base.copyWith(
      updatedAt: now.toIso8601String(),
      watchedMs: base.watchedMs + delta.inMilliseconds,
      episodeKeys: newKeys,
    );
    await _persist();
  }

  Future<void> reset() async {
    final record = max(state.recordEpisodeCount, state.episodeCount);
    state = MarathonSession.empty(record: record);
    await _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final loaded = MarathonSession.fromJson(decoded.cast<String, dynamic>());
    final updatedAt = DateTime.tryParse(loaded.updatedAt);
    if (updatedAt == null || DateTime.now().difference(updatedAt) > _maxIdle) {
      return;
    }
    state = loaded;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}
