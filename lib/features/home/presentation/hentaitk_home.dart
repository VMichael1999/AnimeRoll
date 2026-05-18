import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/home_provider.dart';

/// Home dedicada de HentaiTK — diferenciada visualmente de HentaiLA (que usa
/// grid 2-col de posters verticales). Aquí el énfasis es en cards landscape
/// 16:9 (porque el sitio source usa thumbs horizontales), con un hero del
/// "Más visto de la semana" tipo banner rojo del sitio real.
///
/// El componente se monta desde `home_screen.dart` cuando
/// `ProviderId.fromDomain(activeProvider) == ProviderId.hentaitk`.
class HentaiTKHome extends ConsumerWidget {
  const HentaiTKHome({super.key});

  /// Rojo de marca de HentaiTK (banners "Estrenos", "Más visto", play-circle
  /// section). NO sigue el theme accent porque es identidad del sitio (igual
  /// que el azul de Twitter o el rojo de YouTube): si fuera dinámico, perdería
  /// la asociación visual con el origen.
  static const _brandRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(hentaitkHubProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: _brandRed,
          onRefresh: () async => ref.invalidate(hentaitkHubProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _HentaiTKHeader()),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              const SliverToBoxAdapter(child: _CategoryNav()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              hub.when(
                data: (data) {
                  final episodes = data.latestEpisodes;
                  if (episodes.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyHentaiTK(),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _HeroMostWatched(anime: episodes.first),
                      const SizedBox(height: 18),
                      _SectionBannerRed(
                        icon: Icons.calendar_month_rounded,
                        title: 'Estrenos Mayo 2026',
                      ),
                      const SizedBox(height: 12),
                      _VideoGrid(items: episodes.take(4).toList()),
                      const SizedBox(height: 18),
                      _SectionTitle(
                        icon: Icons.play_circle_rounded,
                        title: 'Hentais 2026',
                        countLabel: '+50',
                      ),
                      const SizedBox(height: 12),
                      _VideoGrid(items: episodes.skip(4).take(8).toList()),
                      const SizedBox(height: 24),
                    ]),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: _brandRed),
                    ),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorView(
                      message: 'No se pudo cargar el contenido',
                      onRetry: () => ref.invalidate(hentaitkHubProvider),
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

// ─────────────────────────────────────────────────────────────────────────────
// Header con logo estilo HentaiTK
// ─────────────────────────────────────────────────────────────────────────────

class _HentaiTKHeader extends StatelessWidget {
  const _HentaiTKHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // Logo HentaiTK con tipografía Impact-like + insignia roja .NET.
          // Mantenemos solo el "TK" en rojo porque es la identidad del sitio.
          const _HentaiTKLogo(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '13.455 videos',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _IconAction(
            icon: Icons.search_rounded,
            onTap: () => context.push('/search?mode=search'),
          ),
        ],
      ),
    );
  }
}

