import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../data/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Text(
                'Favoritos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: favorites.isEmpty
                  ? const _EmptyFavorites()
                  : _FavoriteGrid(favorites: favorites),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteGrid extends ConsumerWidget {
  final List<AnimeModel> favorites;

  const _FavoriteGrid({required this.favorites});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final anime = favorites[index];
        return GestureDetector(
          onTap: () =>
              context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: anime.cover == null
                            ? const _PosterPlaceholder()
                            : CachedNetworkImage(
                                imageUrl: anime.cover!,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const _PosterPlaceholder(),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => ref
                            .read(favoritesProvider.notifier)
                            .remove(anime.url),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.accent2,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                anime.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.favorite_border_rounded, color: AppColors.border),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 56,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Sin favoritos',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Marca animes desde el detalle o el reproductor',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
