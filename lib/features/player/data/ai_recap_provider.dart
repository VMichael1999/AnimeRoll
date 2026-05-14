import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/data/home_provider.dart';
import '../../home/data/anime_repository.dart';

final aiRecapProvider = FutureProvider.autoDispose
    .family<AiRecapResult, AiRecapRequest>((ref, request) {
      return ref
          .read(animeRepositoryProvider)
          .recapEpisode(
            animeTitle: request.animeTitle,
            episodeTitle: request.episodeTitle,
            percent: request.percent,
            synopsis: request.synopsis,
            episodeNumber: request.episodeNumber,
          );
    });

class AiRecapRequest {
  final String animeTitle;
  final String episodeTitle;
  final double percent;
  final String? synopsis;
  final int? episodeNumber;

  const AiRecapRequest({
    required this.animeTitle,
    required this.episodeTitle,
    required this.percent,
    this.synopsis,
    this.episodeNumber,
  });

  @override
  bool operator ==(Object other) {
    return other is AiRecapRequest &&
        other.animeTitle == animeTitle &&
        other.episodeTitle == episodeTitle &&
        other.percent == percent &&
        other.synopsis == synopsis &&
        other.episodeNumber == episodeNumber;
  }

  @override
  int get hashCode =>
      Object.hash(animeTitle, episodeTitle, percent, synopsis, episodeNumber);
}
