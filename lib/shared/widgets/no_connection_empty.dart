import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Empty state cuando no hay conexión a internet. La imagen ya trae el
/// título, descripción y el botón "Reintentar" dibujados, así que toda
/// la imagen actúa como zona tappable para disparar el retry. Incluye
/// un botón "atrás" arriba a la izquierda.
class NoConnectionEmpty extends StatelessWidget {
  /// Callback que se ejecuta al tocar el área (típicamente el botón
  /// "Reintentar" que ya viene dibujado en el PNG).
  final VoidCallback onRetry;

  /// Cuando `true` ajusta la escala para encajar dentro de áreas pequeñas
  /// (p.ej. el bloque del player en aspect-ratio 16:9).
  final bool compact;

  const NoConnectionEmpty({
    super.key,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Contenido centrado verticalmente.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 32,
                vertical: compact ? 12 : 24,
              ),
              child: Center(
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: AppColors.accent.withValues(alpha: 0.18),
                  highlightColor: AppColors.accent.withValues(alpha: 0.08),
                  // Crop visual del padding transparente interno del PNG
                  // para que el botón "Reintentar" no quede muy separado del
                  // texto que dibuja la imagen.
                  child: ClipRect(
                    child: SizedBox(
                      height: compact ? 240 : 440,
                      width: compact ? 320 : 440,
                      child: OverflowBox(
                        minHeight: compact ? 360 : 680,
                        maxHeight: compact ? 360 : 680,
                        minWidth: compact ? 360 : 520,
                        maxWidth: compact ? 360 : 520,
                        child: Image.asset(
                          'assets/sin_conexion.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Botón "atrás" arriba a la izquierda. Respeta el safe area.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
