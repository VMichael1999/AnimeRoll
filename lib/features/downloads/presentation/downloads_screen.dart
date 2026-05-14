import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../data/downloads_provider.dart';

enum _DownloadTab { active, saved, errors }

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _DownloadTab _tab = _DownloadTab.active;

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final albums = _DownloadAlbum.fromDownloads(downloads);
    final active = downloads.where((item) => item.isActive).toList();
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
            _StorageUsage(downloads: downloads),
            const SizedBox(height: 10),
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
                  showBatchActions: true,
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
        .where((item) => item.isActive && !item.isPaused)
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
                style: TextStyle(
                  color: AppColors.accent2,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: Icon(Icons.more_vert_rounded),
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
        .where((item) => item.isActive && !item.isPaused)
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

class _StorageUsage extends StatelessWidget {
  final List<DownloadModel> downloads;

  const _StorageUsage({required this.downloads});

  @override
  Widget build(BuildContext context) {
    final used = downloads
        .where((item) => item.isSavedOnDevice || item.fileSize != null)
        .fold<int>(0, (total, item) => total + _parseBytes(item.fileSize));
    const total = 32 * 1024 * 1024 * 1024;
    final percent = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Almacenamiento usado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_formatBytes(used)} / ${_formatBytes(total)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.accent2),
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
            style: TextStyle(
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
            label: 'En curso',
            active: selected == _DownloadTab.active,
            onTap: () => onChanged(_DownloadTab.active),
          ),
          _TabButton(
            label: 'Guardados',
            active: selected == _DownloadTab.saved,
            onTap: () => onChanged(_DownloadTab.saved),
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
  final bool showBatchActions;

  const _DownloadQueue({
    required this.downloads,
    required this.emptyText,
    this.showBatchActions = false,
  });

  @override
  Widget build(BuildContext context) {
    if (downloads.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: downloads.length + (showBatchActions ? 1 : 0),
      separatorBuilder: (context, index) => index == 0 && showBatchActions
          ? const SizedBox.shrink()
          : const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (showBatchActions && index == 0) {
          return _BatchActions(activeCount: downloads.length);
        }
        final item = downloads[index - (showBatchActions ? 1 : 0)];
        return _DownloadQueueTile(download: item);
      },
    );
  }
}

class _BatchActions extends ConsumerWidget {
  final int activeCount;

  const _BatchActions({required this.activeCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      decoration: BoxDecoration(
        color: Color(0x241A0B30),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$activeCount descargas activas',
              style: TextStyle(
                color: AppColors.accent2,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _QueueButton(
            label: 'Pausar todo',
            icon: Icons.pause_rounded,
            color: AppColors.warning,
            onPressed: () => ref.read(downloadsProvider.notifier).pauseAll(),
          ),
          const SizedBox(width: 6),
          _QueueButton(
            label: 'Cancelar',
            icon: Icons.close_rounded,
            color: AppColors.error,
            onPressed: () =>
                ref.read(downloadsProvider.notifier).cancelActive(),
          ),
        ],
      ),
    );
  }
}

class _DownloadQueueTile extends ConsumerWidget {
  final DownloadModel download;

  const _DownloadQueueTile({required this.download});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed =
        download.status == 'failed' || download.localStatus == 'failed';
    final progress = download.effectiveProgress;
    final paused = download.isPaused;

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
                  height: 50,
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _subtitle(download, failed, paused),
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
              if (!failed)
                _IconMiniButton(
                  tooltip: paused ? 'Reanudar' : 'Pausar',
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppColors.warning,
                  onPressed: () {
                    final notifier = ref.read(downloadsProvider.notifier);
                    paused
                        ? notifier.resumeDownload(download.id)
                        : notifier.pauseDownload(download.id);
                  },
                ),
              const SizedBox(width: 6),
              _IconMiniButton(
                tooltip: 'Eliminar',
                icon: Icons.delete_rounded,
                color: AppColors.error,
                onPressed: () => ref
                    .read(downloadsProvider.notifier)
                    .removeDownload(download.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  failed
                      ? 'Error'
                      : paused
                      ? 'Pausado'
                      : _speedLabel(download),
                  style: TextStyle(
                    fontSize: 10,
                    color: failed
                        ? AppColors.error
                        : paused
                        ? AppColors.warning
                        : AppColors.accent2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                failed ? '' : '$progress%',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                failed || paused ? '' : _etaLabel(download),
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
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

  String _subtitle(DownloadModel item, bool failed, bool paused) {
    if (failed) return item.error ?? 'Error desconocido';
    final status = paused
        ? 'Pausado'
        : item.status == 'queued'
        ? 'En cola'
        : item.localStatus == 'saving'
        ? 'Guardando'
        : item.phase == 'finalizing'
        ? 'Finalizando'
        : item.currentServer ?? item.phase ?? item.status;
    final size = _formatBytes(_parseBytes(item.fileSize));
    return '${item.quality} · ${item.variant} · $size · $status';
  }

  String _speedLabel(DownloadModel item) {
    if (item.phase == 'finalizing') return 'Finalizando';
    if (item.speedBytesPerSecond != null && item.speedBytesPerSecond! > 0) {
      return '${_formatBytes(item.speedBytesPerSecond!)}/s';
    }
    final updated = _parseEpochOrIso(item.updatedAt);
    final created =
        _parseEpochOrIso(item.transferStartedAt) ??
        _parseEpochOrIso(item.startedAt) ??
        _parseEpochOrIso(item.createdAt);
    if (updated == null || created == null || item.downloadedBytes <= 0) {
      return item.status == 'queued' ? 'En cola' : 'Resolviendo';
    }
    final seconds = updated.difference(created).inSeconds;
    if (seconds <= 0) return 'Resolviendo';
    return '${_formatBytes(item.downloadedBytes ~/ seconds)}/s';
  }

  String _etaLabel(DownloadModel item) {
    if (item.phase == 'finalizing') return '~finalizando';
    if (item.etaSeconds != null && item.etaSeconds! > 0) {
      return '~${item.etaSeconds}s restantes';
    }
    final total = item.totalBytes ?? _parseBytes(item.fileSize);
    if (total <= 0 || item.downloadedBytes <= 0) return '';
    final updated = _parseEpochOrIso(item.updatedAt);
    final created =
        _parseEpochOrIso(item.transferStartedAt) ??
        _parseEpochOrIso(item.startedAt) ??
        _parseEpochOrIso(item.createdAt);
    if (updated == null || created == null) return '';
    final seconds = updated.difference(created).inSeconds;
    if (seconds <= 0) return '';
    final bytesPerSecond = item.downloadedBytes / seconds;
    if (bytesPerSecond <= 0) return '';
    final remaining = ((total - item.downloadedBytes) / bytesPerSecond).ceil();
    if (remaining <= 0) return '';
    return '~${remaining}s restantes';
  }
}

class _IconMiniButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _IconMiniButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }
}

class _QueueButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _QueueButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 13),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      '${album.savedCount}/${album.items.length}',
                      style: TextStyle(
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
      placeholder: (context, url) => ColoredBox(color: AppColors.surface2),
    );
  }
}

