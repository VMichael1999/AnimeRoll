import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/download_model.dart';
import '../../home/data/home_provider.dart';
import 'device_video_saver.dart';

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadModel>>((ref) {
      return DownloadsNotifier(ref);
    });

class DownloadsNotifier extends StateNotifier<List<DownloadModel>> {
  static const _storageKey = 'downloadHistory';

  final Ref _ref;
  final DeviceVideoSaver _videoSaver;
  Timer? _timer;
  final Set<String> _savingIds = {};

  DownloadsNotifier(this._ref)
    : _videoSaver = DeviceVideoSaver(),
      super(const []) {
    unawaited(_load());
  }

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
    unawaited(_persist());
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
    unawaited(_persist());
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
          item.copyWith(
            id: latest.id,
            status: latest.status,
            progress: latest.progress,
            url: latest.url,
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
            item.copyWith(
              status: 'failed',
              progress: 0,
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
    unawaited(_persist());
    for (final item in state) {
      if (item.status == 'completed' &&
          item.downloadUrl != null &&
          !item.isSavedOnDevice &&
          !item.isLocalRunning &&
          item.localStatus != 'failed') {
        unawaited(_saveToDevice(item));
      }
    }
    if (!state.any((item) => item.isRunning || item.isLocalRunning)) {
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

  Future<void> _saveToDevice(DownloadModel item) async {
    if (!_savingIds.add(item.id)) return;
    _updateItem(
      item.id,
      (download) => download.copyWith(localStatus: 'saving', localProgress: 0),
    );

    try {
      final title =
          item.title ??
          Uri.tryParse(item.url)?.pathSegments.lastOrNull ??
          item.id;
      final localPath = await _videoSaver.saveVideo(
        url: item.downloadUrl!,
        title: title,
        onProgress: (progress) {
          _updateItem(
            item.id,
            (download) => download.copyWith(
              localStatus: 'saving',
              localProgress: progress,
            ),
          );
        },
      );
      _updateItem(
        item.id,
        (download) => download.copyWith(
          localPath: localPath,
          localStatus: 'saved',
          localProgress: 100,
          savedAt: DateTime.now().toIso8601String(),
        ),
      );
    } catch (error) {
      _updateItem(
        item.id,
        (download) => download.copyWith(
          localStatus: 'failed',
          error: 'No se pudo guardar en el móvil: $error',
        ),
      );
    } finally {
      _savingIds.remove(item.id);
      unawaited(_persist());
    }
  }

  void _updateItem(String id, DownloadModel Function(DownloadModel) update) {
    state = [for (final item in state) item.id == id ? update(item) : item];
    unawaited(_persist());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    state = decoded
        .whereType<Map>()
        .map((item) => DownloadModel.fromJson(item.cast<String, dynamic>()))
        .toList();
    if (state.any((item) => item.isRunning || item.isLocalRunning)) {
      _startPolling();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(state.map((item) => item.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
