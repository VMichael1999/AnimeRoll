import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final watchHistoryProvider =
    StateNotifierProvider<WatchHistoryNotifier, List<WatchHistoryEntry>>(
      (ref) => WatchHistoryNotifier(),
    );

class WatchHistoryEntry {
  final String episodeUrl;
  final String episodeTitle;
  final String animeTitle;
  final String animeUrl;
  final String? thumbnail;
  final int? episodeNumber;
  final int positionMs;
  final int durationMs;
  final double percent;
  final bool completed;
  final String source;
  final String updatedAt;

  const WatchHistoryEntry({
    required this.episodeUrl,
    required this.episodeTitle,
    required this.animeTitle,
    required this.animeUrl,
    this.thumbnail,
    this.episodeNumber,
    required this.positionMs,
    required this.durationMs,
    required this.percent,
    required this.completed,
    required this.source,
    required this.updatedAt,
  });

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WatchHistoryEntry(
      episodeUrl: json['episodeUrl'] as String? ?? '',
      episodeTitle: json['episodeTitle'] as String? ?? '',
      animeTitle: json['animeTitle'] as String? ?? '',
      animeUrl: json['animeUrl'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt(),
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      completed: json['completed'] as bool? ?? false,
      source: json['source'] as String? ?? 'stream',
      updatedAt:
          json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'episodeUrl': episodeUrl,
    'episodeTitle': episodeTitle,
    'animeTitle': animeTitle,
    'animeUrl': animeUrl,
    'thumbnail': thumbnail,
    'episodeNumber': episodeNumber,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'percent': percent,
    'completed': completed,
    'source': source,
    'updatedAt': updatedAt,
  };
}

class WatchHistoryNotifier extends StateNotifier<List<WatchHistoryEntry>> {
  static const _storageKey = 'watchHistory_v1';
  static const _maxItems = 250;

  WatchHistoryNotifier() : super(const []) {
    unawaited(_load());
  }

  WatchHistoryEntry? find(String episodeUrl) {
    if (episodeUrl.isEmpty) return null;
    return state.where((item) => item.episodeUrl == episodeUrl).firstOrNull;
  }

  Future<void> upsertProgress({
    required String episodeUrl,
    required String episodeTitle,
    required String animeTitle,
    required String animeUrl,
    String? thumbnail,
    int? episodeNumber,
    required Duration position,
    required Duration duration,
    required String source,
  }) async {
    if (episodeUrl.isEmpty || duration.inMilliseconds <= 0) return;
    final percent = (position.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final completed =
        percent >= 0.9 || duration - position <= const Duration(seconds: 30);
    final entry = WatchHistoryEntry(
      episodeUrl: episodeUrl,
      episodeTitle: episodeTitle,
      animeTitle: animeTitle,
      animeUrl: animeUrl,
      thumbnail: thumbnail,
      episodeNumber: episodeNumber,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      percent: percent,
      completed: completed,
      source: source,
      updatedAt: DateTime.now().toIso8601String(),
    );

    state = [
      entry,
      ...state.where((item) => item.episodeUrl != episodeUrl),
    ].take(_maxItems).toList();
    await _persist();
  }

  Future<void> remove(String episodeUrl) async {
    state = state.where((item) => item.episodeUrl != episodeUrl).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    state = decoded
        .whereType<Map>()
        .map((item) => WatchHistoryEntry.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.episodeUrl.isNotEmpty)
        .toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(state.map((item) => item.toJson()).toList()),
    );
  }
}
