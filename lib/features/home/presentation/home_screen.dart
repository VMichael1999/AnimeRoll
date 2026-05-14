import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/wide_card.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../settings/data/settings_provider.dart';
import '../data/home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGenre = ref.watch(selectedHomeGenreProvider);
    final genreAnime = ref.watch(genreAnimeProvider(selectedGenre));
    final popular = ref.watch(popularAnimeProvider);
    final latest = ref.watch(latestAnimeProvider);
    final isHentaila = ref.watch(providerPrefProvider) == 'hentaila.com';
    final mainList = selectedGenre == 'Todo' ? popular : genreAnime;

    if (isHentaila) {
      return Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              const SliverToBoxAdapter(child: _HentailaHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              const SliverToBoxAdapter(child: _SearchBar()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: _GenreFilter()),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              SliverToBoxAdapter(
                child: mainList.when(
                  data: (list) => _HentailaGridSection(
                    title: 'Hentai',
                    subtitle: selectedGenre == 'Todo'
                        ? 'RECIENTEMENTE AGREGADOS'
                        : selectedGenre.toUpperCase(),
                    action: 'Catalogo de Hentai',
                    list: list,
                  ),
                  loading: () => const _HentailaGridSkeleton(),
                  error: (err, _) => const SizedBox.shrink(),
                ),
              ),
              if (selectedGenre == 'Todo') ...[
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(
                  child: latest.when(
                    data: (list) => _HentailaGridSection(
                      title: 'Episodios',
                      subtitle: 'RECIENTEMENTE ACTUALIZADO',
                      list: list,
                      episodeCards: true,
                    ),
                    loading: () => const _HentailaGridSkeleton(landscape: true),
                    error: (err, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _HeroSliver(anime: mainList.valueOrNull?.firstOrNull),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: _SearchBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: _GenreFilter()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: _ContinueWatching()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: mainList.when(
              data: (list) => _AnimeRow(
                title: isHentaila
                    ? 'Hentai'
                    : selectedGenre == 'Todo'
                    ? 'Populares'
                    : selectedGenre,
                action: isHentaila ? 'Catalogo de Hentai' : 'Ver todo',
                list: list,
              ),
              loading: () => const _HorizontalSkeleton(),
              error: (err, _) => const SizedBox.shrink(),
            ),
          ),
          if (selectedGenre == 'Todo') ...[
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: latest.when(
                data: (list) => _AnimeRow(
                  title: isHentaila
                      ? 'Episodios recientes'
                      : 'Nuevos episodios',
                  action: isHentaila ? '' : 'Ver todo',
                  list: list,
                ),
                loading: () => const _HorizontalSkeleton(),
                error: (err, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSliver extends StatelessWidget {
  final AnimeModel? anime;
  const _HeroSliver({this.anime});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: false,
      stretch: true,
      backgroundColor: AppColors.bg,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (anime?.cover != null)
              CachedNetworkImage(
                imageUrl: anime!.cover!,
                fit: BoxFit.cover,
                placeholder: (context, _) =>
                    const ColoredBox(color: AppColors.surface2),
                errorWidget: (context, url, _) =>
                    const ColoredBox(color: AppColors.surface2),
              )
            else
              const ColoredBox(color: AppColors.surface2),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.15), AppColors.bg],
                ),
              ),
            ),
            if (anime != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _HeroInfo(anime: anime!),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  final AnimeModel anime;
  const _HeroInfo({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'TENDENCIA #1',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          anime.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 8)],
          ),
          maxLines: 2,
        ),
        if (anime.genres.isNotEmpty)
          Text(
            '${anime.genres.take(3).join(' · ')}${anime.year != null ? ' · ${anime.year}' : ''}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            _HeroButton(
              label: '▶  Reproducir',
              filled: true,
              onTap: () =>
                  context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
            ),
            const SizedBox(width: 8),
            _HeroButton(label: '+ Lista', filled: false, onTap: () {}),
          ],
        ),
      ],
    );
  }
}