class _HentaiTKLogo extends StatelessWidget {
  const _HentaiTKLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'HENTAI',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -1,
            color: Colors.white,
            height: 1,
          ),
        ),
        const Text(
          'TK',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -1,
            color: HentaiTKHome._brandRed,
            height: 1,
          ),
        ),
        const SizedBox(width: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: HentaiTKHome._brandRed,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            '.NET',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav de categorías scrollable horizontal
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryNav extends StatefulWidget {
  const _CategoryNav();

  @override
  State<_CategoryNav> createState() => _CategoryNavState();
}

class _CategoryNavState extends State<_CategoryNav> {
  String _active = 'INICIO';

  // Categorías canónicas tomadas del menú del sitio real. Cada entrada lleva
  // un `label` (lo que se ve) y una `query` (slug que el backend usa como
  // genre para el catalog). null = no navega, es el "INICIO" pasivo.
  static const _items = <_CategoryItem>[
    _CategoryItem(label: 'INICIO', query: null),
    _CategoryItem(label: 'HENTAIS', query: null),
    _CategoryItem(label: 'HENTAI 2026', query: 'hentai-2026', type: true),
    _CategoryItem(label: '3D', query: '3d', brand: true),
    _CategoryItem(label: 'JAV', query: 'jav', brand: true),
    _CategoryItem(label: 'AUDIO LATINO', query: 'audio-latino', brand: true),
    _CategoryItem(label: 'SIN CENSURA', query: 'sin-censura', brand: true),
    _CategoryItem(label: 'SERIES', query: 'series'),
    _CategoryItem(label: 'LIVE ACTION', query: 'live-action'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = _items[i];
          final active = item.label == _active;
          return GestureDetector(
            onTap: () {
              setState(() => _active = item.label);
              if (item.query != null) {
                final param = item.type ? 'type' : 'genre';
                context.push(
                  '/search?mode=catalog&domain=hentaitk.net'
                  '&$param=${item.query}',
                );
              }
            },
            child: _CategoryPill(item: item, active: active),
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  final String label;
  final String? query;
  final bool brand;
  final bool type;

  const _CategoryItem({
    required this.label,
    required this.query,
    this.brand = false,
    this.type = false,
  });
}

class _CategoryPill extends StatelessWidget {
  final _CategoryItem item;
  final bool active;

  const _CategoryPill({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    final Color bg;
    final Color border;
    final Color fg;

    if (active) {
      bg = accent;
      border = Colors.transparent;
      fg = Colors.white;
    } else if (item.brand) {
      bg = HentaiTKHome._brandRed.withValues(alpha: 0.12);
      border = HentaiTKHome._brandRed.withValues(alpha: 0.4);
      fg = HentaiTKHome._brandRed;
    } else {
      bg = AppColors.surface;
      border = AppColors.border;
      fg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Text(
        item.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero: "Video más visto de la semana"
// ─────────────────────────────────────────────────────────────────────────────

class _HeroMostWatched extends StatelessWidget {
  final AnimeModel anime;

  const _HeroMostWatched({required this.anime});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: AppColors.surface),
              if (anime.cover != null && anime.cover!.isNotEmpty)
                AppNetworkImage(url: anime.cover, fit: BoxFit.cover),
              // Gradient inferior para que el banner rojo y el título tengan
              // contraste.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                    colors: [Colors.transparent, Color(0xFF0D0612)],
                  ),
                ),
              ),
              // Banner rojo superior
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  color: HentaiTKHome._brandRed,
                  child: Row(
                    children: const [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'MÁS VISTO DE LA SEMANA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Título + meta abajo
              Positioned(
                left: 16,
                right: 60,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón play FAB
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () => context.push(
                    '/detail?url=${Uri.encodeComponent(anime.url)}',
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
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

// ─────────────────────────────────────────────────────────────────────────────
// Section headers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionBannerRed extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionBannerRed({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: HentaiTKHome._brandRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? countLabel;

  const _SectionTitle({
    required this.icon,
    required this.title,
    this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: HentaiTKHome._brandRed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (countLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                countLabel!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid 2-col de videos
// ─────────────────────────────────────────────────────────────────────────────

class _VideoGrid extends StatelessWidget {
  final List<AnimeModel> items;

  const _VideoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 162,
        ),
        itemBuilder: (_, i) => _VideoCard(anime: items[i]),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final AnimeModel anime;

  const _VideoCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(
        '/detail?url=${Uri.encodeComponent(anime.url)}',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
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
                    if (anime.cover != null && anime.cover!.isNotEmpty)
                      AppNetworkImage(url: anime.cover, fit: BoxFit.cover),
                    if (anime.type != null && anime.type!.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _MiniBadge(label: anime.type!.toUpperCase()),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (anime.genres.isNotEmpty)
                        Text(
                          anime.genres.first.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.secondary,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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

class _MiniBadge extends StatelessWidget {
  final String label;

  const _MiniBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: HentaiTKHome._brandRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHentaiTK extends StatelessWidget {
  const _EmptyHentaiTK();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Sin videos disponibles',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
