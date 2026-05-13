import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/widgets/error_view.dart';
import '../data/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final selectedDomain = ref.watch(domainProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buscar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _SearchInput(
                    controller: _controller,
                    onChanged: (v) {
                      ref.read(queryProvider.notifier).state = v;
                    },
                  ),
                  const SizedBox(height: 10),
                  _ProviderFilter(
                    selected: selectedDomain,
                    onSelect: (d) =>
                        ref.read(domainProvider.notifier).state = d,
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.when(
                data: (list) {
                  if (_controller.text.isEmpty) return const _EmptyState();
                  if (list.isEmpty) return const _NoResults();
                  return _ResultsGrid(list: list);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message:
                      'Error al buscar. Verifica que la API esté corriendo.',
                  onRetry: () => ref.invalidate(searchResultsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchInput({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
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
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Buscar anime, género...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _ProviderFilter({required this.selected, required this.onSelect});

  static const _labels = {
    null: 'Todos',
    'animeflv.net': 'AnimeFLV',
    'animeav1.com': 'AnimeAV1',
    'tioanime.com': 'TioAnime',
    'jkanime.net': 'JKAnime',
    'monoschinos2.com': 'MonosChinos',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _labels.entries.map((e) {
          final active = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : AppColors.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? AppColors.accent2 : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final List<AnimeModel> list;
  const _ResultsGrid({required this.list});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '${list.length} resultados',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final anime = list[i];
              return GestureDetector(
                onTap: () => context.push(
                  '/detail?url=${Uri.encodeComponent(anime.url)}',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: anime.cover != null
                            ? Image.network(
                                anime.cover!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, url, _) =>
                                    const _CoverPlaceholder(),
                              )
                            : const _CoverPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      anime.title,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.movie_outlined, color: AppColors.border, size: 24),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'Escribe para buscar anime',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sentiment_dissatisfied_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
