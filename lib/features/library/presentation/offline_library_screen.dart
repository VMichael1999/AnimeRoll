import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../../downloads/data/downloads_provider.dart';

class OfflineLibraryScreen extends ConsumerWidget {
  const OfflineLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = _OfflineAlbum.fromDownloads(ref.watch(downloadsProvider));
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OfflineBanner(
              onRetry: () => ref.read(downloadsProvider.notifier).refresh(),
            ),
            _OfflineHeader(albums: albums),
            Expanded(
              child: albums.isEmpty
                  ? const _EmptyLibrary()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      itemCount: albums.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _OfflineAlbumCard(
                          album: album,
                          onTap: () => _openAlbum(context, album),
                          onDelete: () => ref
                              .read(downloadsProvider.notifier)
                              .removeAlbum(album.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlbum(BuildContext context, _OfflineAlbum album) {
    final download = album.firstPlayable;
    if (download?.localPath == null) return;
    context.push(
      '/download-player?id=${Uri.encodeComponent(download!.id)}&title=${Uri.encodeComponent(download.displayEpisodeTitle)}&path=${Uri.encodeComponent(download.localPath!)}&animeTitle=${Uri.encodeComponent(download.albumTitle)}',
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.18),
        border: Border(bottom: BorderSide(color: AppColors.warning)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sin conexión — Modo offline activo',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Reintentar',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineHeader extends StatelessWidget {
  final List<_OfflineAlbum> albums;

  const _OfflineHeader({required this.albums});

  @override
  Widget build(BuildContext context) {
    final episodes = albums.fold<int>(
      0,
      (total, album) => total + album.items.length,
    );
    final bytes = albums.fold<int>(0, (total, album) => total + album.bytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biblioteca offline',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            '${albums.length} series · $episodes episodios · ${_formatBytes(bytes)} usados',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineAlbumCard extends StatelessWidget {
  final _OfflineAlbum album;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _OfflineAlbumCard({
    required this.album,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      width: 62,
                      height: 78,
                      child: _CoverImage(url: album.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 78,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            album.subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: [
                              for (final item in album.items.take(4))
                                _EpisodePill(
                                  label: item.episodeNumber == null
                                      ? item.displayEpisodeTitle
                                      : 'Ep. ${item.episodeNumber}',
                                ),
                              if (album.items.length > 4)
                                _EpisodePill(
                                  label: '+${album.items.length - 4}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(9),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${album.items.length} episodios',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatBytes(album.bytes),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodePill extends StatelessWidget {
  final String label;

  const _EpisodePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.accent2,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String? url;

  const _CoverImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _LibraryPlaceholder();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, _, _) => const _LibraryPlaceholder(),
      placeholder: (_, _) => ColoredBox(color: AppColors.surface2),
    );
  }
}

class _LibraryPlaceholder extends StatelessWidget {
  const _LibraryPlaceholder();

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

class _OfflineAlbum {
  final String key;
  final String title;
  final String? cover;
  final List<DownloadModel> items;

  const _OfflineAlbum({
    required this.key,
    required this.title,
    required this.cover,
    required this.items,
  });

  int get bytes =>
      items.fold<int>(0, (total, item) => total + _parseBytes(item.fileSize));

  String get subtitle {
    final first = items.first;
    return '${first.quality} ${first.variant}';
  }

  DownloadModel? get firstPlayable => items.firstOrNull;

  static List<_OfflineAlbum> fromDownloads(List<DownloadModel> downloads) {
    final grouped = <String, List<DownloadModel>>{};
    for (final download in downloads.where((item) => item.isSavedOnDevice)) {
      grouped.putIfAbsent(download.albumKey, () => []).add(download);
    }
    final albums = grouped.entries.map((entry) {
      final items = [
        ...entry.value,
      ]..sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
      return _OfflineAlbum(
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Sin episodios offline',
        style: TextStyle(color: AppColors.textSecondary),
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
