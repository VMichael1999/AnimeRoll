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
  });

  bool get isRunning =>
      status == 'queued' || status == 'preparing' || status == 'downloading';

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
  );
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
