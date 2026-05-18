import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Wrapper sobre [CachedNetworkImage] con defaults inteligentes para esta app:
///
///   1. **`memCacheWidth/Height` dinámicos** — la imagen se decodifica al
///      tamaño real al que va a renderizarse (display × DPR del device), no a
///      su tamaño original. Esto reduce uso de memoria y evita re-scaling en
///      cada frame.
///   2. **`filterQuality: medium`** — por defecto Flutter usa `low` (nearest
///      neighbor), que se ve granuloso al escalar covers chicas. `medium`
///      aplica bilinear y mejora calidad visual sin costo perceptible.
///   3. **Fade-in corto (120ms)** — sensación responsive.
///   4. **Fallbacks consistentes** — `errorBuilder` y `placeholder` por
///      defecto, sobrescribibles caso por caso.
///
/// Los CDNs de los proveedores sirven covers chicas (180×367px típico). Esto
/// no puede arreglarse desde el cliente, pero `filterQuality.medium` hace que
/// el upscaling sea suave en vez de pixelado.
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final FilterQuality filterQuality;
  /// Tint opcional. Útil para oscurecer covers cuando se les superpone texto.
  final Color? color;
  final BlendMode? colorBlendMode;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.filterQuality = FilterQuality.medium,
    this.color,
    this.colorBlendMode,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _wrap(errorWidget ?? _defaultPlaceholder());
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = width != null ? (width! * dpr).round() : null;
    final cacheH = height != null ? (height! * dpr).round() : null;

    final image = CachedNetworkImage(
      imageUrl: url!,
      fit: fit,
      width: width,
      height: height,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (_, _, _) => errorWidget ?? _defaultPlaceholder(),
    );

    return _wrap(image);
  }

  Widget _wrap(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _defaultPlaceholder() => ColoredBox(
    color: AppColors.surface2,
    child: SizedBox(width: width, height: height),
  );
}
