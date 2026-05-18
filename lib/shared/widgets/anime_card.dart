import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/anime_model.dart';
import 'app_network_image.dart';

class AnimeCard extends StatelessWidget {
  final AnimeModel anime;
  final VoidCallback? onTap;
  final double width;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(cover: anime.cover, episodeCount: anime.episodeCount),
            const SizedBox(height: 5),
            Text(
              anime.title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (anime.genres.isNotEmpty)
              Text(
                anime.genres.first,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? cover;
  final int? episodeCount;

  const _Thumbnail({this.cover, this.episodeCount});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: 138,
            child: AppNetworkImage(
              url: cover,
              fit: BoxFit.cover,
              height: 138,
              errorWidget: const _PlaceholderThumb(),
              placeholder: const _PlaceholderThumb(),
            ),
          ),
          if (episodeCount != null)
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Ep $episodeCount',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.movie_outlined, color: AppColors.border, size: 28),
      ),
    );
  }
}
