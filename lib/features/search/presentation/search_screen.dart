import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/widgets/error_view.dart';
import '../../settings/data/settings_provider.dart';
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
    final mode = ref.watch(searchModeProvider);
    final activeProvider = ref.watch(providerPrefProvider);
    final isHentaila = activeProvider == 'hentaila.com';
    final effectiveMode = isHentaila ? SearchMode.catalog : mode;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isHentaila ? 'Catalogo de Hentai' : 'Buscar',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!isHentaila)
                        _ModeButton(
                          label: 'Buscar',
                          active: mode == SearchMode.search,
                          onTap: () =>
                              ref.read(searchModeProvider.notifier).state =
                                  SearchMode.search,
                        ),
                      if (!isHentaila) const SizedBox(width: 8),
                      if (!isHentaila)
                        _ModeButton(
                          label: 'Catálogo',
                          active: mode == SearchMode.catalog,
                          onTap: () =>
                              ref.read(searchModeProvider.notifier).state =
                                  SearchMode.catalog,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (effectiveMode == SearchMode.search)
                    _SearchHeader(
                      controller: _controller,
                      isHentaila: isHentaila,
                    )
                  else
                    const _CatalogHeader(),
                ],
              ),
            ),
            Expanded(
              child: effectiveMode == SearchMode.search
                  ? _SearchResults(controller: _controller)
                  : const _CatalogResults(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends ConsumerWidget {
  final TextEditingController controller;
  final bool isHentaila;

  const _SearchHeader({required this.controller, required this.isHentaila});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDomain = ref.watch(domainProvider);
    return Column(
      children: [
        _SearchInput(
          controller: controller,
          onChanged: (v) => ref.read(queryProvider.notifier).state = v,
          hintText: isHentaila
              ? 'Buscar en HentaiLA...'
              : 'Buscar anime, genero...',
        ),
        if (isHentaila)
          const _ProviderModeBadge()
        else ...[
          const SizedBox(height: 10),
          _ProviderFilter(
            selected: selectedDomain,
            onSelect: (d) => ref.read(domainProvider.notifier).state = d,
          ),
        ],
      ],
    );
  }
}

class _CatalogHeader extends ConsumerWidget {
  const _CatalogHeader();

  static const _letters = [
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(catalogLetterProvider);
    final filters = ref.watch(catalogFiltersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _letters.map((letter) {
                final active = selected == letter;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      ref.read(catalogLetterProvider.notifier).state = letter,
                  child: Container(
                    width: 34,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent2 : AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? AppColors.accent2 : AppColors.border,
                      ),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              selected == '#' ? 'Todos' : 'Letra $selected',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _showCatalogFilters(context, ref),
              icon: Icon(
                filters.isActive
                    ? Icons.filter_alt_rounded
                    : Icons.filter_list_rounded,
                size: 18,
              ),
              label: const Text('Filtros'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final TextEditingController controller;

  const _SearchResults({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    return results.when(
      data: (list) {
        if (controller.text.isEmpty) return const _EmptyState();
        if (list.isEmpty) return const _NoResults();
        return _ResultsGrid(list: list);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'No se pudo buscar. Intenta nuevamente.',
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
    );
  }
}

class _CatalogResults extends ConsumerWidget {
  const _CatalogResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(catalogResultsProvider);
    return results.when(
      data: (list) {
        if (list.isEmpty) return const _NoResults();
        return _ResultsGrid(list: list);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'No se pudo cargar el catálogo.',
        onRetry: () => ref.invalidate(catalogResultsProvider),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.accent2 : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.accent2 : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SearchInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const _SearchInput({
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
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
              controller: widget.controller,
              onChanged: widget.onChanged,
              autofocus: true,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                isDense: true,
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                widget.onChanged('');
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

class _ProviderModeBadge extends StatelessWidget {
  const _ProviderModeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_person_rounded, size: 16, color: AppColors.accent2),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo HentaiLA activo',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
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
    'animeav1.com': 'AnimeAV1',
    'monoschinos2.com': 'MonosChinos',
    'tioanime.com': 'TioAnime',
    'jkanime.net': 'JKAnime',
    'animeflv.net': 'AnimeFLV',
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
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
                      child: Stack(
                        children: [
                          Positioned.fill(
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
                          if (anime.type != null)
                            Positioned(
                              left: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  anime.type!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
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

void _showCatalogFilters(BuildContext context, WidgetRef ref) {
  final isHentaila = ref.read(providerPrefProvider) == 'hentaila.com';
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _CatalogFilterSheet(
      initialFilters: ref.read(catalogFiltersProvider),
      isHentaila: isHentaila,
      onApply: (filters) {
        ref.read(catalogFiltersProvider.notifier).state = filters;
      },
    ),
  );
}

class _CatalogFilterSheet extends StatefulWidget {
  final CatalogFilters initialFilters;
  final bool isHentaila;
  final ValueChanged<CatalogFilters> onApply;

  const _CatalogFilterSheet({
    required this.initialFilters,
    required this.isHentaila,
    required this.onApply,
  });

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  static const _types = ['TV Anime', 'Película', 'OVA', 'ONA', 'Especial'];
  static const _genres = [
    'Acción',
    'Aventura',
    'Comedia',
    'Drama',
    'Fantasía',
    'Romance',
    'Shounen',
    'Slice of Life',
  ];
  static const _hentailaTypes = ['OVA'];
  static const _hentailaGenres = [
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
    'Ninjas',
    'Orgias',
    'Romance',
    'Shota',
    'Softcore',
    'Succubus',
    'Teacher',
    'Tentaculos',
    'Tetonas',
    'Vanilla',
  ];
  static const _years = ['2026', '2025', '2024', '2023', '2022', '2021'];
  static const _statuses = ['En emisión', 'Finalizado', 'Próximamente'];
  static const _sorts = ['Predeterminado', 'Nombre', 'Recientes'];

  late CatalogFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtrar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FilterDropdown(
            label: 'Tipo',
            value: _draft.type,
            values: widget.isHentaila ? _hentailaTypes : _types,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                type: value,
                clearType: value == null,
              ),
            ),
          ),
          _FilterDropdown(
            label: 'Género',
            value: _draft.genre,
            values: widget.isHentaila ? _hentailaGenres : _genres,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                genre: value,
                clearGenre: value == null,
              ),
            ),
          ),
          _FilterDropdown(
            label: 'Año',
            value: _draft.year,
            values: _years,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                year: value,
                clearYear: value == null,
              ),
            ),
          ),
          _FilterDropdown(
            label: 'Estado',
            value: _draft.status,
            values: _statuses,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                status: value,
                clearStatus: value == null,
              ),
            ),
          ),
          _FilterDropdown(
            label: 'Ordenar por',
            value: _draft.sort,
            values: _sorts,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(
                sort: value == 'Predeterminado' ? null : value,
                clearSort: value == null || value == 'Predeterminado',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                widget.onApply(_draft);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3BE2D0),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Filtrar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: AppColors.surface2,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        hint: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label: '),
              const TextSpan(
                text: 'Seleccionar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('$label: Seleccionar'),
          ),
          ...values.map(
            (item) => DropdownMenuItem<String?>(
              value: item,
              child: Text('$label: $item'),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
