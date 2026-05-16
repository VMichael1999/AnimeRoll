/// Filtros disponibles para un proveedor especifico — alimentado por el
/// endpoint `/anime/filters` del backend. La UI solo debe mostrar las
/// secciones cuyo `List<FilterOption>` no esta vacio.
class FilterOption {
  final String value;
  final String label;

  const FilterOption({required this.value, required this.label});

  factory FilterOption.fromJson(Map<String, dynamic> json) => FilterOption(
    value: (json['value'] ?? '').toString(),
    label: (json['label'] ?? json['value'] ?? '').toString(),
  );
}

class AvailableFilters {
  final String? domain;
  final String? provider;
  final List<FilterOption> genres;
  final List<FilterOption> statuses;
  final List<FilterOption> types;
  final List<FilterOption> years;
  final List<FilterOption> sorts;
  final bool uncensoredAvailable;

  const AvailableFilters({
    this.domain,
    this.provider,
    this.genres = const [],
    this.statuses = const [],
    this.types = const [],
    this.years = const [],
    this.sorts = const [],
    this.uncensoredAvailable = false,
  });

  /// Empty fallback used when the backend hasn't responded yet (loading) or
  /// when the provider exposes no filters at all.
  static const empty = AvailableFilters();

  static List<FilterOption> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => FilterOption.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  factory AvailableFilters.fromJson(Map<String, dynamic> json) {
    return AvailableFilters(
      domain: json['domain'] as String?,
      provider: json['provider'] as String?,
      genres: _list(json['genres']),
      statuses: _list(json['statuses']),
      types: _list(json['types']),
      years: _list(json['years']),
      sorts: _list(json['sorts']),
      uncensoredAvailable: json['uncensoredAvailable'] == true,
    );
  }
}
