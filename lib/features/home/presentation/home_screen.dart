import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/download_model.dart';
import '../../../shared/models/monoschinos_hub.dart';
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
    final recentlyAdded = ref.watch(recentlyAddedAnimeProvider);
    final activeProvider = ref.watch(providerPrefProvider);
    final isHentaila = activeProvider == 'hentaila.com';
    final isMonosChinos = activeProvider == 'monoschinos2.net';
    final mainList = selectedGenre == 'Todo' ? popular : genreAnime;

    // MonosChinos: estilo timeline retro propio, distinto a AnimeAV1 (carrusel
    // + filas landscape) y a HentaiLA (grid 2-col de posters). El widget
    // dedicado consume directamente `monosChinosHubProvider` y no reusa
    // popular/latest porque su shape es distinto (latestEpisodes con campos
    // `episode` y `genre`).
    if (isMonosChinos) {
      return const _MonosChinosHome();
    }

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
            child: popular.when(
              data: (list) => _OverlappedCarousel(items: list.take(5).toList()),
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
          if (selectedGenre == 'Todo') ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: latest.when(
                data: (list) => _AnimeRow(
                  title: 'Episodios',
                  subtitle: 'Recientemente Actualizado',
                  action: 'Ver horario',
                  actionRoute: '/schedule',
                  list: list,
                  landscape: true,
                ),
                loading: () => const _HorizontalSkeleton(landscape: true),
                error: (err, _) => const SizedBox.shrink(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            SliverToBoxAdapter(
              child: recentlyAdded.when(
                data: (list) => _AnimeRow(
                  title: 'Animes',
                  subtitle: 'Recientemente Agregados',
                  action: 'Catalogo de Animes',
                  actionRoute: '/search?mode=catalog',
                  list: list,
                ),
                loading: () => const _HorizontalSkeleton(),
                error: (err, _) => const SizedBox.shrink(),
              ),
            ),
          ] else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: mainList.when(
                data: (list) => _AnimeRow(
                  title: selectedGenre,
                  subtitle: 'Catalogo de Animes',
                  action: 'Ver filtros',
                  actionRoute: '/search?mode=catalog',
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

class _AnimeAv1Hero extends StatefulWidget {
  final List<AnimeModel> items;

  const _AnimeAv1Hero({required this.items});

  @override
  State<_AnimeAv1Hero> createState() => _AnimeAv1HeroState();
}

class _AnimeAv1HeroState extends State<_AnimeAv1Hero> {
  final _controller = PageController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || widget.items.length <= 1 || !_controller.hasClients) {
        return;
      }
      final current = (_controller.page ?? 0).round();
      _controller.animateToPage(
        (current + 1) % widget.items.length,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox(height: 260);
    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        itemBuilder: (context, index) =>
            _AnimeAv1HeroSlide(anime: widget.items[index]),
      ),
    );
  }
}

class _AnimeAv1HeroSlide extends StatelessWidget {
  final AnimeModel anime;

  const _AnimeAv1HeroSlide({required this.anime});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
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
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.35),
                  AppColors.bg,
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (anime.type != null) anime.type!,
                    if (anime.year != null) anime.year!,
                    if (anime.status != null) anime.status!,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (anime.genres.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: anime.genres
                        .take(4)
                        .map(
                          (genre) => _HeroGenreChip(
                            genre: genre,
                            onTap: () => context.go(
                              '/search?mode=catalog&domain=animeav1.com&genre=${Uri.encodeComponent(catalogGenreValue(genre))}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => context.push(
                    '/detail?url=${Uri.encodeComponent(anime.url)}',
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Ver Anime'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
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

class _HeroGenreChip extends StatelessWidget {
  final String genre;
  final VoidCallback onTap;

  const _HeroGenreChip({required this.genre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Text(
          genre,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

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
        final visible =
            List.generate(
              widget.items.length,
              (i) => i,
            ).where((i) => (i - _current).abs() <= 2).toList()..sort(
              (a, b) => (b - _current).abs().compareTo((a - _current).abs()),
            );
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

    final double cardW = absDist == 0
        ? cW
        : absDist == 1
        ? nW
        : fW;
    final double cardH = absDist == 0
        ? 240.0
        : absDist == 1
        ? 202.0
        : 168.0;

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

    final double opacity = absDist == 0
        ? 1.0
        : absDist == 1
        ? 0.55
        : 0.25;
    final double skewAngle = dist == 0
        ? 0.0
        : dist < 0
        ? 0.18
        : -0.18;

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
            ? () =>
                  context.push('/detail?url=${Uri.encodeComponent(anime.url)}')
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
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                        fontSize: 10,
                        color: Color(0xAAFFFFFF),
                      ),
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
                        label: '+ Lista',
                        filled: false,
                        onTap: () {},
                      ),
                      if (anime.score != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 9)),
                              const SizedBox(width: 2),
                              Text(
                                anime.score!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
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
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  const _HomeSectionHeader({
    required this.title,
    this.subtitle,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.accent2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
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

// ignore: unused_element
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
                  height: 1.3,
                ),
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
  final String? subtitle;
  final String? action;
  final String? actionRoute;
  final List<AnimeModel> list;
  final bool landscape;

  const _AnimeRow({
    required this.title,
    required this.list,
    this.subtitle,
    this.action,
    this.actionRoute,
    this.landscape = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) return const SizedBox.shrink();
    final layout = ref.watch(catalogLayoutProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeSectionHeader(
          title: title,
          subtitle: subtitle,
          action: action == '' ? null : action ?? 'Ver todo',
          onAction: () => context.go(actionRoute ?? '/search?mode=catalog'),
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
            height: landscape ? 150 : 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (context, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => landscape
                  ? _EpisodeUpdateCard(anime: list[i])
                  : AnimeCard(
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

class _EpisodeUpdateCard extends StatelessWidget {
  final AnimeModel anime;

  const _EpisodeUpdateCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push('/detail?url=${Uri.encodeComponent(anime.url)}'),
      child: SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
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
            const SizedBox(height: 7),
            Text(
              anime.type ?? 'Episodio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.accent2,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

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
  final bool landscape;

  const _HorizontalSkeleton({this.landscape = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: landscape ? 150 : 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (context, _) => const SizedBox(width: 10),
        itemBuilder: (context, _) => Column(
          children: [
            Container(
              width: landscape ? 190 : 100,
              height: landscape ? 107 : 138,
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

// ═══════════════════════════════════════════════════════════════════════════
// MonosChinos — Timeline retro
//
// Layout exclusivo del proveedor `monoschinos2.net`. No reusa el árbol de
// AnimeAV1 ni el de HentaiLA: aquí cada capítulo nuevo es una fila timeline
// con número grande tipo monospace + card landscape con poster + badges +
// género en cyan. Mira el mockup en `monoschinos_mockup.html` (opción A).
// ═══════════════════════════════════════════════════════════════════════════

/// Home de MonosChinos: timeline retro de capítulos + sección "En emisión"
/// arriba. Los colores siguen la preferencia de acento del usuario (cambia
/// dinámicamente entre Violeta, Océano, Carmesí, Esmeralda, etc.) leyendo
/// `AppColors.accent` y `AppColors.accent2` — que el ThemeData del proyecto
/// resetea cada vez que cambia el preset.
class _MonosChinosHome extends ConsumerWidget {
  const _MonosChinosHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(monosChinosHubProvider);
    final airing = ref.watch(monosChinosAiringProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(monosChinosHubProvider);
            ref.invalidate(monosChinosAiringProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _MonosHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              // Sección "En emisión" en horizontal scroll arriba de todo —
              // por pedido explícito del usuario: el contenido en emisión
              // debe estar accesible al iniciar el proveedor.
              SliverToBoxAdapter(
                child: _MonosAiringSection(asyncList: airing),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
              const SliverToBoxAdapter(child: _MonosSegmentedHeading()),
              hub.when(
                data: (data) {
                  if (data.latestEpisodes.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MonosEmpty(),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    sliver: SliverList.separated(
                      itemCount: data.latestEpisodes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) =>
                          _MonosTimelineRow(item: data.latestEpisodes[i]),
                    ),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.accent2,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No se pudo cargar el contenido',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                ref.invalidate(monosChinosHubProvider),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: BorderSide(color: AppColors.accent),
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera con logo del proveedor + título + acción a búsqueda.
class _MonosHeader extends StatelessWidget {
  const _MonosHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent2.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text('🐵', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MonosChinos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Últimos capítulos disponibles',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _MonosIconAction(
            icon: Icons.search_rounded,
            onTap: () => context.push('/search?mode=search'),
          ),
        ],
      ),
    );
  }
}

class _MonosIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonosIconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Encabezado de sección — por ahora solo "Recientes" porque el sitio no
/// expone trending/popular como secciones discretas. Si en el futuro lo hace,
/// se reemplaza por un segmented control con tres pestañas como el mockup.
class _MonosSegmentedHeading extends StatelessWidget {
  const _MonosSegmentedHeading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: const [
            Expanded(child: _MonosSegment(label: 'RECIENTES', active: true)),
            // Slots para futuros tabs cuando MonosChinos exponga POPULARES /
            // EMISIÓN como endpoints discretos.
          ],
        ),
      ),
    );
  }
}

class _MonosSegment extends StatelessWidget {
  final String label;
  final bool active;

  const _MonosSegment({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                colors: [AppColors.accent, AppColors.accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: active ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Fila del timeline: número monoespaciado a la izquierda + card landscape
/// con poster, badges y meta. Cada fila navega al detalle del anime al tocar.
class _MonosTimelineRow extends StatelessWidget {
  final MonosChinosLatestEpisode item;

  const _MonosTimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        final url = item.animeUrl ?? item.episodeUrl;
        if (url.isNotEmpty) {
          context.push('/detail?url=${Uri.encodeComponent(url)}');
        }
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonosEpisodeNumber(episode: item.episode),
            const SizedBox(width: 12),
            Expanded(child: _MonosTimelineCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class _MonosEpisodeNumber extends StatelessWidget {
  final int episode;

  const _MonosEpisodeNumber({required this.episode});

  @override
  Widget build(BuildContext context) {
    final text = episode > 0 ? episode.toString().padLeft(2, '0') : '--';
    return SizedBox(
      width: 50,
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'EPISODIO',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonosTimelineCard extends StatelessWidget {
  final MonosChinosLatestEpisode item;

  const _MonosTimelineCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: AppColors.surface2),
                  if (item.poster != null && item.poster!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.poster!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: AppColors.surface2),
                    ),
                  // Degradado inferior para que los badges flotantes y el
                  // título tengan contraste si se quisiera overlay text.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      children: [
                        _MonosBadge(
                          text: 'HD',
                          bg: AppColors.accent,
                          fg: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        _MonosBadge(
                          text: 'ESP',
                          bg: AppColors.accent2,
                          fg: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.genre != null && item.genre!.isNotEmpty) ...[
                        Text(
                          item.genre!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent2,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        'Capítulo ${item.episode}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonosBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _MonosBadge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}

class _MonosEmpty extends StatelessWidget {
  const _MonosEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Sin capítulos recientes',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Sección "En emisión" — chips horizontales de animes que están actualmente
/// transmitiendo. Visualmente más compacta que el timeline (poster vertical
/// 110×155) para que entre cómoda al inicio sin desplazar la atención de los
/// capítulos nuevos.
class _MonosAiringSection extends ConsumerWidget {
  final AsyncValue<List<AnimeModel>> asyncList;

  const _MonosAiringSection({required this.asyncList});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    colors: [AppColors.accent, AppColors.accent2],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'EN EMISIÓN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(
                  '/search?mode=catalog&domain=monoschinos2.net',
                ),
                child: Row(
                  children: [
                    Text(
                      'VER TODO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent2,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.accent2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 195,
          child: asyncList.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No hay animes en emisión.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _MonosAiringCard(anime: items[i]),
              );
            },
            loading: () => Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
            error: (_, _) => Center(
              child: Text(
                'No se pudo cargar.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonosAiringCard extends StatelessWidget {
  final AnimeModel anime;

  const _MonosAiringCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(
        '/detail?url=${Uri.encodeComponent(anime.url)}',
      ),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: anime.cover == null || anime.cover!.isEmpty
                        ? Container(color: AppColors.surface2)
                        : CachedNetworkImage(
                            imageUrl: anime.cover!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                Container(color: AppColors.surface2),
                          ),
                  ),
                  // Indicador "en vivo" arriba a la izquierda.
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EN EMISIÓN',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
