// coverage:ignore-file
// CineHax home — proveedor VIP de películas y series (TMDB-backed).
//
// Diferencia del home genérico: tema azul oscuro / cyan, secciones derivadas
// del hub (`cinehaxHubProvider`) con filas horizontales por género, hero
// destacado en la parte superior y tabs (Inicio · Tendencias · Películas ·
// Series) que reordenan o filtran lo que se ve.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/cinehax_hub.dart';
import '../../../shared/utils/network_error.dart';
import '../../../shared/widgets/app_shimmers.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/no_connection_empty.dart';
import '../data/home_provider.dart';

// ── Paleta CineHax ────────────────────────────────────────────────────────────
const _cinehaxBg = Color(0xFF06101E);
const _cinehaxSurface = Color(0xFF0D1A2E);
const _cinehaxBlue = Color(0xFF2B8BFF);
const _cinehaxGold = Color(0xFFFFB820);
const _cinehaxMuted = Color(0xFFA08BB8);

class CinehaxHome extends ConsumerStatefulWidget {
  const CinehaxHome({super.key});

  @override
  ConsumerState<CinehaxHome> createState() => _CinehaxHomeState();
}

class _CinehaxHomeState extends ConsumerState<CinehaxHome> {
  /// Tab activa. Se mapea a un filtro sobre las secciones del hub.
  _CinehaxTab _tab = _CinehaxTab.inicio;

  @override
  Widget build(BuildContext context) {
    final hubAsync = ref.watch(cinehaxHubProvider);

    return Scaffold(
      backgroundColor: _cinehaxBg,
      body: SafeArea(
        child: hubAsync.when(
          loading: () => Column(
            children: const [
              SizedBox(height: 12),
              _Header(),
              SizedBox(height: 42),
              Expanded(child: HomeFeedSkeleton(rowCount: 4)),
            ],
          ),
          error: (err, _) => isNetworkError(err)
              ? NoConnectionEmpty(
                  onRetry: () => ref.invalidate(cinehaxHubProvider),
                )
              : ErrorView(
                  message: 'No se pudo cargar CineHax',
                  onRetry: () => ref.invalidate(cinehaxHubProvider),
                ),
          data: (hub) => _buildBody(context, hub),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CinehaxHubData hub) {
    final sections = _filterSections(hub.sections, _tab);
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(child: _Header()),
        SliverToBoxAdapter(
          child: _Tabs(
            active: _tab,
            onChange: (next) => setState(() => _tab = next),
          ),
        ),
        if (hub.hero != null)
          SliverToBoxAdapter(child: _Hero(item: hub.hero!)),
        for (final section in sections)
          SliverToBoxAdapter(child: _SectionRow(section: section)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// Filtra las secciones del hub según la tab activa. "Inicio" muestra todas;
  /// "Películas" y "Series" filtran por type; "Tendencias" prioriza secciones
  /// marcadas como trending o top-rated.
  List<CinehaxSection> _filterSections(
    List<CinehaxSection> all,
    _CinehaxTab tab,
  ) {
    return switch (tab) {
      _CinehaxTab.inicio => all,
      _CinehaxTab.peliculas => all.where((s) => s.type == 'movie').toList(),
      _CinehaxTab.series => all.where((s) => s.type == 'tv').toList(),
      _CinehaxTab.tendencias => all
          .where((s) =>
              s.sort == 'trending' ||
              s.sort == 'top-rated' ||
              s.id.contains('top'))
          .toList(),
    };
  }
}

enum _CinehaxTab { inicio, tendencias, peliculas, series }

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Colors.white,
                  fontFamily: 'Impact',
                ),
                children: [
                  TextSpan(text: 'CINE'),
                  TextSpan(
                    text: 'HAX',
                    style: TextStyle(color: _cinehaxBlue),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/search'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _cinehaxSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: _cinehaxMuted,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _cinehaxSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _cinehaxMuted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _Tabs extends StatelessWidget {
  final _CinehaxTab active;
  final ValueChanged<_CinehaxTab> onChange;
  const _Tabs({required this.active, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (_CinehaxTab.inicio, 'Inicio', Icons.home_outlined),
      (_CinehaxTab.tendencias, 'Tendencias', Icons.local_fire_department_rounded),
      (_CinehaxTab.peliculas, 'Películas', Icons.movie_outlined),
      (_CinehaxTab.series, 'Series', Icons.tv_rounded),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (context, idx) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final item = items[i];
          final isActive = item.$1 == active;
          return InkWell(
            onTap: () => onChange(item.$1),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isActive ? _cinehaxSurface : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? _cinehaxBlue.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.$3,
                    size: 14,
                    color: isActive ? Colors.white : _cinehaxMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : _cinehaxMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final AnimeModel item;
  const _Hero({required this.item});

  @override
  Widget build(BuildContext context) {
    final cover = item.cover ?? '';
    return GestureDetector(
      onTap: () => context.push(
        '/detail?url=${Uri.encodeComponent(item.url)}',
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        height: 244,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _cinehaxSurface,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                placeholder: (context, idx) => const ColoredBox(color: _cinehaxSurface),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: _cinehaxSurface),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _cinehaxBg.withValues(alpha: 0.95),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _cinehaxBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _heroChipLabel(item),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.score != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: _cinehaxGold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.score!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.genres.isNotEmpty)
                          Flexible(
                            child: Text(
                              item.genres.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _cinehaxBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Ver ahora',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _heroChipLabel(AnimeModel item) {
    final type = (item.type ?? '').toUpperCase();
    if (item.year != null && type.isNotEmpty) {
      return '$type · ${item.year}';
    }
    if (type.isNotEmpty) return type;
    if (item.year != null) return 'ESTRENO ${item.year}';
    return 'DESTACADO';
  }
}

// ── Section row ───────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final CinehaxSection section;
  const _SectionRow({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    section.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.push(
                    '/cinehax/section?id=${Uri.encodeComponent(section.id)}'
                    '&label=${Uri.encodeComponent(section.label)}'
                    '&type=${section.type}'
                    '${section.genre != null ? '&genre=${section.genre}' : ''}'
                    '${section.sort != null ? '&sort=${section.sort}' : ''}',
                  ),
                  child: Row(
                    children: const [
                      Text(
                        'Ver todo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _cinehaxBlue,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: _cinehaxBlue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: section.items.length,
              separatorBuilder: (context, idx) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final item = section.items[i];
                return _PosterCard(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Poster card ───────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  final AnimeModel item;
  const _PosterCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cover = item.cover ?? '';
    return GestureDetector(
      onTap: () => context.push(
        '/detail?url=${Uri.encodeComponent(item.url)}',
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
                    child: cover.isEmpty
                        ? const ColoredBox(color: _cinehaxSurface)
                        : CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            placeholder: (context, idx) =>
                                const ColoredBox(color: _cinehaxSurface),
                            errorWidget: (context, url, error) =>
                                const ColoredBox(color: _cinehaxSurface),
                          ),
                  ),
                  if (item.score != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _ScoreBadge(score: item.score!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 7
        ? const Color(0xFF10B981) // green
        : score >= 5
            ? const Color(0xFFF59E0B) // amber
            : const Color(0xFFEF4444); // red
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.78),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
