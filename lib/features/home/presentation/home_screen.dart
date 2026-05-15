import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/download_model.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/wide_card.dart';
import '../../downloads/data/downloads_provider.dart';
import '../../favorites/data/favorites_provider.dart';
import '../../history/data/watch_history_provider.dart';
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
          const SliverToBoxAdapter(child: _TopBar()),
          SliverToBoxAdapter(
            child: mainList.when(
              data: (list) =>
                  _OverlappedCarousel(items: list.take(5).toList()),
              loading: () => const SizedBox(height: 260),
              error: (err, _) => const SizedBox(height: 260),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: _SearchBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: _GenreFilter()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: _ContinueWatching()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: mainList.when(
              data: (list) => _SpotlightSection(candidates: list),
              loading: () => const SizedBox.shrink(),
              error: (err, _) => const SizedBox.shrink(),
            ),
          ),
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
          if (selectedGenre == 'Todo')
            SliverToBoxAdapter(
              child: mainList.when(
                data: (list) => _Top10Section(list: list),
                loading: () => const SizedBox.shrink(),
                error: (err, _) => const SizedBox.shrink(),
              ),
            ),
          if (selectedGenre == 'Todo') ...[
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
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

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
        child: Row(
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Anime',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'Roll',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.notifications_outlined,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlapped carousel ───────────────────────────────────────────────────────

class _OverlappedCarousel extends StatefulWidget {
  final List<AnimeModel> items;
  const _OverlappedCarousel({required this.items});

  @override
  State<_OverlappedCarousel> createState() => _OverlappedCarouselState();
}

class _OverlappedCarouselState extends State<_OverlappedCarousel> {
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.items.length <= 1) return;
      setState(() => _current = (_current + 1) % widget.items.length);
    });
  }

  void _goTo(int idx) {
    setState(() => _current = idx);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox(height: 260);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final visible = List.generate(widget.items.length, (i) => i)
            .where((i) => (i - _current).abs() <= 2)
            .toList()
          ..sort((a, b) =>
              (b - _current).abs().compareTo((a - _current).abs()));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200 && _current < widget.items.length - 1) {
                  _goTo(_current + 1);
                } else if (v > 200 && _current > 0) {
                  _goTo(_current - 1);
                }
              },
              child: SizedBox(
                height: 240,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: visible.map((i) => _buildCard(i, w)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.items.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: i == _current ? 20 : 5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? AppColors.accent2
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(int itemIdx, double w) {
    final anime = widget.items[itemIdx];
    final dist = itemIdx - _current;
    final absDist = dist.abs();

    final double cW = w * 0.54;
    final double nW = w * 0.43;
    final double fW = w * 0.33;

    final double cardW = absDist == 0 ? cW : absDist == 1 ? nW : fW;
    final double cardH =
        absDist == 0 ? 240.0 : absDist == 1 ? 202.0 : 168.0;

    final double centerLeft = (w - cW) / 2;
    double left;
    if (dist == 0) {
      left = centerLeft;
    } else if (dist == -1) {
      left = centerLeft - nW * 0.62;
    } else if (dist == 1) {
      left = centerLeft + cW - nW * 0.38;
    } else if (dist == -2) {
      left = centerLeft - nW * 0.62 - fW * 0.52;
    } else {
      left = centerLeft + cW - nW * 0.38 + fW * 0.52;
    }

    final double opacity = absDist == 0 ? 1.0 : absDist == 1 ? 0.55 : 0.25;
    final double skewAngle = dist == 0 ? 0.0 : dist < 0 ? 0.18 : -0.18;

    return AnimatedPositioned(
      key: ValueKey(itemIdx),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOut,
      left: left,
      bottom: 0,
      width: cardW,
      height: cardH,
      child: GestureDetector(
        onTap: absDist == 0
            ? () => context
                .push('/detail?url=${Uri.encodeComponent(anime.url)}')
            : () => _goTo(itemIdx),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 350),
          opacity: opacity,
          child: Transform(
            alignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(skewAngle),
            child: _CarouselCard(anime: anime, isCenter: absDist == 0),
          ),
        ),
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final AnimeModel anime;
  final bool isCenter;

  const _CarouselCard({required this.anime, required this.isCenter});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (anime.cover != null)
            CachedNetworkImage(
              imageUrl: anime.cover!,
              fit: BoxFit.cover,
              placeholder: (context, _) =>
                  ColoredBox(color: AppColors.surface2),
              errorWidget: (context, url, _) =>
                  ColoredBox(color: AppColors.surface2),
            )
          else
            ColoredBox(color: AppColors.surface2),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2),
                  AppColors.bg,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCenter
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : AppColors.border.withValues(alpha: 0.5),
                width: isCenter ? 1.5 : 1,
              ),
            ),
          ),
          if (isCenter) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0.0, 0.5],
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (anime.genres.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        ...anime.genres.take(2),
                        if (anime.year != null) anime.year!,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xAAFFFFFF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _HeroButton(
                        label: 'Reproducir',
                        icon: Icons.play_arrow_rounded,
                        filled: true,
                        onTap: () => context.push(
                          '/detail?url=${Uri.encodeComponent(anime.url)}',
                        ),
                      ),
                      const SizedBox(width: 6),
                      _HeroButton(
                          label: '+ Lista', filled: false, onTap: () {}),
                      if (anime.score != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface2.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐',
                                  style: TextStyle(fontSize: 9)),
                              const SizedBox(width: 2),
                              Text(
                                anime.score!.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final VoidCallback onTap;

  const _HeroButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: filled ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
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
              Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                isHentaila ? 'Buscar en HentaiLA...' : 'Buscar anime...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
    final history = ref
        .watch(watchHistoryProvider)
        .where((item) => !item.completed && item.percent > 0.01)
        .take(8)
        .toList();
    if (history.isEmpty) return const SizedBox.shrink();
    final downloads = ref.watch(downloadsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: 'Continuar viendo',
          action: 'Ver todo',
          onAction: () => context.go('/history'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            separatorBuilder: (context, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = history[i];
              final anime = AnimeModel(
                title: item.animeTitle,
                url: item.animeUrl,
                cover: item.thumbnail,
              );
              return Stack(
                children: [
                  WideCard(
                    anime: anime,
                    subtitle:
                        '${item.episodeTitle} · ${(item.percent * 100).round()}%',
                    onTap: () => _openHistoryItem(context, item, downloads),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: item.percent.clamp(0, 1),
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(AppColors.accent2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _openHistoryItem(
    BuildContext context,
    WatchHistoryEntry item,
    List<DownloadModel> downloads,
  ) {
    final local = downloads
        .where((download) => download.url == item.episodeUrl)
        .firstOrNull;
    if (local?.isSavedOnDevice == true && local?.localPath != null) {
      context.push(
        '/download-player?id=${Uri.encodeComponent(local!.id)}&title=${Uri.encodeComponent(local.displayEpisodeTitle)}&path=${Uri.encodeComponent(local.localPath!)}&animeTitle=${Uri.encodeComponent(local.albumTitle)}',
      );
      return;
    }
    context.push(
      '/player?url=${Uri.encodeComponent(item.episodeUrl)}&title=${Uri.encodeComponent(item.episodeTitle)}&animeUrl=${Uri.encodeComponent(item.animeUrl)}',
    );
  }
}

// ── Spotlight ────────────────────────────────────────────────────────────────

class _SpotlightSection extends ConsumerStatefulWidget {
  final List<AnimeModel> candidates;

  const _SpotlightSection({required this.candidates});

  @override
  ConsumerState<_SpotlightSection> createState() => _SpotlightSectionState();
}

class _SpotlightSectionState extends ConsumerState<_SpotlightSection> {
  int _skipCount = 0;

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final history = ref.watch(watchHistoryProvider);
    final selectedGenre = ref.watch(selectedHomeGenreProvider);

    final picks = _SpotlightPick.ranked(
      candidates: widget.candidates,
      favorites: favorites,
      history: history,
      filter: selectedGenre,
    );

    if (picks.isEmpty) return const SizedBox.shrink();

    final mainIndex = picks.isNotEmpty ? _skipCount % picks.length : 0;
    final spotlight = picks[mainIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(title: 'Sorpréndeme'),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SpotlightCard(
            spotlight: spotlight,
            onSkip: () => setState(() => _skipCount++),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPick {
  final AnimeModel anime;
  final String reason;
  final int match;

  const _SpotlightPick({
    required this.anime,
    required this.reason,
    required this.match,
  });

  static List<_SpotlightPick> ranked({
    required List<AnimeModel> candidates,
    required List<AnimeModel> favorites,
    required List<WatchHistoryEntry> history,
    String filter = 'Para mí',
  }) {
    final seenUrls = {
      for (final item in favorites) item.url,
      for (final item in history) item.animeUrl,
    };
    final genreWeights = <String, int>{};
    for (final anime in favorites) {
      for (final genre in anime.genres) {
        genreWeights.update(genre, (v) => v + 3, ifAbsent: () => 3);
      }
    }
    for (final item in history) {
      final tokens = item.animeTitle.toLowerCase().split(RegExp(r'\W+'));
      for (final token in tokens.where((t) => t.length > 4)) {
        genreWeights.update(token, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    var pool = candidates.where((a) => a.url.isNotEmpty).toList();

    // Apply genre/type filter
    final filtered = _applyFilter(pool, filter);
    if (filtered.isNotEmpty) pool = filtered;

    // Unseen first, seen fallback
    final unseen = pool.where((a) => !seenUrls.contains(a.url)).toList();
    final ranked =
        (unseen.isNotEmpty ? unseen : pool)
            .map((a) => MapEntry(a, _scoreAnime(a, genreWeights)))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return ranked.take(5).map((e) {
      final matchedGenres = e.key.genres
          .where((g) => genreWeights.containsKey(g))
          .take(2)
          .toList();
      final reason = matchedGenres.isNotEmpty
          ? 'Porque sigues ${matchedGenres.join(' y ')}'
          : e.key.score != null
          ? 'Buena valoración para descubrir algo nuevo'
          : 'Una recomendación fuera de tu lista';
      return _SpotlightPick(
        anime: e.key,
        reason: reason,
        match: e.value.clamp(72, 98),
      );
    }).toList();
  }

  static List<AnimeModel> _applyFilter(List<AnimeModel> pool, String filter) {
    return switch (filter) {
      'Acción' =>
        pool
            .where((a) => a.genres.any((g) => g.toLowerCase().contains('acci')))
            .toList(),
      'Romance' =>
        pool
            .where((a) => a.genres.any((g) => g.toLowerCase() == 'romance'))
            .toList(),
      'Isekai' =>
        pool
            .where((a) => a.genres.any((g) => g.toLowerCase() == 'isekai'))
            .toList(),
      'Película' =>
        pool
            .where(
              (a) =>
                  a.type?.toLowerCase().contains('movie') == true ||
                  a.type?.toLowerCase().contains('pel') == true ||
                  a.episodeCount == 1,
            )
            .toList(),
      'Clásico' =>
        pool
            .where((a) => (int.tryParse(a.year ?? '') ?? 9999) <= 2005)
            .toList(),
      'Poco conocido' => pool.where((a) => (a.score ?? 0) < 7.5).toList(),
      'Todo' => pool,
      _ =>
        pool
            .where(
              (a) =>
                  a.genres.any((g) => g.toLowerCase() == filter.toLowerCase()),
            )
            .toList(),
    };
  }

  static int _scoreAnime(AnimeModel anime, Map<String, int> genreWeights) {
    var score = 70;
    for (final genre in anime.genres) {
      score += genreWeights[genre] ?? 0;
    }
    if (anime.cover != null) score += 4;
    if (anime.status?.toLowerCase().contains('final') == true) score += 3;
    if ((anime.score ?? 0) > 0) score += ((anime.score ?? 0) * 2).round();
    if ((anime.episodeCount ?? 0) > 0 && (anime.episodeCount ?? 0) <= 24) {
      score += 3;
    }
    return score;
  }
}

class _SpotlightCard extends StatelessWidget {
  final _SpotlightPick spotlight;
  final VoidCallback onSkip;

  const _SpotlightCard({required this.spotlight, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final anime = spotlight.anime;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1228), Color(0xFF0D0D20)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover 16:9
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (anime.cover != null)
                  CachedNetworkImage(
                    imageUrl: anime.cover!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, err) =>
                        const ColoredBox(color: Color(0xFF2D1F50)),
                  )
                else
                  const ColoredBox(color: Color(0xFF2D1F50)),
                // Bottom gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0],
                      colors: [Colors.transparent, Color(0xFF1E1228)],
                    ),
                  ),
                ),
                // Top-left genre badges
                Positioned(
                  top: 10,
                  left: 10,
                  child: Wrap(
                    spacing: 5,
                    children: [
                      ...anime.genres
                          .take(2)
                          .map((g) => _SpotlightPill(label: g)),
                      if (anime.status != null)
                        _SpotlightPill(label: anime.status!),
                    ],
                  ),
                ),
                // Bottom title + meta
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (anime.year != null) anime.year,
                          if (anime.episodeCount != null)
                            '${anime.episodeCount} eps',
                          if (anime.score != null)
                            '⭐ ${anime.score!.toStringAsFixed(1)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Why section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('🎲', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spotlight.reason,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(
                      '/detail?url=${Uri.encodeComponent(anime.url)}',
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Ver ahora',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: onSkip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.skip_next_rounded,
                            color: AppColors.textSecondary,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Otro anime',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPill extends StatelessWidget {
  final String label;

  const _SpotlightPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Home section header ───────────────────────────────────────────────────────

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _HomeSectionHeader({
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.accent, AppColors.accent2],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                '$action →',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accent2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Top 10 ────────────────────────────────────────────────────────────────────

class _Top10Section extends StatelessWidget {
  final List<AnimeModel> list;
  const _Top10Section({required this.list});

  @override
  Widget build(BuildContext context) {
    final top10 = list.take(10).toList();
    if (top10.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: 'Top 10 hoy',
          action: 'Ver ranking',
          onAction: () => context.go('/search'),
        ),
        SizedBox(
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: top10.length,
            separatorBuilder: (context, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) =>
                _Top10Card(anime: top10[i], rank: i + 1),
          ),
        ),
      ],
    );
  }
}

class _Top10Card extends StatelessWidget {
  final AnimeModel anime;
  final int rank;
  const _Top10Card({required this.anime, required this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
      child: SizedBox(
        width: 115,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 115,
                height: 155,
                child: anime.cover == null
                    ? ColoredBox(color: AppColors.surface2)
                    : CachedNetworkImage(
                        imageUrl: anime.cover!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, _) =>
                            ColoredBox(color: AppColors.surface2),
                      ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: -4,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.5
                    ..color = AppColors.accent2,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic horizontal row ────────────────────────────────────────────────────

class _AnimeRow extends ConsumerWidget {
  final String title;
  final String? action;
  final List<AnimeModel> list;

  const _AnimeRow({required this.title, required this.list, this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) return const SizedBox.shrink();
    final layout = ref.watch(catalogLayoutProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: title,
          action: action == '' ? null : action ?? 'Ver todo',
          onAction: () => context.go('/search'),
        ),
        const SizedBox(height: 10),
        if (layout == 'list')
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.take(8).length,
            separatorBuilder: (context, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _HomeListTile(anime: list[i]),
          )
        else
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

class _HomeListTile extends StatelessWidget {
  final AnimeModel anime;
  final VoidCallback? onTapOverride;

  const _HomeListTile({required this.anime, this.onTapOverride});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap:
          onTapOverride ??
          () => context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
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
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 78,
                child: anime.cover == null
                    ? ColoredBox(color: AppColors.surface2)
                    : CachedNetworkImage(
                        imageUrl: anime.cover!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, _) =>
                            ColoredBox(color: AppColors.surface2),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (anime.type != null) anime.type,
                      if (anime.status != null) anime.status,
                      if (anime.year != null) anime.year,
                      if (anime.genres.isNotEmpty) anime.genres.first,
                    ].whereType<String>().join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _HentailaGridSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) return const SizedBox.shrink();
    final layout = ref.watch(catalogLayoutProvider);
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
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
                  icon: Icon(Icons.layers_outlined, size: 16),
                  label: Text(action!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (layout == 'list')
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.take(8).length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HomeListTile(
                anime: list[index],
                onTapOverride: episodeCards
                    ? () {
                        final anime = list[index];
                        context.push(
                          '/player?url=${Uri.encodeComponent(anime.url)}&title=${Uri.encodeComponent(anime.type ?? anime.title)}&animeUrl=${Uri.encodeComponent(_animeUrlFromEpisodeUrl(anime.url))}',
                        );
                      }
                    : null,
              ),
            )
          else
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
                    context.push(
                      '/detail?url=${Uri.encodeComponent(anime.url)}',
                    );
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
                          ColoredBox(color: AppColors.surface2),
                      errorWidget: (context, url, _) =>
                          ColoredBox(color: AppColors.surface2),
                    )
                  else
                    ColoredBox(color: AppColors.surface2),
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
                        style: TextStyle(
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
