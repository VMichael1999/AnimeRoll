import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Empty state que se muestra cuando el episodio activo no tiene servidores
/// reproducibles. La imagen + textos + botón quedan centrados verticalmente
/// y aparece un botón "atrás" en la esquina superior izquierda.
class NoServersEmpty extends StatelessWidget {
  /// Cuando `true` ajusta paddings para verse bien dentro del AspectRatio 16:9
  /// del player. Cuando `false` se centra en la pantalla completa.
  final bool compact;

  const NoServersEmpty({super.key, this.compact = false});

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
                horizontal: 32,
                vertical: compact ? 16 : 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // El PNG trae padding transparente interno, así que lo
                  // recortamos visualmente con ClipRect + un OverflowBox para
                  // que la imagen "toque" el texto sin aire en medio.
                  ClipRect(
                    child: SizedBox(
                      height: compact ? 120 : 210,
                      width: compact ? 240 : 380,
                      child: OverflowBox(
                        minHeight: compact ? 240 : 420,
                        maxHeight: compact ? 240 : 420,
                        minWidth: compact ? 280 : 460,
                        maxWidth: compact ? 280 : 460,
                        child: Image.asset(
                          'assets/sin_servicio.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: const SizedBox.shrink(),
                  ),
                  Text(
                    'Sin servidores disponibles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 16 : 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Text(
                    'No hay servidores disponibles en este momento. ¡Vuelve más tarde!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 24),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.accent2.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.accent2,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Próximamente',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
