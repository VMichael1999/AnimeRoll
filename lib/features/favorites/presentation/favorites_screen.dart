import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../data/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String _filter = 'Todos';
  bool _scoreFirst = true;

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final filters = _filters(favorites);
    final visible = _visibleFavorites(favorites);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Favoritos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _scoreFirst ? 'Orden alfabetico' : 'Orden rating',
                    onPressed: () => setState(() => _scoreFirst = !_scoreFirst),
                    icon: Icon(
                      _scoreFirst
                          ? Icons.star_rounded
                          : Icons.sort_by_alpha_rounded,
                    ),
                  ),
                ],
              ),
            ),
            if (favorites.isNotEmpty) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filters.length,
                  separatorBuilder: (context, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    final active = filter == _filter;
                    return _FilterChip(
                      label: filter,
                      active: active,
                      onTap: () => setState(() => _filter = filter),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${visible.length} de ${favorites.length} guardados',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      _scoreFirst ? 'Mejor rating' : 'A-Z',
                      style: const TextStyle(
                        color: AppColors.accent2,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: favorites.isEmpty
                  ? const _EmptyFavorites()
                  : _FavoriteGrid(favorites: visible),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _filters(List<AnimeModel> favorites) {
    final genres = {
      for (final anime in favorites)
        for (final genre in anime.genres.take(3))
          if (genre.trim().isNotEmpty) genre.trim(),
    }.toList()..sort();
    return ['Todos', 'En emision', 'Finalizados', ...genres.take(8)];
  }

  List<AnimeModel> _visibleFavorites(List<AnimeModel> favorites) {
    var items = favorites.where((anime) {
      if (_filter == 'Todos') return true;
      if (_filter == 'En emision') {
        return anime.status?.toLowerCase().contains('emisi') == true;
      }
      if (_filter == 'Finalizados') {
        return anime.status?.toLowerCase().contains('final') == true;
      }
      return anime.genres.contains(_filter);
    }).toList();

    items.sort((a, b) {
      if (_scoreFirst) {
        return (b.score ?? 0).compareTo(a.score ?? 0);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return items;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.16)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.accent2 : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
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
    if (favorites.isEmpty) {
      return const Center(
        child: Text(
          'No hay favoritos para este filtro',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

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
                      left: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              anime.status?.toLowerCase().contains('emisi') ==
                                  true
                              ? AppColors.success
                              : AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (anime.score != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.warning,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                anime.score!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 7,
                      right: 7,
                      child: InkWell(
                        onTap: () => ref
                            .read(favoritesProvider.notifier)
                            .remove(anime.url),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(18),
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
              const SizedBox(height: 3),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (anime.type != null) _MiniTag(label: anime.type!),
                  if (anime.episodeCount != null)
                    _MiniTag(label: '${anime.episodeCount} eps'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;

  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
      ),
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
