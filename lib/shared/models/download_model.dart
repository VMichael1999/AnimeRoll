class DownloadModel {
  final String id;
  final String status;
  final int progress;
  final String url;
  final String? title;
  final String? thumbnail;
  final String quality;
  final String variant;
  final String? downloadUrl;
  final String? fileSize;
  final String? currentServer;
  final String? error;
  final String? localPath;
  final int localProgress;
  final String localStatus;
  final String? savedAt;

  const DownloadModel({
    required this.id,
    required this.status,
    required this.progress,
    required this.url,
    this.title,
    this.thumbnail,
    required this.quality,
    required this.variant,
    this.downloadUrl,
    this.fileSize,
    this.currentServer,
    this.error,
    this.localPath,
    this.localProgress = 0,
    this.localStatus = 'pending',
    this.savedAt,
  });

  bool get isRunning =>
      status == 'queued' || status == 'preparing' || status == 'downloading';

  bool get isLocalRunning => localStatus == 'saving';

  bool get isSavedOnDevice => localStatus == 'saved' && localPath != null;

  factory DownloadModel.fromJson(Map<String, dynamic> json) => DownloadModel(
    id: json['downloadId'] as String? ?? json['id'] as String? ?? '',
    status: json['status'] as String? ?? 'queued',
    progress: (json['progress'] as num?)?.toInt() ?? 0,
    url: json['url'] as String? ?? '',
    title: json['title'] as String?,
    thumbnail: json['thumbnail'] as String?,
    quality: json['quality'] as String? ?? '1080p',
    variant: json['variant'] as String? ?? 'SUB',
    downloadUrl: json['downloadUrl'] as String?,
    fileSize: json['fileSize']?.toString(),
    currentServer: json['currentServer'] as String?,
    error: json['error'] as String?,
    localPath: json['localPath'] as String?,
    localProgress: (json['localProgress'] as num?)?.toInt() ?? 0,
    localStatus: json['localStatus'] as String? ?? 'pending',
    savedAt: json['savedAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'progress': progress,
    'url': url,
    'title': title,
    'thumbnail': thumbnail,
    'quality': quality,
    'variant': variant,
    'downloadUrl': downloadUrl,
    'fileSize': fileSize,
    'currentServer': currentServer,
    'error': error,
    'localPath': localPath,
    'localProgress': localProgress,
    'localStatus': localStatus,
    'savedAt': savedAt,
  };

  DownloadModel copyWith({
    String? id,
    String? status,
    int? progress,
    String? url,
    String? title,
    String? thumbnail,
    String? quality,
    String? variant,
    String? downloadUrl,
    String? fileSize,
    String? currentServer,
    String? error,
    String? localPath,
    int? localProgress,
    String? localStatus,
    String? savedAt,
  }) {
    return DownloadModel(
      id: id ?? this.id,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      quality: quality ?? this.quality,
      variant: variant ?? this.variant,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSize: fileSize ?? this.fileSize,
      currentServer: currentServer ?? this.currentServer,
      error: error ?? this.error,
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
