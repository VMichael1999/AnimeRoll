import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../data/downloads_provider.dart';

enum _DownloadTab { saved, active, errors }

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _DownloadTab _tab = _DownloadTab.saved;

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final albums = _DownloadAlbum.fromDownloads(downloads);
    final active = downloads
        .where((item) => item.isRunning || item.isLocalRunning)
        .toList();
    final errors = downloads
        .where(
          (item) => item.status == 'failed' || item.localStatus == 'failed',
        )
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DownloadsHeader(
              downloads: downloads,
              onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
            ),
            _DownloadStats(downloads: downloads),
            const SizedBox(height: 12),
            _DownloadTabs(
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            Expanded(
              child: switch (_tab) {
                _DownloadTab.saved => _AlbumLibrary(
                  albums: albums,
                  onOpenAlbum: (album) => _openAlbumPlayer(context, album),
                ),
                _DownloadTab.active => _DownloadQueue(
                  downloads: active,
                  emptyText: 'No hay descargas en curso',
                ),
                _DownloadTab.errors => _DownloadQueue(
                  downloads: errors,
                  emptyText: 'Sin errores de descarga',
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAlbumPlayer(BuildContext context, _DownloadAlbum album) {
    final download = album.firstPlayable;
    if (download?.localPath == null) return;
    context.push(
      '/download-player?id=${Uri.encodeComponent(download!.id)}&title=${Uri.encodeComponent(download.displayEpisodeTitle)}&path=${Uri.encodeComponent(download.localPath!)}&animeTitle=${Uri.encodeComponent(download.albumTitle)}',
    );
  }
}

class _DownloadsHeader extends StatelessWidget {
  final List<DownloadModel> downloads;
  final VoidCallback onRefresh;

  const _DownloadsHeader({required this.downloads, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final active = downloads
        .where((item) => item.isRunning || item.isLocalRunning)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Descargas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (active > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$active activas',
                style: const TextStyle(
                  color: AppColors.accent2,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _DownloadStats extends StatelessWidget {
  final List<DownloadModel> downloads;

  const _DownloadStats({required this.downloads});

  @override
  Widget build(BuildContext context) {
    final active = downloads
        .where((item) => item.isRunning || item.isLocalRunning)
        .length;
    final saved = downloads.where((item) => item.isSavedOnDevice).length;
    final errors = downloads
        .where(
          (item) => item.status == 'failed' || item.localStatus == 'failed',
        )
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '$active',
              label: 'Activas',
              color: AppColors.accent2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              value: '$saved',
              label: 'Guardados',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              value: '$errors',
              label: 'Errores',
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTabs extends StatelessWidget {
  final _DownloadTab selected;
  final ValueChanged<_DownloadTab> onChanged;

  const _DownloadTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _TabButton(
            label: 'Guardados',
            active: selected == _DownloadTab.saved,
            onTap: () => onChanged(_DownloadTab.saved),
          ),
          _TabButton(
            label: 'En curso',
            active: selected == _DownloadTab.active,
            onTap: () => onChanged(_DownloadTab.active),
          ),
          _TabButton(
            label: 'Errores',
            active: selected == _DownloadTab.errors,
            onTap: () => onChanged(_DownloadTab.errors),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.accent2 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.accent2 : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumLibrary extends StatelessWidget {
  final List<_DownloadAlbum> albums;
  final ValueChanged<_DownloadAlbum> onOpenAlbum;

  const _AlbumLibrary({required this.albums, required this.onOpenAlbum});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const _EmptyDownloads();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
    );
  }
}

class _DownloadQueue extends StatelessWidget {
  final List<DownloadModel> downloads;
  final String emptyText;

  const _DownloadQueue({required this.downloads, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (downloads.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: downloads.length,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _DownloadQueueTile(download: downloads[index]),
    );
  }
}

class _DownloadQueueTile extends StatelessWidget {
  final DownloadModel download;

  const _DownloadQueueTile({required this.download});

  @override
  Widget build(BuildContext context) {
    final failed =
        download.status == 'failed' || download.localStatus == 'failed';
    final progress = download.localStatus == 'saving'
        ? download.localProgress
        : download.progress;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 40,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      failed
                          ? download.error ?? 'Error desconocido'
                          : '${download.quality} - ${download.variant}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: failed
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                failed ? 'Error' : '$progress%',
                style: TextStyle(
                  fontSize: 11,
                  color: failed ? AppColors.error : AppColors.accent2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 100) / 100,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                failed ? AppColors.error : AppColors.accent2,
              ),
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

  DownloadModel? get firstPlayable =>
      items.where((item) => item.isSavedOnDevice).firstOrNull;

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
