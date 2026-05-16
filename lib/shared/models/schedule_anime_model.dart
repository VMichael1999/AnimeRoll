class ScheduleAnimeModel {
  final String title;
  final String url;
  final String episodeUrl;
  /// Screenshot horizontal del episodio (16:9). Usado en cards de horario.
  final String? cover;
  /// Backdrop del anime (16:9, sin contexto de episodio). Usado para el hero
  /// del proximo episodio cuando exista; suele ser una imagen mas pulida que
  /// el screenshot de un episodio especifico.
  final String? backdrop;
  /// Poster vertical del anime. Fallback final si no hay screenshot/backdrop.
  final String? poster;
  final String? type;
  final int? episode;
  final DateTime? emittedAt;

  const ScheduleAnimeModel({
    required this.title,
    required this.url,
    required this.episodeUrl,
    this.cover,
    this.backdrop,
    this.poster,
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
      backdrop: json['backdrop'] as String?,
      poster: json['poster'] as String?,
      type: json['type'] as String?,
      episode: (json['episode'] as num?)?.toInt(),
      emittedAt: DateTime.tryParse(
        json['emittedAt']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
