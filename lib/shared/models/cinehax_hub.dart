import 'anime_model.dart';

/// Hub de CineHax. El backend (`/anime/hub?domain=cinehax.com`) devuelve un
/// hero + una lista variable de secciones (películas por género, series por
/// género, Netflix, top rated, etc.). Cada sección lleva su `id`, `label`,
/// `type` (movie/tv), `genre` opcional y los items en formato `AnimeModel`.
class CinehaxHubData {
  final AnimeModel? hero;
  final List<CinehaxSection> sections;

  const CinehaxHubData({required this.hero, required this.sections});

  factory CinehaxHubData.fromJson(Map<String, dynamic> json) {
    AnimeModel? parseHero(dynamic raw) {
      if (raw is! Map) return null;
      return AnimeModel.fromJson(raw.cast<String, dynamic>());
    }

    final rawSections = json['sections'];
    final List sectionList = rawSections is List ? rawSections : const [];

    return CinehaxHubData(
      hero: parseHero(json['hero']),
      sections: sectionList
          .whereType<Map>()
          .map((e) => CinehaxSection.fromJson(e.cast<String, dynamic>()))
          .where((s) => s.items.isNotEmpty)
          .toList(),
    );
  }
}

class CinehaxSection {
  /// Identificador estable usado por el backend (`popular_movies`,
  /// `comedy_movies`, etc.). Sirve para deep-linking a la pantalla "Ver todo".
  final String id;

  /// Etiqueta legible para el header de la sección.
  final String label;

  /// `'movie'` o `'tv'`. Determina qué endpoint pegar al "Ver todo".
  final String type;

  /// Slug del género (`comedy`, `action`, ...) cuando aplica; null para
  /// secciones agregadas como "Top hoy" o "Series de Netflix".
  final String? genre;

  /// Orden TMDB de la sección (`popular`, `trending`, `top-rated`, ...).
  final String? sort;

  final List<AnimeModel> items;

  const CinehaxSection({
    required this.id,
    required this.label,
    required this.type,
    required this.items,
    this.genre,
    this.sort,
  });

  factory CinehaxSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List items = rawItems is List ? rawItems : const [];
    return CinehaxSection(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      type: (json['type'] ?? 'movie').toString(),
      genre: json['genre']?.toString(),
      sort: json['sort']?.toString(),
      items: items
          .whereType<Map>()
          .map((e) => AnimeModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
