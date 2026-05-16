import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/monoschinos_hub.dart';
import '../../../shared/models/schedule_anime_model.dart';
import '../../settings/data/settings_provider.dart';
import 'anime_repository.dart';

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnimeRepository(),
);

final hentailaHubProvider = FutureProvider<HentailaHubData>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  return repo.hentailaHub();
});

/// Hub de MonosChinos (últimos capítulos publicados). Solo se usa cuando el
/// proveedor activo es `monoschinos2.net`; en otros casos el home cae al flujo
/// genérico (schedule / catalog).
final monosChinosHubProvider = FutureProvider<MonosChinosHubData>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  return repo.monosChinosHub();
});

/// Animes "En emisión" para la home de MonosChinos. Es una vista derivada
/// del catálogo filtrado por `?estado=en+emision`. El usuario pidió que esta
/// sección esté visible al iniciar la app cuando MonosChinos es el proveedor
/// activo — ver mensaje original.
final monosChinosAiringProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  return repo.catalog(
    domain: 'monoschinos2.net',
    status: 'en emision',
    limit: 18,
  );
});

final popularAnimeProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  if (activeProvider == 'hentaila.com') {
    final hub = await ref.watch(hentailaHubProvider.future);
    return hub.latestMedia;
  }
  final schedule = await repo.schedule();
  return _uniqueAnime(schedule).take(12).toList(growable: false);
});

final latestAnimeProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  if (activeProvider == 'hentaila.com') {
    final hub = await ref.watch(hentailaHubProvider.future);
    return hub.latestEpisodes;
  }
  final schedule = await repo.schedule();
  return _latestEpisodes(
    schedule,
  ).take(12).map(_scheduleToAnime).toList(growable: false);
});

final recentlyAddedAnimeProvider = FutureProvider<List<AnimeModel>>((
  ref,
) async {
  final repo = ref.read(animeRepositoryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  if (activeProvider == 'hentaila.com') {
    final hub = await ref.watch(hentailaHubProvider.future);
    return hub.latestMedia;
  }
  return repo.catalog(domain: 'animeav1.com', limit: 12);
});

final selectedHomeGenreProvider = StateProvider<String>((ref) => 'Todo');

final genreAnimeProvider = FutureProvider.family<List<AnimeModel>, String>((
  ref,
  genre,
) async {
  if (genre == 'Todo') {
    return ref.watch(popularAnimeProvider.future);
  }
  final repo = ref.read(animeRepositoryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  if (activeProvider == 'hentaila.com') {
    return repo.search(_genreQuery(genre), domain: activeProvider);
  }
  return repo.catalog(
    domain: 'animeav1.com',
    genre: catalogGenreValue(genre),
    limit: 24,
  );
});

String catalogGenreValue(String genre) => genre
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[áàäâ]'), 'a')
    .replaceAll(RegExp(r'[éèëê]'), 'e')
    .replaceAll(RegExp(r'[íìïî]'), 'i')
    .replaceAll(RegExp(r'[óòöô]'), 'o')
    .replaceAll(RegExp(r'[úùüû]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

AnimeModel _scheduleToAnime(ScheduleAnimeModel item) => AnimeModel(
  title: item.title,
  url: item.url,
  cover: item.cover,
  type: item.episode == null ? item.type : 'Episodio ${item.episode}',
  year: item.emittedAt?.year.toString(),
);

List<AnimeModel> _uniqueAnime(List<ScheduleAnimeModel> items) {
  final sorted = _latestEpisodes(items);
  final seen = <String>{};
  final result = <AnimeModel>[];
  for (final item in sorted) {
    if (!seen.add(item.url)) continue;
    result.add(_scheduleToAnime(item));
  }
  return result;
}

List<ScheduleAnimeModel> _latestEpisodes(List<ScheduleAnimeModel> items) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final aTime = a.emittedAt;
    final bTime = b.emittedAt;
    if (aTime == null && bTime == null) return a.title.compareTo(b.title);
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return sorted;
}

String _genreQuery(String genre) {
  return switch (genre) {
    'Acción' => 'action',
    'Terror' => 'horror',
    'Comedia' => 'comedy',
    _ => genre.toLowerCase(),
  };
}
