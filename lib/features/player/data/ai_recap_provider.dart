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
            detail: request.detail,
          );
    });

class AiRecapRequest {
  final String animeTitle;
  final String episodeTitle;
  final double percent;
  final String? synopsis;
  final int? episodeNumber;
  final String detail;

  const AiRecapRequest({
    required this.animeTitle,
    required this.episodeTitle,
    required this.percent,
    this.synopsis,
    this.episodeNumber,
    this.detail = 'medium',
  });

  @override
  bool operator ==(Object other) {
    return other is AiRecapRequest &&
        other.animeTitle == animeTitle &&
        other.episodeTitle == episodeTitle &&
        other.percent == percent &&
        other.synopsis == synopsis &&
        other.episodeNumber == episodeNumber &&
        other.detail == detail;
  }

  @override
  int get hashCode =>
      Object.hash(animeTitle, episodeTitle, percent, synopsis, episodeNumber, detail);
}
