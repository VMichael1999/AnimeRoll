class AnimeModel {
  final String title;
  final String url;
  final String? cover;
  final String? synopsis;
  final String? status;
  final String? year;
  final List<String> genres;
  final int? episodeCount;
  final double? score;

  const AnimeModel({
    required this.title,
    required this.url,
    this.cover,
    this.synopsis,
    this.status,
    this.year,
    this.genres = const [],
    this.episodeCount,
    this.score,
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
      status: json['status'] as String?,
      year: json['year']?.toString(),
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
    );
  }
}
