import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/detail_provider.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../settings/data/settings_provider.dart';

class DetailScreen extends ConsumerWidget {
  final String animeUrl;
  const DetailScreen({super.key, required this.animeUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animeAsync = ref.watch(animeDetailProvider(animeUrl));

    return Scaffold(
      body: animeAsync.when(
        data: (detail) => _DetailBody(detail: detail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'No se pudo cargar el anime',
          onRetry: () => ref.invalidate(animeDetailProvider(animeUrl)),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final AnimeDetailData detail;

  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final anime = detail.anime;
    final episodes = detail.episodes;

    return CustomScrollView(
      slivers: [
        _DetailAppBar(anime: anime),
        SliverToBoxAdapter(
          child: _DetailInfo(anime: anime, episodes: episodes),
        ),
        SliverToBoxAdapter(
          child: _EpisodeSection(
            episodes: episodes,
            fallbackThumbnail: anime.cover,
            animeTitle: anime.title,
            animeUrl: anime.url,
          ),
        ),
        SliverToBoxAdapter(child: _RelatedSection(anime: anime)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  final AnimeModel anime;
  const _DetailAppBar({required this.anime});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.bg,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (anime.cover != null)
              CachedNetworkImage(
                imageUrl: anime.cover!,
                fit: BoxFit.cover,
                placeholder: (context, _) =>
                    const ColoredBox(color: AppColors.surface2),
                errorWidget: (context, url, _) =>
                    const ColoredBox(color: AppColors.surface2),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.bg],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfo extends ConsumerWidget {
  final AnimeModel anime;
  final List<EpisodeModel> episodes;

  const _DetailInfo({required this.anime, required this.episodes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstEpisode = episodes.firstOrNull;
    final isFavorite = ref.watch(
      favoritesProvider.select(
        (items) => items.any((item) => item.url == anime.url),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 70,
                  height: 98,
                  child: anime.cover != null
                      ? CachedNetworkImage(
                          imageUrl: anime.cover!,
                          fit: BoxFit.cover,
                          placeholder: (context, _) =>
                              const _ImagePlaceholder(iconSize: 22),
                          errorWidget: (context, url, _) =>
                              const _ImagePlaceholder(iconSize: 22),
                        )
                      : const _ImagePlaceholder(iconSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (anime.year != null) anime.year!,
                        if (anime.status != null) anime.status!,
                        if (anime.episodeCount != null)
                          '${anime.episodeCount} eps',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatsRow(anime: anime),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (anime.synopsis != null) ...[
            Text(
              anime.synopsis!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
          ],
          if (anime.genres.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: anime.genres.map((g) => _GenreTag(label: g)).toList(),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: firstEpisode == null
                      ? null
                      : () => context.push(
                          '/player?url=${Uri.encodeComponent(firstEpisode.url)}&title=${Uri.encodeComponent(firstEpisode.title)}&animeUrl=${Uri.encodeComponent(anime.url)}',
                        ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    'Ver ahora',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconAction(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                active: isFavorite,
                onTap: () => ref.read(favoritesProvider.notifier).toggle(anime),
              ),
              const SizedBox(width: 8),
              _IconAction(
                icon: Icons.download_rounded,
                onTap: firstEpisode == null
                    ? null
                    : () => _downloadEpisode(context, ref, firstEpisode),
              ),
              const SizedBox(width: 8),
              _IconAction(
                icon: Icons.playlist_add_check_rounded,
                onTap: episodes.isEmpty
                    ? null
                    : () => _downloadBatch(context, ref, episodes),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadEpisode(
    BuildContext context,
    WidgetRef ref,
    EpisodeModel episode,
  ) async {
    try {
      await ref
          .read(downloadsProvider.notifier)
          .startEpisode(
            episodeUrl: episode.url,
            title: '${anime.title} · ${episode.title}',
            thumbnail: episode.thumbnail ?? anime.cover,
            animeTitle: anime.title,
            animeUrl: anime.url,
            episodeTitle: episode.title,
            episodeNumber: episode.number,
            quality: ref.read(qualityPrefProvider),
            variant: ref.read(variantPrefProvider),
            preferredServer: anime.url.contains('hentaila.com')
                ? 'VIP'
                : 'yourupload',
          );
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Descarga agregada',
          type: AppToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'No se pudo iniciar la descarga',
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _downloadBatch(
    BuildContext context,
    WidgetRef ref,
    List<EpisodeModel> episodes,
  ) async {
    final episodeNumbers = episodes
        .map((episode) => episode.number)
        .whereType<int>()
        .toList();
    if (episodeNumbers.isEmpty) {
      AppToast.show(
        context,
        message: 'No hay episodios validos',
        type: AppToastType.error,
      );
      return;
    }

    try {
      final batch = await ref
          .read(downloadsProvider.notifier)
          .startBatch(
            animeUrl: anime.url,
            episodes: episodeNumbers,
            title: anime.title,
            thumbnail: anime.cover,
            quality: ref.read(qualityPrefProvider),
            variant: ref.read(variantPrefProvider),
          );
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Lote agregado: ${batch.total} episodios',
          type: AppToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'No se pudo iniciar el lote',
          type: AppToastType.error,
        );
      }
    }
  }
}

class _StatsRow extends StatelessWidget {
  final AnimeModel anime;
  const _StatsRow({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (anime.score != null)
          _Stat(value: anime.score!.toStringAsFixed(1), label: 'Score'),
        if (anime.episodeCount != null) ...[
          const SizedBox(width: 14),
          _Stat(value: '${anime.episodeCount}', label: 'Eps'),
        ],
        const SizedBox(width: 14),
        const _Stat(value: 'SUB', label: 'Audio'),
        const SizedBox(width: 14),
        const _Stat(value: 'HD', label: 'Calidad'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.accent2,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _GenreTag extends StatelessWidget {
  final String label;
  const _GenreTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  const _IconAction({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? AppColors.accent2 : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Episodes ──────────────────────────────────────────────────────────────────

class _EpisodeSection extends StatelessWidget {
  final List<EpisodeModel> episodes;
  final String? fallbackThumbnail;
  final String animeTitle;
  final String animeUrl;

  const _EpisodeSection({
    required this.episodes,
    required this.animeTitle,
    required this.animeUrl,
    this.fallbackThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            'Episodios',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        if (episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sin episodios disponibles',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          _EpisodeList(
            episodes: episodes,
            animeTitle: animeTitle,
            animeUrl: animeUrl,
            fallbackThumbnail: fallbackThumbnail,
          ),
      ],
    );
  }
}

class _EpisodeList extends ConsumerWidget {
  final List<EpisodeModel> episodes;
  final String? fallbackThumbnail;
  final String animeTitle;
  final String animeUrl;

  const _EpisodeList({
    required this.episodes,
    required this.animeTitle,
    required this.animeUrl,
    this.fallbackThumbnail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: episodes.length,
      separatorBuilder: (context, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _EpisodeItem(
        episode: episodes[i],
        fallbackThumbnail: fallbackThumbnail,
        onTap: () => context.push(
          '/player?url=${Uri.encodeComponent(episodes[i].url)}&title=${Uri.encodeComponent(episodes[i].title)}&animeUrl=${Uri.encodeComponent(animeUrl)}',
        ),
        onDownload: () => _downloadEpisode(context, ref, episodes[i]),
      ),
    );
  }

  Future<void> _downloadEpisode(
    BuildContext context,
    WidgetRef ref,
    EpisodeModel episode,
  ) async {
    try {
      await ref
          .read(downloadsProvider.notifier)
          .startEpisode(
            episodeUrl: episode.url,
            title: '$animeTitle · ${episode.title}',
            thumbnail: episode.thumbnail ?? fallbackThumbnail,
            animeTitle: animeTitle,
            animeUrl: animeUrl,
            episodeTitle: episode.title,
            episodeNumber: episode.number,
            quality: ref.read(qualityPrefProvider),
            variant: ref.read(variantPrefProvider),
            preferredServer: animeUrl.contains('hentaila.com')
                ? 'VIP'
                : 'yourupload',
          );
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'Descarga agregada: ${episode.title}',
          type: AppToastType.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'No se pudo iniciar la descarga',
          type: AppToastType.error,
        );
      }
    }
  }
}

class _EpisodeItem extends StatelessWidget {
  final EpisodeModel episode;
  final String? fallbackThumbnail;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _EpisodeItem({
    required this.episode,
    required this.onTap,
    required this.onDownload,
    this.fallbackThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnail = episode.thumbnail ?? fallbackThumbnail;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 60,
                height: 38,
                color: AppColors.border,
                child: thumbnail != null
                    ? CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, _) =>
                            const _ImagePlaceholder(iconSize: 18),
                        errorWidget: (context, url, _) =>
                            const _ImagePlaceholder(iconSize: 18),
                      )
                    : const Icon(
                        Icons.play_circle_outline,
                        color: AppColors.textSecondary,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (episode.duration != null)
                    Text(
                      episode.duration!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Descargar episodio',
              onPressed: onDownload,
              icon: const Icon(
                Icons.download_rounded,
                color: AppColors.accent2,
                size: 19,
              ),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              tooltip: 'Reproducir episodio',
              onPressed: onTap,
              icon: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.textSecondary,
                size: 21,
              ),
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double iconSize;

  const _ImagePlaceholder({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
          size: iconSize,
        ),
      ),
    );
  }
}

class _RelatedSection extends ConsumerWidget {
  final AnimeModel anime;

  const _RelatedSection({required this.anime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatedAsync = ref.watch(relatedAnimeProvider(anime));

    return relatedAsync.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final sameUniverse = items
            .where((item) => _sameFamily(anime.title, item.title))
            .take(6)
            .toList();
        final recommendations = items
            .where((item) => !sameUniverse.any((same) => same.url == item.url))
            .take(6)
            .toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sameUniverse.isNotEmpty) ...[
                const _RelatedTitle('Del mismo universo'),
                const SizedBox(height: 10),
                _RelatedCarousel(items: sameUniverse),
                const SizedBox(height: 18),
              ],
              if (recommendations.isNotEmpty) ...[
                const _RelatedTitle('Te puede gustar'),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: recommendations
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RecommendationTile(
                              anime: item,
                              reason: anime.genres.isNotEmpty
                                  ? 'Por tu interes en ${anime.genres.first}'
                                  : 'Similar a ${anime.title}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  bool _sameFamily(String source, String candidate) {
    final sourceKey = _mainTitle(source);
    final candidateKey = _mainTitle(candidate);
    return sourceKey.length > 3 && candidateKey.contains(sourceKey);
  }

  String _mainTitle(String value) {
    return value
        .toLowerCase()
        .split(RegExp(r'[:\-()]'))
        .first
        .replaceAll(RegExp(r'\b(season|part|final|tv)\b'), '')
        .trim();
  }
}

class _RelatedTitle extends StatelessWidget {
  final String title;

  const _RelatedTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }
}

class _RelatedCarousel extends StatelessWidget {
  final List<AnimeModel> items;

  const _RelatedCarousel({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 16),
        itemCount: items.length,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _RelatedCard(anime: items[index]),
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  final AnimeModel anime;

  const _RelatedCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _RelatedImage(url: anime.cover),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            if (anime.score != null)
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    anime.score!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final AnimeModel anime;
  final String reason;

  const _RecommendationTile({required this.anime, required this.reason});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 64,
                child: _RelatedImage(url: anime.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (anime.genres.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: anime.genres
                          .take(2)
                          .map((genre) => _GenreTag(label: genre))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedImage extends StatelessWidget {
  final String? url;

  const _RelatedImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _ImagePlaceholder(iconSize: 20);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, _) => const _ImagePlaceholder(iconSize: 20),
      errorWidget: (context, url, error) =>
          const _ImagePlaceholder(iconSize: 20),
    );
  }
}
