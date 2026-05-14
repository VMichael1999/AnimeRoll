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
  static const _maxLocalSaveAttempts = 3;

  final Ref _ref;
  final DeviceVideoSaver _videoSaver;
  Timer? _timer;
  final Set<String> _savingIds = {};
  final Map<String, int> _localSaveAttempts = {};
  bool _localSaveRunning = false;

  DownloadsNotifier(this._ref)
    : _videoSaver = DeviceVideoSaver(),
      super(const []) {
    unawaited(_load());
  }

  Future<void> startEpisode({
    required String episodeUrl,
    String? title,
    String? thumbnail,
    String? animeTitle,
    String? animeUrl,
    String? episodeTitle,
    int? episodeNumber,
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
      phase: download.phase,
      progress: download.progress,
      url: download.url,
      title: title,
      thumbnail: thumbnail,
      animeTitle: animeTitle ?? _inferAnimeTitle(title),
      animeUrl: animeUrl ?? _inferAnimeUrl(episodeUrl),
      episodeTitle: episodeTitle ?? _inferEpisodeTitle(title),
      episodeNumber: episodeNumber ?? _inferEpisodeNumber(episodeUrl),
      quality: download.quality,
      variant: download.variant,
      downloadUrl: download.downloadUrl,
      fileSize: download.fileSize,
      currentServer: download.currentServer,
      error: download.error,
      downloadedBytes: download.downloadedBytes,
      totalBytes: download.totalBytes,
      speedBytesPerSecond: download.speedBytesPerSecond,
      etaSeconds: download.etaSeconds,
      createdAt: download.createdAt,
      queuedAt: download.queuedAt,
      startedAt: download.startedAt,
      transferStartedAt: download.transferStartedAt,
      updatedAt: download.updatedAt,
      completedAt: download.completedAt,
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
            animeTitle: title,
            animeUrl: animeUrl,
            episodeTitle: 'Episodio ${item.episode}',
            episodeNumber: item.episode,
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
    final updated = await Future.wait(state.map(_refreshItem));
    state = updated;
    unawaited(_persist());
    unawaited(_drainLocalSaveQueue());
    if (!state.any((item) => item.isActive || _canRetryLocalSave(item))) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<DownloadModel> _refreshItem(DownloadModel item) async {
    final repo = _ref.read(animeRepositoryProvider);
    try {
      final latest = await repo.getDownloadStatus(item.id);
      return item.copyWith(
        id: latest.id,
        status: latest.status,
        phase: latest.phase,
        progress: latest.progress,
        url: latest.url,
        quality: latest.quality,
        variant: latest.variant,
        downloadUrl: latest.downloadUrl,
        fileSize: latest.fileSize,
        currentServer: latest.currentServer,
        error: latest.error,
        downloadedBytes: latest.downloadedBytes,
        totalBytes: latest.totalBytes,
        speedBytesPerSecond: latest.speedBytesPerSecond,
        etaSeconds: latest.etaSeconds,
        createdAt: latest.createdAt,
        queuedAt: latest.queuedAt,
        startedAt: latest.startedAt,
        transferStartedAt: latest.transferStartedAt,
        updatedAt: latest.updatedAt,
        completedAt: latest.completedAt,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return item.copyWith(
          status: 'failed',
          progress: 0,
          error: 'Descarga no encontrada en el servidor',
        );
      }
      return item;
    } catch (_) {
      return item;
    }
  }

  Future<void> pauseDownload(String id) async {
    _updateItem(id, (download) {
      if (download.isSavedOnDevice || download.localStatus == 'failed') {
        return download;
      }
      return download.copyWith(localStatus: 'paused');
    });
  }

  Future<void> resumeDownload(String id) async {
    _updateItem(id, (download) {
      if (!download.isPaused) return download;
      return download.copyWith(localStatus: 'pending');
    });
    _startPolling();
    unawaited(_drainLocalSaveQueue());
  }

  Future<void> pauseAll() async {
    state = [
      for (final item in state)
        if (item.isSavedOnDevice || item.localStatus == 'failed')
          item
        else
          item.copyWith(localStatus: 'paused'),
    ];
    await _persist();
  }

  Future<void> cancelActive() async {
    final targets = state.where((item) => item.isActive).toList();
    state = state.where((item) => !item.isActive).toList();
    await _persist();
    for (final item in targets) {
      await _videoSaver.deleteVideo(item.localPath);
    }
  }

  Future<void> removeDownload(String id, {bool deleteFile = true}) async {
    final target = state.where((item) => item.id == id).firstOrNull;
    state = state.where((item) => item.id != id).toList();
    await _persist();
    if (deleteFile && target?.localPath != null) {
      await _videoSaver.deleteVideo(target!.localPath);
    }
  }

  Future<void> removeAlbum(String albumKey, {bool deleteFiles = true}) async {
    final targets = state
        .where((item) => item.albumKey == albumKey)
        .toList(growable: false);
    state = state.where((item) => item.albumKey != albumKey).toList();
    await _persist();
    if (!deleteFiles) return;
    for (final item in targets) {
      await _videoSaver.deleteVideo(item.localPath);
    }
  }

  void _startPolling() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  Future<void> _drainLocalSaveQueue() async {
    if (_localSaveRunning) return;
    _localSaveRunning = true;
    try {
      while (mounted) {
        final next = state
            .where(
              (item) =>
                  item.status == 'completed' &&
                  item.downloadUrl != null &&
                  !item.isSavedOnDevice &&
                  !item.isLocalRunning &&
                  !item.isPaused &&
                  _canRetryLocalSave(item),
            )
            .firstOrNull;
        if (next == null) break;
        await _saveToDevice(next);
      }
    } finally {
      _localSaveRunning = false;
    }
  }

  Future<void> _saveToDevice(DownloadModel item) async {
    if (!_savingIds.add(item.id)) return;
    final attempt = (_localSaveAttempts[item.id] ?? 0) + 1;
    _localSaveAttempts[item.id] = attempt;
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
      _localSaveAttempts.remove(item.id);
    } catch (error) {
      final exhausted = attempt >= _maxLocalSaveAttempts;
      _updateItem(
        item.id,
        (download) => download.copyWith(
          localStatus: exhausted ? 'failed' : 'pending',
          error: exhausted
              ? 'No se pudo guardar en el móvil: $error'
              : 'Reintentando guardado local ($attempt/$_maxLocalSaveAttempts)',
        ),
      );
      if (!exhausted) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
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
        .map(_normalizeLoadedItem)
        .toList();
    if (state.any(
      (item) =>
          item.isRunning || item.isLocalRunning || _canRetryLocalSave(item),
    )) {
      _startPolling();
    }
  }

  DownloadModel _normalizeLoadedItem(DownloadModel item) {
    if (item.localStatus == 'saving') {
      return item.copyWith(
        localStatus: 'pending',
        localProgress: 0,
        error: 'Guardado local interrumpido, reanudando',
      );
    }
    return item;
  }

  bool _canRetryLocalSave(DownloadModel item) {
    if (item.isSavedOnDevice || item.isPaused) return false;
    if (item.status != 'completed' || item.downloadUrl == null) return false;
    return (_localSaveAttempts[item.id] ?? 0) < _maxLocalSaveAttempts;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(state.map((item) => item.toJson()).toList()),
    );
  }

  String? _inferAnimeTitle(String? title) {
    if (title == null) return null;
    return title.split('·').first.trim();
  }

  String? _inferEpisodeTitle(String? title) {
    if (title == null || !title.contains('·')) return title;
    return title.split('·').skip(1).join('·').trim();
  }

  String _inferAnimeUrl(String episodeUrl) {
    final uri = Uri.tryParse(episodeUrl);
    if (uri == null || uri.pathSegments.length < 3) return '';
    return uri
        .replace(
          pathSegments: uri.pathSegments.take(uri.pathSegments.length - 1),
        )
        .toString();
  }

  int? _inferEpisodeNumber(String episodeUrl) {
    final uri = Uri.tryParse(episodeUrl);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    return int.tryParse(uri.pathSegments.last);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
