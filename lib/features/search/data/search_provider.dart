import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../home/data/home_provider.dart';

final queryProvider = StateProvider<String>((ref) => '');
final domainProvider = StateProvider<String?>((ref) => null);
final searchModeProvider = StateProvider<SearchMode>(
  (ref) => SearchMode.search,
);
final catalogLetterProvider = StateProvider<String>((ref) => '#');
final catalogFiltersProvider = StateProvider<CatalogFilters>(
  (ref) => const CatalogFilters(),
);

enum SearchMode { search, catalog }

class CatalogFilters {
  final String? type;
  final String? genre;
  final String? year;
  final String? status;
  final String? sort;

  const CatalogFilters({
    this.type,
    this.genre,
    this.year,
    this.status,
    this.sort,
  });

  bool get isActive =>
      type != null ||
      genre != null ||
      year != null ||
      status != null ||
      sort != null;

  CatalogFilters copyWith({
    String? type,
    String? genre,
    String? year,
    String? status,
    String? sort,
    bool clearType = false,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearStatus = false,
    bool clearSort = false,
  }) {
    return CatalogFilters(
      type: clearType ? null : type ?? this.type,
      genre: clearGenre ? null : genre ?? this.genre,
      year: clearYear ? null : year ?? this.year,
      status: clearStatus ? null : status ?? this.status,
      sort: clearSort ? null : sort ?? this.sort,
    );
  }
}

final searchResultsProvider = FutureProvider.autoDispose<List<AnimeModel>>((
  ref,
) async {
  final query = ref.watch(queryProvider);
  final domain = ref.watch(domainProvider);
  if (query.trim().isEmpty) return [];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (disposed) return [];
  final repo = ref.read(animeRepositoryProvider);
  if (domain == null) {
    return repo.searchImageFirst(query.trim());
  }
  return repo.search(query.trim(), domain: domain);
});

final catalogResultsProvider = FutureProvider.autoDispose<List<AnimeModel>>((
  ref,
) async {
  final letter = ref.watch(catalogLetterProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final repo = ref.read(animeRepositoryProvider);
  return repo.catalog(
    letter: letter,
    type: filters.type,
    genre: filters.genre,
    year: filters.year,
    status: filters.status,
    sort: filters.sort,
    limit: 60,
  );
});
