import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../home/data/home_provider.dart';

typedef AnimeDetailData = ({AnimeModel anime, List<EpisodeModel> episodes});

final animeDetailProvider = FutureProvider.autoDispose
    .family<AnimeDetailData, String>(
      (ref, url) => ref.read(animeRepositoryProvider).getInfoWithEpisodes(url),
    );
