import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DeviceVideoSaver {
  static const _channel = MethodChannel('anime_roll/media_store');

  final Dio _dio;

  DeviceVideoSaver({Dio? dio}) : _dio = dio ?? Dio();

  Future<String> saveVideo({
    required String url,
    required String title,
    required void Function(int progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = _fileNameFor(title);
    final tempPath = '${tempDir.path}${Platform.pathSeparator}$fileName';

    await _dio.download(
      url,
      tempPath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress(((received / total) * 100).round().clamp(0, 100));
      },
    );

    if (Platform.isAndroid) {
      final savedPath = await _channel.invokeMethod<String>('saveVideo', {
        'sourcePath': tempPath,
        'displayName': fileName,
        'mimeType': _mimeType(fileName),
      });
      await File(tempPath).delete().catchError((_) => File(tempPath));
      return savedPath ?? 'Movies/AnimeRoll/$fileName';
    }

    final documents = await getApplicationDocumentsDirectory();
    final localPath = '${documents.path}${Platform.pathSeparator}$fileName';
    await File(tempPath).copy(localPath);
    await File(tempPath).delete().catchError((_) => File(tempPath));
    return localPath;
  }

  String _fileNameFor(String title) {
    final safe = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final base = safe.isEmpty ? 'AnimeRoll video' : safe;
    return '$base.mp4';
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }
}
