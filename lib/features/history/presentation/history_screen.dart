import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../../downloads/data/downloads_provider.dart';
import '../data/watch_history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(watchHistoryProvider);
    final downloads = ref.watch(downloadsProvider);
    final visible = history.where(_matchesQuery).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => context.go('/home'),
                    icon: Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Historial',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Limpiar historial',
                    onPressed: history.isEmpty
                        ? null
                        : () => _confirmClear(context, ref),
                    icon: Icon(Icons.delete_sweep_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar en historial...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyHistory(hasQuery: _query.trim().isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: visible.length,
                      separatorBuilder: (context, _) =>
                          Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return _HistoryTile(
                          item: item,
                          onTap: () => _openItem(context, item, downloads),
                          onDelete: () => ref
                              .read(watchHistoryProvider.notifier)
                              .remove(item.episodeUrl),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesQuery(WatchHistoryEntry item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.animeTitle.toLowerCase().contains(query) ||
        item.episodeTitle.toLowerCase().contains(query);
  }

  void _openItem(
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

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Limpiar historial'),
        content: const Text('Se eliminará todo el progreso guardado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(watchHistoryProvider.notifier).clear();
    }
  }
}

class _HistoryTile extends StatelessWidget {
  final WatchHistoryEntry item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (item.percent * 100).round().clamp(0, 100);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 70,
                child: item.thumbnail == null
                    ? ColoredBox(color: AppColors.surface2)
                    : CachedNetworkImage(
                        imageUrl: item.thumbnail!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
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
                    item.animeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.episodeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    minHeight: 4,
                    value: item.percent.clamp(0.0, 1.0),
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                      item.completed ? AppColors.success : AppColors.accent2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.completed ? 'Completado' : '$percent% visto',
                    style: TextStyle(
                      fontSize: 10,
                      color: item.completed
                          ? AppColors.success
                          : AppColors.accent2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Eliminar',
              onPressed: onDelete,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool hasQuery;

  const _EmptyHistory({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        hasQuery ? 'Sin resultados' : 'Aún no hay historial',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
