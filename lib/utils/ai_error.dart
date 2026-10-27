import 'package:dio/dio.dart';

// Helpers to classify and describe failures from the AI (Gemini) calls.

final RegExp _transientPattern = RegExp(
  r'429|500|502|503|504|timeout|tiempo de espera|overloaded|unavailable|'
  r'resource_exhausted|rate limit|quota',
  caseSensitive: false,
);

/// True when [error] is likely to succeed if the request is repeated:
/// rate limits, server overload/5xx and network timeouts.
bool isTransientAiError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        break;
    }
    final status = error.response?.statusCode;
    if (status != null && (status == 429 || status >= 500)) return true;
  }
  return _transientPattern.hasMatch(error.toString());
}

/// Short, user-facing (Spanish) reason for an AI failure.
String describeAiError(Object error) {
  final text = error.toString().toLowerCase();
  if (RegExp(r'429|quota|resource_exhausted|rate limit').hasMatch(text)) {
    return 'Límite de uso de Gemini alcanzado. Intenta en unos minutos';
  }
  if (RegExp(r'timeout|tiempo de espera').hasMatch(text)) {
    return 'La IA tardó demasiado en responder. Intenta nuevamente';
  }
  if (RegExp(r'503|overloaded|unavailable').hasMatch(text)) {
    return 'Gemini está saturado en este momento. Intenta nuevamente';
  }
  if (RegExp(r'500|502|504').hasMatch(text)) {
    return 'El servicio de IA falló temporalmente. Intenta nuevamente';
  }
  if (RegExp(r'401|403|api key|permission').hasMatch(text)) {
    return 'La API Key de Gemini no es válida o no tiene permisos';
  }
  if (error is DioException && error.type == DioExceptionType.connectionError) {
    return 'Sin conexión con el servicio de IA. Revisa tu internet';
  }
  return 'Error al analizar la imagen con IA';
}

/// Runs [action], repeating it up to [retries] more times (waiting [delay]
/// times the attempt number between tries) only for transient errors.
Future<T> retryTransient<T>(
  Future<T> Function() action, {
  int retries = 2,
  Duration delay = const Duration(seconds: 2),
}) async {
  var attempt = 0;
  while (true) {
    try {
      return await action();
    } catch (e) {
      if (attempt >= retries || !isTransientAiError(e)) rethrow;
      attempt++;
      await Future<void>.delayed(delay * attempt);
    }
  }
}
