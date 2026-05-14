import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/watch_status.dart';

class WatchlistEntry {
  final AnimeModel anime;
  final WatchStatus status;
  final DateTime addedAt;

  const WatchlistEntry({
    required this.anime,
    required this.status,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'anime': anime.toJson(),
        'status': status.name,
        'addedAt': addedAt.toIso8601String(),
      };

  factory WatchlistEntry.fromJson(Map<String, dynamic> json) {
    return WatchlistEntry(
      anime: AnimeModel.fromJson(json['anime'] as Map<String, dynamic>),
      status: WatchStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => WatchStatus.watching,
      ),
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

class WatchlistNotifier extends StateNotifier<List<WatchlistEntry>> {
  WatchlistNotifier() : super([]) {
    _load();
  }

  static const _key = 'watchlist_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => WatchlistEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  WatchStatus? statusFor(String animeUrl) {
    for (final e in state) {
      if (e.anime.url == animeUrl) return e.status;
    }
    return null;
  }

  Future<void> setStatus(AnimeModel anime, WatchStatus status) async {
    final idx = state.indexWhere((e) => e.anime.url == anime.url);
    final updated = List<WatchlistEntry>.from(state);
    if (idx >= 0) {
      updated[idx] = WatchlistEntry(
        anime: anime,
        status: status,
        addedAt: state[idx].addedAt,
      );
    } else {
      updated.add(
        WatchlistEntry(anime: anime, status: status, addedAt: DateTime.now()),
      );
    }
    state = updated;
    await _persist();
  }

  Future<void> remove(String animeUrl) async {
    state = state.where((e) => e.anime.url != animeUrl).toList();
    await _persist();
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, List<WatchlistEntry>>(
      (ref) => WatchlistNotifier(),
    );
