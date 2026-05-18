import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/available_filters.dart';
import '../../../shared/utils/provider_capabilities.dart';
import '../../home/data/anime_repository.dart';
import '../../home/data/home_provider.dart';
import '../../settings/data/settings_provider.dart';

final queryProvider = StateProvider<String>((ref) => '');
final domainProvider = StateProvider<String?>((ref) => null);
final searchModeProvider = StateProvider<SearchMode>(
  (ref) => SearchMode.search,
);
final catalogLetterProvider = StateProvider<String>((ref) => '#');
final catalogFiltersProvider = StateProvider<CatalogFilters>(
  (ref) => const CatalogFilters(),
);

enum SearchMode { search, mood, catalog }

/// Wrapper para preguntar "este proveedor es scoped?" sin volver a
/// hardcodear nombres. Delega en `ProviderId.fromDomain(...).isScoped`.
bool _isScoped(String? domain) => ProviderId.fromDomain(domain).isScoped;

final moodResultsProvider = FutureProvider.autoDispose<List<MoodAnimeResult>>((
  ref,
) async {
  final query = ref.watch(queryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  final domain = _isScoped(activeProvider)
      ? activeProvider
      : ref.watch(domainProvider);
  if (query.trim().isEmpty) return [];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (disposed) return [];
  return ref
      .read(animeRepositoryProvider)
      .moodSearch(query.trim(), domain: domain);
});

class CatalogFilters {
  final String? type;
  final String? genre;
  final String? year;
  final String? status;
  final String? sort;
  final bool uncensored;

  const CatalogFilters({
    this.type,
    this.genre,
    this.year,
    this.status,
    this.sort,
    this.uncensored = false,
  });

  bool get isActive =>
      type != null ||
      genre != null ||
      year != null ||
      status != null ||
      sort != null ||
      uncensored;

  CatalogFilters copyWith({
    String? type,
    String? genre,
    String? year,
    String? status,
    String? sort,
    bool? uncensored,
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
      uncensored: uncensored ?? this.uncensored,
    );
  }
}

final searchResultsProvider = FutureProvider.autoDispose<List<AnimeModel>>((
  ref,
) async {
  final query = ref.watch(queryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  final domain = _isScoped(activeProvider)
      ? activeProvider
      : ref.watch(domainProvider);
  if (query.trim().isEmpty) return [];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 350));
  if (disposed) return [];
  final repo = ref.read(animeRepositoryProvider);
  if (domain == null) {
    final providers = await ref.watch(availableProvidersProvider.future);
    return repo.searchImageFirst(
      query.trim(),
      // Excluimos proveedores scoped del multi-search por defecto. Cada uno
      // (hentaila, monoschinos) se busca solo desde su propia pantalla.
      domains: providers.where((d) => !_isScoped(d)).toList(),
    );
  }
  return repo.search(query.trim(), domain: domain);
});

/// Fetcha del backend los filtros disponibles para el proveedor dado.
/// Devuelve solo lo que el sitio realmente soporta (ej. AnimeAV1 expone
/// genero + estado, ignora tipo/año/orden).
final availableFiltersProvider = FutureProvider.autoDispose
    .family<AvailableFilters, String>((ref, domain) async {
      final repo = ref.read(animeRepositoryProvider);
      return repo.availableFilters(domain: domain);
    });

final catalogResultsProvider = FutureProvider.autoDispose<List<AnimeModel>>((
  ref,
) async {
  final letter = ref.watch(catalogLetterProvider);
  final filters = ref.watch(catalogFiltersProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  final query = ref.watch(queryProvider);
  final repo = ref.read(animeRepositoryProvider);
  // Domain del catálogo: respeta el proveedor activo. Antes solo contemplaba
  // hentaila y caía a animeav1 para MonosChinos, mostrando catálogo de AV1
  // dentro de la home de MC (bug). Ahora cualquier proveedor activo (AV1,
  // hentaila, monoschinos…) se respeta.
  return repo.catalog(
    domain: activeProvider,
    letter: letter,
    type: filters.type,
    genre: filters.genre,
    year: filters.year,
    status: filters.status,
    sort: filters.sort,
    uncensored: filters.uncensored,
    // El parámetro `search` solo aplica al modo "catalog-con-buscador-inline"
    // (hentaila). Otros proveedores tienen pantalla de búsqueda separada.
    search: ProviderId.fromDomain(activeProvider) == ProviderId.hentaila
        ? query.trim()
        : null,
    limit: 60,
  );
});
