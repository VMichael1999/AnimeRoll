// coverage:ignore-file
// "Ver todo" de una sección de CineHax. Grid 3-col con scroll infinito,
// mismo styling que el home (azul oscuro + cyan). El backend pagina por TMDB,
// así que vamos sumando páginas hasta `totalPages`.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/utils/network_error.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_shimmers.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/no_connection_empty.dart';
import '../data/home_provider.dart';

const _bg = Color(0xFF06101E);
const _surface = Color(0xFF0D1A2E);
const _blue = Color(0xFF2B8BFF);
const _muted = Color(0xFFA08BB8);

class CinehaxSectionScreen extends ConsumerStatefulWidget {
  final String sectionId;
  final String label;
  final String type;
  final String? genre;
  final String? sort;

  const CinehaxSectionScreen({
    super.key,
    required this.sectionId,
    required this.label,
    required this.type,
    this.genre,
    this.sort,
  });

  @override
  ConsumerState<CinehaxSectionScreen> createState() =>
      _CinehaxSectionScreenState();
}

class _CinehaxSectionScreenState extends ConsumerState<CinehaxSectionScreen> {
  final List<AnimeModel> _items = [];
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _failed = false;
  bool _lastErrorIsNetwork = false;

  @override
  void initState() {
    super.initState();
    _fetchPage(initial: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _page >= _totalPages) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 320) {
      _fetchPage();
    }
  }

  Future<void> _fetchPage({bool initial = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (initial) _failed = false;
    });
    try {
      final repo = ref.read(animeRepositoryProvider);
      final res = await repo.cinehaxCatalog(
        type: widget.type,
        genre: widget.genre,
        sort: widget.sort ?? 'popular',
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _totalPages = res.totalPages;
        _page += 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (initial) {
          _failed = true;
          _lastErrorIsNetwork = isNetworkError(error);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _failed && _items.isEmpty
            ? (_lastErrorIsNetwork
                ? NoConnectionEmpty(
                    onRetry: () {
                      setState(() {
                        _page = 1;
                        _items.clear();
                      });
                      _fetchPage(initial: true);
                    },
                  )
                : ErrorView(
                    message: 'No se pudo cargar la sección',
                    onRetry: () {
                      setState(() {
                        _page = 1;
                        _items.clear();
                      });
                      _fetchPage(initial: true);
                    },
                  ))
            : CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _Header(label: widget.label)),
                  if (_items.isEmpty && _loading)
                    const SliverToBoxAdapter(
                      child: PosterGridSkeleton(count: 9),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.56,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, i) =>
                            _PosterTile(item: _items[i]),
                      ),
                    ),
                  if (_loading && _items.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: AppLoading(color: _blue, size: 42),
                      ),
                    )
                  else if (_page > _totalPages || _items.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No hay más resultados',
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String label;
  const _Header({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'CineHax',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: _muted,
                ),
                SizedBox(width: 5),
                Text(
                  'Popular',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _muted,
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

class _PosterTile extends StatelessWidget {
  final AnimeModel item;
  const _PosterTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cover = item.cover ?? '';
    return GestureDetector(
      onTap: () => context.push(
        '/detail?url=${Uri.encodeComponent(item.url)}',
      ),
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
                      ? const ColoredBox(color: _surface)
                      : CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          placeholder: (context, idx) =>
                              const ColoredBox(color: _surface),
                          errorWidget: (context, url, error) =>
                              const ColoredBox(color: _surface),
                        ),
                ),
                if (item.score != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _Score(score: item.score!),
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
    );
  }
}

class _Score extends StatelessWidget {
  final double score;
  const _Score({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 7
        ? const Color(0xFF10B981)
        : score >= 5
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.78),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