class _DownloadPlaceholder extends StatelessWidget {
  const _DownloadPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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

  int get bytes =>
      items.fold<int>(0, (total, item) => total + _parseBytes(item.fileSize));

  String get subtitle {
    final first = items.first;
    return '${first.quality} ${first.variant}';
  }

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

int _parseBytes(String? value) {
  if (value == null || value.trim().isEmpty) return 0;
  final raw = value.trim().toLowerCase();
  final direct = int.tryParse(raw);
  if (direct != null) return direct;

  final match = RegExp(r'([\d.]+)\s*(kb|mb|gb|tb)').firstMatch(raw);
  if (match == null) return 0;
  final amount = double.tryParse(match.group(1) ?? '') ?? 0;
  final unit = match.group(2);
  final multiplier = switch (unit) {
    'kb' => 1024,
    'mb' => 1024 * 1024,
    'gb' => 1024 * 1024 * 1024,
    'tb' => 1024 * 1024 * 1024 * 1024,
    _ => 1,
  };
  return (amount * multiplier).round();
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  return '${(bytes / mb).clamp(0.1, double.infinity).toStringAsFixed(1)} MB';
}

DateTime? _parseEpochOrIso(String? value) {
  if (value == null || value.isEmpty) return null;
  final millis = int.tryParse(value);
  if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime.tryParse(value);
}
