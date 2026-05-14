import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../data/downloads_provider.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  String? _selectedAlbumKey;

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final albums = _DownloadAlbum.fromDownloads(downloads);
    final selectedAlbum = _selectedAlbumKey == null
        ? null
        : albums.where((album) => album.key == _selectedAlbumKey).firstOrNull;

    if (selectedAlbum == null && _selectedAlbumKey != null) {
      _selectedAlbumKey = null;
    }

    return Scaffold(
      body: SafeArea(
        child: selectedAlbum == null
            ? _AlbumLibrary(
                albums: albums,
                downloads: downloads,
                onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
                onOpenAlbum: (album) =>
                    setState(() => _selectedAlbumKey = album.key),
              )
            : _AlbumDetail(
                album: selectedAlbum,
                onBack: () => setState(() => _selectedAlbumKey = null),
              ),
      ),
    );
  }
}

class _AlbumLibrary extends StatelessWidget {
  final List<_DownloadAlbum> albums;
  final List<DownloadModel> downloads;
  final VoidCallback onRefresh;
  final ValueChanged<_DownloadAlbum> onOpenAlbum;

  const _AlbumLibrary({
    required this.albums,
    required this.downloads,
    required this.onRefresh,
    required this.onOpenAlbum,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Descargas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Biblioteca local en Videos/AnimeRoll del movil',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        _StorageBar(downloads: downloads),
        const SizedBox(height: 16),
        Expanded(
          child: albums.isEmpty
              ? const _EmptyDownloads()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.66,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (context, index) => _AlbumCard(
                    album: albums[index],
                    onTap: () => onOpenAlbum(albums[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AlbumDetail extends ConsumerWidget {
  final _DownloadAlbum album;
  final VoidCallback onBack;

  const _AlbumDetail({required this.album, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              Expanded(
                child: Text(
                  album.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Eliminar album',
                onPressed: () => _confirmDeleteAlbum(context, ref),
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 102,
                  child: _CoverImage(url: album.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${album.items.length} episodios',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${album.savedCount} guardados en el movil',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: album.items.length,
            separatorBuilder: (context, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final download = album.items[index];
              return _DownloadDismissTile(
                download: download,
                onPlay: () => _openPlayer(context, download),
                onDelete: () => ref
                    .read(downloadsProvider.notifier)
                    .removeDownload(download.id),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openPlayer(BuildContext context, DownloadModel download) {
    if (!download.isSavedOnDevice || download.localPath == null) return;
    context.push(
      '/download-player?id=${Uri.encodeComponent(download.id)}&title=${Uri.encodeComponent(download.displayEpisodeTitle)}&path=${Uri.encodeComponent(download.localPath!)}&animeTitle=${Uri.encodeComponent(download.albumTitle)}',
    );
  }

  Future<void> _confirmDeleteAlbum(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar album'),
        content: Text(
          'Se eliminaran ${album.items.length} episodios descargados de ${album.title}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(downloadsProvider.notifier).removeAlbum(album.key);
    if (context.mounted) onBack();
  }
}

class _StorageBar extends StatelessWidget {
  final List<DownloadModel> downloads;

  const _StorageBar({required this.downloads});

  @override
  Widget build(BuildContext context) {
    final saved = downloads.where((item) => item.isSavedOnDevice).length;
    final progress = downloads.isEmpty ? 0.0 : saved / downloads.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Videos guardados', style: TextStyle(fontSize: 11)),
              Text(
                '$saved / ${downloads.length}',
                style: const TextStyle(fontSize: 11, color: AppColors.accent2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final _DownloadAlbum album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _CoverImage(url: album.cover),
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
                    decoration: const BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      '${album.savedCount}/${album.items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DownloadDismissTile extends StatelessWidget {
  final DownloadModel download;
  final VoidCallback onPlay;
  final Future<void> Function() onDelete;

  const _DownloadDismissTile({
    required this.download,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(download.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(width: 8),
            Icon(Icons.delete_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      child: _DownloadTile(download: download, onTap: onPlay),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar descarga'),
        content: Text('Se eliminara ${download.displayEpisodeTitle}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadModel download;
  final VoidCallback onTap;

  const _DownloadTile({required this.download, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final failed =
        download.status == 'failed' || download.localStatus == 'failed';
    final completed = download.status == 'completed';
    final saving = download.localStatus == 'saving';
    final saved = download.isSavedOnDevice;

    return InkWell(
      onTap: saved ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 68,
                    height: 42,
                    child: _CoverImage(url: download.thumbnail),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.displayEpisodeTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _statusText(download, saved, saving, completed, failed),
                        style: TextStyle(
                          fontSize: 10,
                          color: failed
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      saved
                          ? Icons.play_circle_fill_rounded
                          : Icons.download_rounded,
                      color: saved
                          ? AppColors.accent2
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      saved
                          ? 'Ver'
                          : saving
                          ? '${download.localProgress}%'
                          : completed
                          ? 'Listo'
                          : failed
                          ? 'Error'
                          : '${download.progress}%',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: saving
                    ? download.localProgress / 100
                    : download.progress / 100,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(
                  failed ? Colors.redAccent : AppColors.accent,
                ),
                minHeight: 5,
              ),
            ),
            if (saved) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Toca para reproducir descargado',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(
    DownloadModel download,
    bool saved,
    bool saving,
    bool completed,
    bool failed,
  ) {
    if (failed) return download.error ?? 'Error desconocido';
    if (saved) return 'Guardado en Videos/AnimeRoll';
    if (saving) return 'Guardando en el movil...';
    if (completed) return 'Listo para guardar';
    return '${download.quality} · ${download.variant}${download.currentServer != null ? ' · ${download.currentServer}' : ''}';
  }
}

class _CoverImage extends StatelessWidget {
  final String? url;

  const _CoverImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _DownloadPlaceholder();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (context, url, error) => const _DownloadPlaceholder(),
      placeholder: (context, url) =>
          const ColoredBox(color: AppColors.surface2),
    );
  }
}

class _DownloadPlaceholder extends StatelessWidget {
  const _DownloadPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.video_library_rounded, color: AppColors.border),
      ),
    );
  }
}

class _DownloadAlbum {
  final String key;
  final String title;
  final String? cover;
  final List<DownloadModel> items;

  const _DownloadAlbum({
    required this.key,
    required this.title,
    required this.cover,
    required this.items,
  });

  int get savedCount => items.where((item) => item.isSavedOnDevice).length;

  static List<_DownloadAlbum> fromDownloads(List<DownloadModel> downloads) {
    final grouped = <String, List<DownloadModel>>{};
    for (final download in downloads) {
      grouped.putIfAbsent(download.albumKey, () => []).add(download);
    }

    final albums = grouped.entries.map((entry) {
      final items = [
        ...entry.value,
      ]..sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
      return _DownloadAlbum(
        key: entry.key,
        title: items.first.albumTitle,
        cover: items.first.thumbnail,
        items: items,
      );
    }).toList();

    albums.sort((a, b) => a.title.compareTo(b.title));
    return albums;
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Sin descargas',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Tus albumes apareceran cuando descargues episodios',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
