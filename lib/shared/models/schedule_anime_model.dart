class ScheduleAnimeModel {
  final String title;
  final String url;
  final String episodeUrl;
  final String? cover;
  final String? type;
  final int? episode;
  final DateTime? emittedAt;

  const ScheduleAnimeModel({
    required this.title,
    required this.url,
    required this.episodeUrl,
    this.cover,
    this.type,
    this.episode,
    this.emittedAt,
  });

  factory ScheduleAnimeModel.fromJson(Map<String, dynamic> json) {
    return ScheduleAnimeModel(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      episodeUrl: json['episodeUrl'] as String? ?? '',
      cover:
          json['cover'] as String? ??
          json['image'] as String? ??
          json['poster'] as String?,
      type: json['type'] as String?,
      episode: (json['episode'] as num?)?.toInt(),
      emittedAt: DateTime.tryParse(
        json['emittedAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
