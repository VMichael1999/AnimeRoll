class AnimeModel {
  final String title;
  final String url;
  final String? cover;
  final String? synopsis;
  final String? status;
  final String? type;
  final String? year;
  final List<String> genres;
  final int? episodeCount;
  final double? score;
  final int? votes;

  const AnimeModel({
    required this.title,
    required this.url,
    this.cover,
    this.synopsis,
    this.status,
    this.type,
    this.year,
    this.genres = const [],
    this.episodeCount,
    this.score,
    this.votes,
  });

  factory AnimeModel.fromJson(Map<String, dynamic> json) {
    final episodes = json['episodes'];
    final genres = json['genres'];

    return AnimeModel(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      cover:
          json['cover'] as String? ??
          json['image'] as String? ??
          json['poster'] as String?,
      synopsis: json['synopsis'] as String? ?? json['description'] as String?,
      status: _statusLabel(json['status']),
      type: json['type'] as String?,
      year: json['year']?.toString() ?? _yearFromDate(json['startDate']),
      genres: genres is List
          ? genres
                .map(
                  (genre) => genre is Map
                      ? genre['name']?.toString()
                      : genre?.toString(),
                )
                .whereType<String>()
                .toList()
          : const [],
      episodeCount:
          (json['episodeCount'] as num?)?.toInt() ??
          (json['totalEpisodes'] as num?)?.toInt() ??
          (episodes is List ? episodes.length : (episodes as num?)?.toInt()),
      score: (json['score'] as num?)?.toDouble(),
      votes: (json['votes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'cover': cover,
    'synopsis': synopsis,
    'status': status,
    'type': type,
    'year': year,
    'genres': genres,
    'episodeCount': episodeCount,
    'score': score,
    'votes': votes,
  };

  static String? _yearFromDate(Object? value) {
    final text = value?.toString();
    if (text == null || text.length < 4) return null;
    return text.substring(0, 4);
  }

  static String? _statusLabel(Object? value) {
    if (value is String) return value;
    return switch (value) {
      1 => 'Finalizado',
      2 => 'En emisión',
      3 => 'Próximamente',
      _ => null,
    };
  }
}
