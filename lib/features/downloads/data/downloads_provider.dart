import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/download_model.dart';
import '../../home/data/home_provider.dart';

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadModel>>((ref) {
      return DownloadsNotifier(ref);
    });

class DownloadsNotifier extends StateNotifier<List<DownloadModel>> {
  final Ref _ref;
  Timer? _timer;

  DownloadsNotifier(this._ref) : super(const []);

  Future<void> startEpisode({
    required String episodeUrl,
    String? title,
    String? thumbnail,
    required String quality,
    required String variant,
    String? preferredServer,
  }) async {
    final repo = _ref.read(animeRepositoryProvider);
    final download = await repo.createDownload(
      episodeUrl: episodeUrl,
      quality: quality,
      variant: variant,
      preferredServer: preferredServer,
    );
    final enriched = DownloadModel(
      id: download.id,
      status: download.status,
      progress: download.progress,
      url: download.url,
      title: title,
      thumbnail: thumbnail,
      quality: download.quality,
      variant: download.variant,
      downloadUrl: download.downloadUrl,
      fileSize: download.fileSize,
      currentServer: download.currentServer,
      error: download.error,
    );
    state = [enriched, ...state.where((item) => item.id != download.id)];
    _startPolling();
  }

  Future<BatchDownloadModel> startBatch({
    required String animeUrl,
    required List<int> episodes,
    String? title,
    String? thumbnail,
    required String quality,
    required String variant,
  }) async {
    final repo = _ref.read(animeRepositoryProvider);
    final batch = await repo.createBatchDownload(
      animeUrl: animeUrl,
      episodes: episodes,
      quality: quality,
      variant: variant,
    );
    final items = batch.items
        .where((item) => item.downloadId.isNotEmpty)
        .map(
          (item) => DownloadModel(
            id: item.downloadId,
            status: item.status,
            progress: 0,
            url: '${animeUrl.replaceAll(RegExp(r'/$'), '')}/${item.episode}',
            title: title == null
                ? 'Episodio ${item.episode}'
                : '$title · Ep ${item.episode}',
            thumbnail: thumbnail,
            quality: quality,
            variant: variant,
          ),
        )
        .toList();
    state = [
      ...items,
      ...state.where(
        (download) => !items.any((item) => item.id == download.id),
      ),
    ];
    _startPolling();
    return batch;
  }

  Future<void> refresh() async {
    if (state.isEmpty) return;
    final repo = _ref.read(animeRepositoryProvider);
    final updated = <DownloadModel>[];
    for (final item in state) {
      try {
        final latest = await repo.getDownloadStatus(item.id);
        updated.add(
          DownloadModel(
            id: latest.id,
            status: latest.status,
            progress: latest.progress,
            url: latest.url,
            title: item.title,
            thumbnail: item.thumbnail,
            quality: latest.quality,
            variant: latest.variant,
            downloadUrl: latest.downloadUrl,
            fileSize: latest.fileSize,
            currentServer: latest.currentServer,
            error: latest.error,
          ),
        );
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) {
          updated.add(
            DownloadModel(
              id: item.id,
              status: 'failed',
              progress: 0,
              url: item.url,
              title: item.title,
              thumbnail: item.thumbnail,
              quality: item.quality,
              variant: item.variant,
              error: 'Descarga no encontrada en el servidor',
            ),
          );
        } else {
          updated.add(item);
        }
      } catch (_) {
        updated.add(item);
      }
    }
    state = updated;
    if (!state.any((item) => item.isRunning)) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startPolling() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
