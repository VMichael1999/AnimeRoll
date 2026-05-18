// Capacidades por proveedor — centralizadas para evitar dispersión de
// comparaciones contra strings literales (`activeProvider == 'hentaila.com'`).
//
// El patrón previo tenía esos checks regados en ~88 lugares de la app: cada
// vez que se agrega un proveedor nuevo había que recorrer todo. Ahora el
// helper expone capacidades booleanas (`isScoped`, `supportsSchedule`, etc.)
// y los call-sites preguntan por la capacidad, no por el nombre.

/// Identidad canónica de cada proveedor soportado por la app. El valor
/// `unknown` cubre dominios legacy o no reconocidos — el helper los trata
/// como AnimeAV1 (default histórico de la app) para no romper data antigua.
enum ProviderId {
  animeav1,
  hentaila,
  hentaitk,
  monoschinos,
  cinehax,
  animeflv,
  tioanime,
  jkanime,
  unknown;

  /// Deriva la identidad desde una URL absoluta o un dominio. Compara con
  /// `contains` para tolerar variaciones (`www.`, `vww.`, etc.).
  static ProviderId fromDomain(String? domainOrUrl) {
    if (domainOrUrl == null || domainOrUrl.isEmpty) return ProviderId.unknown;
    final raw = domainOrUrl.toLowerCase();
    // Si parece URL, sacamos solo el host; si es ya un dominio, lo dejamos.
    final host = raw.contains('://')
        ? (Uri.tryParse(raw)?.host.toLowerCase() ?? raw)
        : raw;
    // Orden importa: chequeamos hentaitk ANTES que hentaila porque la
    // detección es por `contains` y ambos llevan "hentai".
    if (host.contains('hentaitk')) return ProviderId.hentaitk;
    if (host.contains('hentaila')) return ProviderId.hentaila;
    if (host.contains('cinehax')) return ProviderId.cinehax;
    if (host.contains('monoschinos')) return ProviderId.monoschinos;
    if (host.contains('animeflv')) return ProviderId.animeflv;
    if (host.contains('tioanime')) return ProviderId.tioanime;
    if (host.contains('jkanime')) return ProviderId.jkanime;
    if (host.contains('animeav1')) return ProviderId.animeav1;
    return ProviderId.unknown;
  }

  /// Dominio canónico que se envía al backend en query strings (?domain=).
  String get canonicalDomain => switch (this) {
    ProviderId.animeav1 => 'animeav1.com',
    ProviderId.hentaila => 'hentaila.com',
    ProviderId.hentaitk => 'hentaitk.net',
    ProviderId.monoschinos => 'monoschinos2.net',
    ProviderId.cinehax => 'cinehax.com',
    ProviderId.animeflv => 'animeflv.net',
    ProviderId.tioanime => 'tioanime.com',
    ProviderId.jkanime => 'jkanime.net',
    ProviderId.unknown => 'animeav1.com',
  };

  /// Nombre legible para mostrar en UI (header, badges, modos).
  String get label => switch (this) {
    ProviderId.animeav1 => 'AnimeAV1',
    ProviderId.hentaila => 'HentaiLA',
    ProviderId.hentaitk => 'HentaiTK',
    ProviderId.monoschinos => 'MonosChinos',
    ProviderId.cinehax => 'CineHax',
    ProviderId.animeflv => 'AnimeFLV',
    ProviderId.tioanime => 'TioAnime',
    ProviderId.jkanime => 'JKAnime',
    ProviderId.unknown => 'Proveedor',
  };

  /// "Scoped" significa que el proveedor tiene UI propia (home dedicado,
  /// favoritos/watchlist filtrados solo a él) y NO debe mezclarse con el
  /// flujo genérico de búsqueda multi-proveedor.
  bool get isScoped =>
      this == ProviderId.hentaila ||
      this == ProviderId.hentaitk ||
      this == ProviderId.monoschinos ||
      this == ProviderId.cinehax;

  /// Si requiere un código de desbloqueo (VIP gate) antes de poder
  /// activarse. CineHax es el único hoy — el usuario debe ingresar `999-999`
  /// la primera vez. El estado se persiste en SharedPreferences.
  bool get isVip => this == ProviderId.cinehax;

  /// Si el backend expone `/schedule` para este proveedor. Solo AnimeAV1
  /// publica horario semanal real.
  bool get supportsSchedule => this == ProviderId.animeav1;

  /// Si el proveedor soporta `/mood-search` (búsqueda por estado de ánimo
  /// con IA). Hoy solo AnimeAV1 + el modo genérico cuando no hay proveedor.
  bool get supportsMoodSearch => this == ProviderId.animeav1;

  /// Si el proveedor tiene una pantalla home con diseño dedicado.
  bool get hasCustomHome => isScoped;
}
