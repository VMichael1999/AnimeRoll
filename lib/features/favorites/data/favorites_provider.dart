import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/anime_model.dart';

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<AnimeModel>>((ref) {
      return FavoritesNotifier();
    });

class FavoritesNotifier extends StateNotifier<List<AnimeModel>> {
  static const _storageKey = 'favoriteAnime';

  FavoritesNotifier() : super(const []) {
    unawaited(_load());
  }

  bool contains(String animeUrl) {
    return state.any((anime) => anime.url == animeUrl);
  }

  Future<void> toggle(AnimeModel anime) async {
    if (anime.url.isEmpty) return;
    if (contains(anime.url)) {
      state = state.where((item) => item.url != anime.url).toList();
    } else {
      state = [anime, ...state.where((item) => item.url != anime.url)];
    }
    await _persist();
  }

  Future<void> remove(String animeUrl) async {
    state = state.where((item) => item.url != animeUrl).toList();
    await _persist();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    state = decoded
        .whereType<Map>()
        .map((item) => AnimeModel.fromJson(item.cast<String, dynamic>()))
        .where((anime) => anime.url.isNotEmpty)
        .toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(state.map((anime) => anime.toJson()).toList()),
    );
  }
}
