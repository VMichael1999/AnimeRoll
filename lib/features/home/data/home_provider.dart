import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import 'anime_repository.dart';

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnimeRepository(),
);

final popularAnimeProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
  return repo.searchImageFirst('a', limit: 12);
});

final latestAnimeProvider = FutureProvider<List<AnimeModel>>((ref) async {
  final repo = ref.read(animeRepositoryProvider);
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
