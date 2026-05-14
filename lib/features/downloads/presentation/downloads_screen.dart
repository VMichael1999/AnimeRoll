import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/download_model.dart';
import '../data/downloads_provider.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Descargas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: () =>
                        ref.read(downloadsProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Se guardan en Videos/AnimeRoll del móvil',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            _StorageBar(downloads: downloads),
            const SizedBox(height: 16),
            Expanded(
              child: downloads.isEmpty
                  ? const _EmptyDownloads()
                  : _DownloadList(downloads: downloads),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageBar extends StatelessWidget {
  final List<DownloadModel> downloads;

  const _StorageBar({required this.downloads});

  @override
  Widget build(BuildContext context) {
    final completed = downloads.where((item) => item.isSavedOnDevice).length;
    final progress = downloads.isEmpty ? 0.0 : completed / downloads.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progreso total', style: TextStyle(fontSize: 11)),
              Text(
                '$completed / ${downloads.length}',
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

class _DownloadList extends StatelessWidget {
  final List<DownloadModel> downloads;

  const _DownloadList({required this.downloads});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: downloads.length,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _DownloadTile(download: downloads[index]),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadModel download;

  const _DownloadTile({required this.download});

  @override
  Widget build(BuildContext context) {
    final title =
        download.title ??
        Uri.tryParse(download.url)?.pathSegments.lastOrNull ??
        download.url;
    final failed = download.status == 'failed';
    final completed = download.status == 'completed';
    final saving = download.localStatus == 'saving';
    final saved = download.isSavedOnDevice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 38,
                  child: download.thumbnail == null
                      ? const ColoredBox(
                          color: AppColors.border,
                          child: Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: download.thumbnail!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              const ColoredBox(color: AppColors.border),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                ),
              ),
              Text(
                saved
                    ? 'Móvil'
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
          const SizedBox(height: 6),
          Text(
            failed
                ? download.error ?? 'Error desconocido'
                : saved
                ? 'Guardado en Videos/AnimeRoll'
                : saving
                ? 'Guardando en el móvil...'
                : '${download.quality} · ${download.variant}${download.currentServer != null ? ' · ${download.currentServer}' : ''}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (download.downloadUrl != null || download.localPath != null) ...[
            const SizedBox(height: 6),
            Text(
              download.localPath ?? download.downloadUrl!,
              style: const TextStyle(fontSize: 10, color: AppColors.accent2),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
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
            Icons.download_done_rounded,
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
            'Inicia una descarga desde el detalle de un anime',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
