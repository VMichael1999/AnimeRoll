/// Item del hub de MonosChinos. Representa un capítulo recientemente
/// publicado en la home del sitio. La forma viene del backend en
/// `GET /anime/hub?domain=monoschinos2.net`.
class MonosChinosLatestEpisode {
  final String title;
  final String? slug;
  /// URL del anime (`/anime/<slug>`) — usada para navegar al detalle.
  final String? animeUrl;
  /// URL del episodio (`/ver/<slug>-episodio-N`) — usada para reproducir.
  final String episodeUrl;
  final int episode;
  /// Poster vertical del anime. MonosChinos no expone screenshots por
  /// episodio, así que reutiliza el poster oficial para cada capítulo nuevo.
  final String? poster;
  /// Género primario que el sitio muestra debajo del título (puede ser null
  /// si no parseamos uno).
  final String? genre;

  const MonosChinosLatestEpisode({
    required this.title,
    required this.episodeUrl,
    required this.episode,
    this.slug,
    this.animeUrl,
    this.poster,
    this.genre,
  });

  factory MonosChinosLatestEpisode.fromJson(Map<String, dynamic> json) {
    return MonosChinosLatestEpisode(
      title: (json['title'] ?? '').toString(),
      slug: json['slug'] as String?,
      animeUrl: json['url'] as String?,
      episodeUrl: (json['episodeUrl'] ?? '').toString(),
      episode: (json['episode'] as num?)?.toInt() ?? 0,
      poster: json['poster'] as String? ?? json['image'] as String?,
      genre: json['genre'] as String?,
    );
  }
}

/// Forma del hub de MonosChinos consumido por el home.
class MonosChinosHubData {
  final List<MonosChinosLatestEpisode> latestEpisodes;

  const MonosChinosHubData({required this.latestEpisodes});

  static const empty = MonosChinosHubData(latestEpisodes: []);
}
