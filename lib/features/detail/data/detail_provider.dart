import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../home/data/home_provider.dart';

typedef AnimeDetailData = ({AnimeModel anime, List<EpisodeModel> episodes});

final animeDetailProvider = FutureProvider.autoDispose
    .family<AnimeDetailData, String>(
      (ref, url) => ref.read(animeRepositoryProvider).getInfoWithEpisodes(url),
    );

final relatedAnimeProvider = FutureProvider.autoDispose
    .family<List<AnimeModel>, AnimeModel>((ref, anime) async {
      final repo = ref.read(animeRepositoryProvider);
      final query = anime.genres.isNotEmpty ? anime.genres.first : anime.title;
      final results = await repo.searchImageFirst(query, limit: 12);
      return results
          .where((item) => item.url.isNotEmpty && item.url != anime.url)
          .toList();
    });
