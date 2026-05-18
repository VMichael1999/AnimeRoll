// Helpers de proveedor compartidos por toda la app.
//
// Cada anime / episodio guardado (favoritos, watchlist, history) lleva una
// URL absoluta del sitio scrapeado. Para filtrar por proveedor activo
// derivamos el dominio canonico desde esa URL sin requerir un campo nuevo
// en los modelos persistidos — esto preserva compatibilidad con datos ya
// guardados en SharedPreferences.

/// Devuelve el dominio canonico del proveedor para una URL absoluta. Si el
/// host no matchea ningun proveedor conocido, cae al default AnimeAV1 (el
/// proveedor "general" de la app).
String providerForUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return 'animeav1.com';
  if (host.contains('hentaila')) return 'hentaila.com';
  if (host.contains('monoschinos')) return 'monoschinos2.net';
  if (host.contains('animeflv')) return 'animeflv.net';
  if (host.contains('tioanime')) return 'tioanime.com';
  if (host.contains('jkanime')) return 'jkanime.net';
  // Default: cualquier otro host se considera AnimeAV1 (cubre el caso
  // animeav1.com pero tambien data legacy sin host reconocido).
  return 'animeav1.com';
}
