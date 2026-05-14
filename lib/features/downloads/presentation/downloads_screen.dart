import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../data/downloads_provider.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final albums = _DownloadAlbum.fromDownloads(downloads);

    return Scaffold(
      body: SafeArea(
        child: _AlbumLibrary(
          albums: albums,
          downloads: downloads,
          onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
          onOpenAlbum: (album) => _openAlbumPlayer(context, album),
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