class _HeroButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeroButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : Colors.transparent,
          border: Border.all(
            color: filled ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _HentailaHeader extends StatelessWidget {
  const _HentailaHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hentai',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'RECIENTEMENTE AGREGADOS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF1C7EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/search'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Catalogo de Hentai',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHentaila = ref.watch(providerPrefProvider) == 'hentaila.com';
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isHentaila ? 'Buscar en HentaiLA...' : 'Buscar anime...',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Genre filter ──────────────────────────────────────────────────────────────

class _GenreFilter extends ConsumerWidget {
  const _GenreFilter();

  static const _genres = [
    'Todo',
    'Acción',
    'Romance',
    'Isekai',
    'Terror',
    'Comedia',
    'Shounen',
  ];

  static const _hentailaGenres = [
    'Todo',
    '3D',
    'Ahegao',
    'Anal',
    'Casadas',
    'Chikan',
    'Ecchi',
    'Enfermeras',
    'Escolares',
    'Futanari',
    'Gore',
    'Hardcore',
    'Harem',
    'Incesto',
    'Juegos Sexuales',
    'Suspenso',
    'Milfs',
    'Maids',
    'Netorare',
    'Ninfomania',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedHomeGenreProvider);
    final isHentaila = ref.watch(providerPrefProvider) == 'hentaila.com';
    final genres = isHentaila ? _hentailaGenres : _genres;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: genres.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final genre = genres[i];
          final active = genre == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(selectedHomeGenreProvider.notifier).state = genre,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                genre,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppColors.accent2 : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Continue watching ─────────────────────────────────────────────────────────

class _ContinueWatching extends ConsumerWidget {
  const _ContinueWatching();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref
        .watch(downloadsProvider)
        .where((item) => item.isSavedOnDevice)
        .take(8)
        .toList();
    if (downloads.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Continuar viendo',
          action: 'Ver todo',
          onAction: () => context.go('/downloads'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: downloads.length,
            separatorBuilder: (context, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = downloads[i];
              final anime = AnimeModel(
                title: item.albumTitle,
                url: item.animeUrl ?? item.url,
                cover: item.thumbnail,
              );
              return WideCard(
                anime: anime,
                subtitle: item.displayEpisodeTitle,
                onTap: () => context.push(
                  '/download-player?id=${Uri.encodeComponent(item.id)}&title=${Uri.encodeComponent(item.displayEpisodeTitle)}&path=${Uri.encodeComponent(item.localPath!)}&animeTitle=${Uri.encodeComponent(item.albumTitle)}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Generic horizontal row ────────────────────────────────────────────────────

class _AnimeRow extends StatelessWidget {
  final String title;
  final String? action;
  final List<AnimeModel> list;

  const _AnimeRow({required this.title, required this.list, this.action});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          action: action == '' ? null : action ?? 'Ver todo',
          onAction: () => context.go('/search'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (context, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => AnimeCard(
              anime: list[i],
              onTap: () => context.push(
                '/detail?url=${Uri.encodeComponent(list[i].url)}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _HentailaGridSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? action;
  final List<AnimeModel> list;
  final bool episodeCards;

  const _HentailaGridSection({
    required this.title,
    required this.subtitle,
    required this.list,
    this.action,
    this.episodeCards = false,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF1C7EB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null)
                TextButton.icon(
                  onPressed: () => context.go('/search'),
                  icon: const Icon(Icons.layers_outlined, size: 16),
                  label: Text(action!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 14,
              childAspectRatio: episodeCards ? 1.45 : 0.58,
            ),
            itemBuilder: (context, index) {
              final anime = list[index];
              return _HentailaCard(
                anime: anime,
                landscape: episodeCards,
                onTap: () {
                  if (episodeCards) {
                    context.push(
                      '/player?url=${Uri.encodeComponent(anime.url)}&title=${Uri.encodeComponent(anime.type ?? anime.title)}&animeUrl=${Uri.encodeComponent(_animeUrlFromEpisodeUrl(anime.url))}',
                    );
                    return;
                  }
                  context.push('/detail?url=${Uri.encodeComponent(anime.url)}');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static String _animeUrlFromEpisodeUrl(String episodeUrl) {
    final uri = Uri.tryParse(episodeUrl);
    if (uri == null || uri.pathSegments.isEmpty) return episodeUrl;
    final episodeSlug = uri.pathSegments.last;
    final animeSlug = episodeSlug.replaceFirst(RegExp(r'-\d+$'), '');
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      pathSegments: ['media', animeSlug],
    ).toString();
  }
}

class _HentailaCard extends StatelessWidget {
  final AnimeModel anime;
  final bool landscape;
  final VoidCallback onTap;

  const _HentailaCard({
    required this.anime,
    required this.landscape,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
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
                    )
                  else
                    const ColoredBox(color: AppColors.surface2),
                  if (landscape)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2.withValues(alpha: 0.92),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        anime.type ?? 'OVA',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF1C7EB),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            anime.title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: landscape ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HentailaGridSkeleton extends StatelessWidget {
  final bool landscape;

  const _HentailaGridSkeleton({this.landscape = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: landscape ? 1.45 : 0.58,
        ),
        itemBuilder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _HorizontalSkeleton extends StatelessWidget {
  const _HorizontalSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, _) => Column(
          children: [
            Container(
              width: 100,
              height: 138,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 5),
            Container(width: 80, height: 10, color: AppColors.surface2),
          ],
        ),
      ),
    );
  }
}
