import 'dart:io';
import 'package:dio/dio.dart';

/// Decide si una excepción atrapada en un `FutureProvider` representa una
/// caída de conexión (no hay internet, DNS, timeout, host inalcanzable, etc.).
/// Sirve para ramificar entre el empty state "Sin conexión" (con retry) y el
/// `ErrorView` genérico de errores funcionales.
bool isNetworkError(Object? error) {
  if (error is SocketException) return true;
  if (error is HttpException) return true;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // `unknown` envuelve frecuentemente un SocketException de bajo nivel.
        return error.error is SocketException || error.error is HttpException;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }
  // Mensajes de error sin tipado fuerte: heurística por substring.
  final text = error?.toString().toLowerCase() ?? '';
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('network is unreachable');
}
