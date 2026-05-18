import 'package:flutter/material.dart';
import '../utils/network_error.dart';
import 'error_view.dart';
import 'no_connection_empty.dart';

/// Wrapper que muestra `NoConnectionEmpty` (imagen + retry clickeable) si la
/// excepción es de red, o el `ErrorView` genérico para cualquier otro error.
/// Útil para no repetir el `if (isNetworkError(e)) ... else ...` en cada
/// `error:` de un `AsyncValue`.
class NetworkAwareError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final String message;
  final bool compact;

  const NetworkAwareError({
    super.key,
    required this.error,
    required this.onRetry,
    this.message = 'No se pudo cargar el contenido',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isNetworkError(error)) {
      return NoConnectionEmpty(onRetry: onRetry, compact: compact);
    }
    return ErrorView(message: message, onRetry: onRetry);
  }
}
