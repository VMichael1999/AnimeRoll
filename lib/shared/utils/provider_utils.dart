// Helpers de proveedor — wrapper fino sobre `ProviderId`.
//
// Esta función existía antes que `ProviderId` y muchas pantallas la consumen
// directamente. La mantenemos como adaptador para no romperlas; el match real
// vive en `provider_capabilities.dart`.

import 'provider_capabilities.dart';

/// Devuelve el dominio canónico del proveedor que corresponde a la URL
/// pasada. Si el host no se reconoce, cae a AnimeAV1 (default histórico).
String providerForUrl(String url) =>
    ProviderId.fromDomain(url).canonicalDomain;
