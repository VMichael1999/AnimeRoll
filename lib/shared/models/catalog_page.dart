import 'anime_model.dart';

/// Página de resultados del catálogo. Algunos proveedores (HentaiTK cuando
/// se filtra por año) devuelven los items adicionalmente agrupados por mes
/// dentro de `months`. Si esa lista viene vacía, el cliente cae al flujo
/// genérico (renderizar `results` como un solo grid).
class CatalogPage {
  final List<AnimeModel> results;
  final List<CatalogMonth> months;

  const CatalogPage({this.results = const [], this.months = const []});

  bool get isGroupedByMonth => months.isNotEmpty;

  factory CatalogPage.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    final List items = rawResults is List ? rawResults : const [];
    final results = items
        .whereType<Map>()
        .map((e) => AnimeModel.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);

    final rawMonths = json['months'];
    final List monthItems = rawMonths is List ? rawMonths : const [];
    final months = monthItems
        .whereType<Map>()
        .map((e) => CatalogMonth.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);

    return CatalogPage(results: results, months: months);
  }
}

/// Una sección del catálogo agrupada por mes. Se pinta en la UI como banner
/// rojo `ESTRENOS [MES] [AÑO]` + grid con los animes de ese mes.
class CatalogMonth {
  /// Número del mes (1..12). Renombrado del `num` original para no chocar
  /// con la clase `num` de Dart (que rompe `as num?` en el JSON parser).
  final int month;
  final String slug;
  final String label;
  final int? year;
  final List<AnimeModel> items;

  const CatalogMonth({
    required this.month,
    required this.slug,
    required this.label,
    required this.year,
    required this.items,
  });

  factory CatalogMonth.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List items = rawItems is List ? rawItems : const [];
    return CatalogMonth(
      month: (json['num'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      year: (json['year'] as num?)?.toInt(),
      items: items
          .whereType<Map>()
          .map((e) => AnimeModel.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
