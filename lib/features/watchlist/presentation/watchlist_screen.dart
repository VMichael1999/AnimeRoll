import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anime_model.dart';
import '../../../shared/models/watch_status.dart';
import '../data/watchlist_provider.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _statuses = WatchStatus.values;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(watchlistProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Mi Lista',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.accent2,
              labelColor: AppColors.accent2,
              unselectedLabelColor: AppColors.textSecondary,
              dividerColor: AppColors.border,
              tabs: _statuses
                  .map(
                    (s) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(s.icon, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            s.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _CountBadge(
                            count: entries
                                .where((e) => e.status == s)
                                .length,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: _statuses
                    .map(
                      (s) => _WatchlistTab(
                        entries: entries.where((e) => e.status == s).toList(),
                        status: s,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _WatchlistTab extends ConsumerWidget {
  final List<WatchlistEntry> entries;
  final WatchStatus status;

  const _WatchlistTab({required this.entries, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              'Sin animes en "${status.label}"',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) =>
          _WatchlistCard(entry: entries[i], ref: ref),
    );
  }
}

class _WatchlistCard extends StatelessWidget {
  final WatchlistEntry entry;
  final WidgetRef ref;

  const _WatchlistCard({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context) {
    final anime = entry.anime;
    return InkWell(
      onTap: () => context.push(
        '/detail?url=${Uri.encodeComponent(anime.url)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: anime.cover ?? '',
                width: 52,
                height: 74,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surface2,
                  width: 52,
                  height: 74,
                ),
                errorWidget: (context, url, err) => Container(
                  color: AppColors.surface2,
                  width: 52,
                  height: 74,
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.border,
                  ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (anime.type != null || anime.year != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (anime.type != null) anime.type!,
                        if (anime.year != null) anime.year!,
                        if (anime.episodeCount != null)
                          '${anime.episodeCount} eps',
                      ].join(' • '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: entry.status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: entry.status.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(entry.status.icon, size: 11, color: entry.status.color),
                        const SizedBox(width: 4),
                        Text(
                          entry.status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: entry.status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              color: AppColors.textSecondary,
              onPressed: () => _showOptions(context, anime),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, AnimeModel anime) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ...WatchStatus.values.map(
            (s) => ListTile(
              leading: Icon(s.icon, color: s.color, size: 20),
              title: Text(s.label),
              selected: s == entry.status,
              selectedColor: s.color,
              onTap: () {
                Navigator.pop(context);
                ref.read(watchlistProvider.notifier).setStatus(anime, s);
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            title: const Text(
              'Quitar de la lista',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () {
              Navigator.pop(context);
              ref.read(watchlistProvider.notifier).remove(anime.url);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
