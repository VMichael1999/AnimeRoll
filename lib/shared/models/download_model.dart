class DownloadModel {
  final String id;
  final String status;
  final String? phase;
  final int progress;
  final String url;
  final String? title;
  final String? thumbnail;
  final String? animeTitle;
  final String? animeUrl;
  final String? episodeTitle;
  final int? episodeNumber;
  final String quality;
  final String variant;
  final String? downloadUrl;
  final String? fileSize;
  final String? currentServer;
  final String? error;
  final int downloadedBytes;
  final int? totalBytes;
  final int? speedBytesPerSecond;
  final int? etaSeconds;
  final String? createdAt;
  final String? queuedAt;
  final String? startedAt;
  final String? transferStartedAt;
  final String? updatedAt;
  final String? completedAt;
  final String? localPath;
  final int localProgress;
  final String localStatus;
  final String? savedAt;

  const DownloadModel({
    required this.id,
    required this.status,
    this.phase,
    required this.progress,
    required this.url,
    this.title,
    this.thumbnail,
    this.animeTitle,
    this.animeUrl,
    this.episodeTitle,
    this.episodeNumber,
    required this.quality,
    required this.variant,
    this.downloadUrl,
    this.fileSize,
    this.currentServer,
    this.error,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.speedBytesPerSecond,
    this.etaSeconds,
    this.createdAt,
    this.queuedAt,
    this.startedAt,
    this.transferStartedAt,
    this.updatedAt,
    this.completedAt,
    this.localPath,
    this.localProgress = 0,
    this.localStatus = 'pending',
    this.savedAt,
  });

  bool get isRunning =>
      status == 'queued' || status == 'preparing' || status == 'downloading';

  bool get isLocalRunning => localStatus == 'saving';

  bool get isSavedOnDevice => localStatus == 'saved' && localPath != null;

  bool get isPaused => localStatus == 'paused';

  bool get isQueuedForLocalSave =>
      status == 'completed' && localStatus == 'pending';

  bool get isActive =>
      isRunning || isLocalRunning || isQueuedForLocalSave || isPaused;

  int get effectiveProgress => isLocalRunning ? localProgress : progress;

  String get albumTitle {
    final inferred = animeTitle ?? title?.split('·').first.trim();
    return inferred == null || inferred.isEmpty ? 'Sin título' : inferred;
  }

  String get albumKey {
    final key = animeUrl?.trim();
    if (key != null && key.isNotEmpty) return key;
    return albumTitle.toLowerCase();
  }

  String get displayEpisodeTitle {
    final inferred = episodeTitle ?? title?.split('·').last.trim();
    if (inferred != null && inferred.isNotEmpty) return inferred;
    if (episodeNumber != null) return 'Episodio $episodeNumber';
    return title ?? url;
  }

  factory DownloadModel.fromJson(Map<String, dynamic> json) => DownloadModel(
    id: json['downloadId'] as String? ?? json['id'] as String? ?? '',
    status: json['status'] as String? ?? 'queued',
    phase: json['phase'] as String?,
    progress: (json['progress'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    title: json['title'] as String?,
    thumbnail: json['thumbnail'] as String?,
    animeTitle: json['animeTitle'] as String?,
    animeUrl: json['animeUrl'] as String?,
    episodeTitle: json['episodeTitle'] as String?,
    episodeNumber: (json['episodeNumber'] as num?)?.toInt(),
    quality: json['quality'] as String? ?? '1080p',
    variant: json['variant'] as String? ?? 'SUB',
    downloadUrl: json['downloadUrl'] as String?,
    fileSize: json['fileSize']?.toString(),
    currentServer: json['currentServer'] as String?,
    error: json['error'] as String?,
    downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
    totalBytes: (json['totalBytes'] as num?)?.toInt(),
    speedBytesPerSecond: (json['speedBytesPerSecond'] as num?)?.toInt(),
    etaSeconds: (json['etaSeconds'] as num?)?.toInt(),
    createdAt: json['createdAt']?.toString(),
    queuedAt: json['queuedAt']?.toString(),
    startedAt: json['startedAt']?.toString(),
    transferStartedAt: json['transferStartedAt']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
    completedAt: json['completedAt']?.toString(),
    localPath: json['localPath'] as String?,
    localProgress: (json['localProgress'] as num?)?.toInt() ?? 0,
    localStatus: json['localStatus'] as String? ?? 'pending',
    savedAt: json['savedAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'phase': phase,
    'progress': progress,
    'url': url,
    'title': title,
    'thumbnail': thumbnail,
    'animeTitle': animeTitle,
    'animeUrl': animeUrl,
    'episodeTitle': episodeTitle,
    'episodeNumber': episodeNumber,
    'quality': quality,
    'variant': variant,
    'downloadUrl': downloadUrl,
    'fileSize': fileSize,
    'currentServer': currentServer,
    'error': error,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'speedBytesPerSecond': speedBytesPerSecond,
    'etaSeconds': etaSeconds,
    'createdAt': createdAt,
    'queuedAt': queuedAt,
    'startedAt': startedAt,
    'transferStartedAt': transferStartedAt,
    'updatedAt': updatedAt,
    'completedAt': completedAt,
    'localPath': localPath,
    'localProgress': localProgress,
    'localStatus': localStatus,
    'savedAt': savedAt,
  };

  DownloadModel copyWith({
    String? id,
    String? status,
    String? phase,
    int? progress,
    String? url,
    String? title,
    String? thumbnail,
    String? animeTitle,
    String? animeUrl,
    String? episodeTitle,
    int? episodeNumber,
    String? quality,
    String? variant,
    String? downloadUrl,
    String? fileSize,
    String? currentServer,
    String? error,
    int? downloadedBytes,
    int? totalBytes,
    int? speedBytesPerSecond,
    int? etaSeconds,
    String? createdAt,
    String? queuedAt,
    String? startedAt,
    String? transferStartedAt,
    String? updatedAt,
    String? completedAt,
    String? localPath,
    int? localProgress,
    String? localStatus,
    String? savedAt,
  }) {
    return DownloadModel(
      id: id ?? this.id,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      animeTitle: animeTitle ?? this.animeTitle,
      animeUrl: animeUrl ?? this.animeUrl,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      quality: quality ?? this.quality,
      variant: variant ?? this.variant,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      currentServer: currentServer ?? this.currentServer,
      error: error ?? this.error,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      createdAt: createdAt ?? this.createdAt,
      queuedAt: queuedAt ?? this.queuedAt,
      startedAt: startedAt ?? this.startedAt,
      transferStartedAt: transferStartedAt ?? this.transferStartedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      localPath: localPath ?? this.localPath,
      localProgress: localProgress ?? this.localProgress,
      localStatus: localStatus ?? this.localStatus,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

class BatchDownloadModel {
  final String id;
  final String status;
  final int progress;
  final int total;
  final int completed;
  final int failed;
  final List<BatchDownloadItem> items;

  const BatchDownloadModel({
    required this.id,
    required this.status,
    required this.progress,
    required this.total,
    required this.completed,
    required this.failed,
    this.items = const [],
  });

  factory BatchDownloadModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'];

    return BatchDownloadModel(
      id: json['batchId'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      items: items is List
          ? items
                .map(
                  (item) =>
                      BatchDownloadItem.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : const [],
    );
  }
}

class BatchDownloadItem {
  final int episode;
  final String downloadId;
  final String status;

  const BatchDownloadItem({
    required this.episode,
    required this.downloadId,
    required this.status,
  });

  factory BatchDownloadItem.fromJson(Map<String, dynamic> json) =>
      BatchDownloadItem(
        episode: (json['episode'] as num?)?.toInt() ?? 0,
        downloadId: json['downloadId'] as String? ?? '',
        status: json['status'] as String? ?? 'queued',
      );
}
