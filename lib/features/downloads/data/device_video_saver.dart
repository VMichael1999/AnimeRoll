import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DeviceVideoSaver {
  static const _channel = MethodChannel('anime_roll/media_store');
  static const _maxAttempts = 4;

  final Dio _dio;

  DeviceVideoSaver({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 20),
              followRedirects: true,
              maxRedirects: 5,
            ),
          );

  Future<String> saveVideo({
    required String url,
    required String title,
    required void Function(int progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = _fileNameFor(title);
    final tempPath = '${tempDir.path}${Platform.pathSeparator}$fileName.part';

    await _downloadWithResume(
      url: url,
      tempPath: tempPath,
      onProgress: onProgress,
    );
    onProgress(100);

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

  Future<void> _downloadWithResume({
    required String url,
    required String tempPath,
    required void Function(int progress) onProgress,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        await _downloadAttempt(
          url: url,
          tempPath: tempPath,
          onProgress: onProgress,
        );
        return;
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts - 1) break;
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    throw lastError ?? StateError('No se pudo descargar el archivo');
  }

  Future<void> _downloadAttempt({
    required String url,
    required String tempPath,
    required void Function(int progress) onProgress,
  }) async {
    final file = File(tempPath);
    final existingBytes = await file.exists() ? await file.length() : 0;
    final headers = <String, dynamic>{};
    if (existingBytes > 0) {
      headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
    }

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    final statusCode = response.statusCode ?? 0;
    var offset = existingBytes;
    if (existingBytes > 0 && statusCode != HttpStatus.partialContent) {
      offset = 0;
      await file.delete().catchError((_) => file);
    }

    final totalBytes = _totalBytes(response.headers, offset);
    final sink = file.openSync(
      mode: offset > 0 ? FileMode.append : FileMode.write,
    );
    var received = offset;
    try {
      await for (final chunk in response.data!.stream) {
        sink.writeFromSync(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          onProgress(((received / totalBytes) * 100).round().clamp(0, 99));
        }
      }
    } finally {
      await sink.close();
    }

    if (totalBytes > 0 && received < totalBytes) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Descarga incompleta: $received/$totalBytes bytes',
        type: DioExceptionType.badResponse,
      );
    }
  }

  int _totalBytes(Headers headers, int offset) {
    final contentRange = headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
      final total = int.tryParse(match?.group(1) ?? '');
      if (total != null && total > 0) return total;
    }
    final length = int.tryParse(
      headers.value(Headers.contentLengthHeader) ?? '',
    );
    if (length == null || length <= 0) return 0;
    return offset + length;
  }

  Future<void> deleteVideo(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return;
    if (Platform.isAndroid && localPath.startsWith('content://')) {
      await _channel.invokeMethod<void>('deleteVideo', {'uri': localPath});
      return;
    }
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
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
