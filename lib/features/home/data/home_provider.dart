import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../settings/data/settings_provider.dart';
import 'anime_repository.dart';

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnimeRepository(),
);

final hentailaHubProvider = FutureProvider<HentailaHubData>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  return repo.hentailaHub();
});

final popularAnimeProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  if (activeProvider == 'hentaila.com') {
    final hub = await ref.watch(hentailaHubProvider.future);
    return hub.latestMedia;
  }
  return repo.searchImageFirst('a', limit: 12);
});

final latestAnimeProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  final activeProvider = ref.watch(providerPrefProvider);
  if (activeProvider == 'hentaila.com') {
    final hub = await ref.watch(hentailaHubProvider.future);
    return hub.latestEpisodes;
  }
  return repo.searchImageFirst('one', limit: 12);
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
  return repo.searchImageFirst(_genreQuery(genre), limit: 24);
});

String _genreQuery(String genre) {
  return switch (genre) {
    'Acción' => 'action',
    'Terror' => 'horror',
    'Comedia' => 'comedy',
    _ => genre.toLowerCase(),
  };
}
