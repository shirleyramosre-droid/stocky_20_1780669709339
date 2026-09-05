import 'package:dio/dio.dart';

// Same rationale as ai_client.dart: without explicit timeouts a stalled
// connection surfaces as an infinite spinner instead of a retryable error.
final Dio _geminiDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
  ),
);

final RegExp _dataUrlPattern = RegExp(r'^data:(.*?);base64,(.*)$');

/// Calls Google's Gemini API directly with a user-supplied API key,
/// bypassing the Rocket-managed Lambda entirely.
///
/// Returns a response shaped like Gemini's native REST format
/// (`{"candidates": [...]}`), which [GarmentVisionService] already knows
/// how to parse, or `{"error": ..., "details": ...}` on failure — same
/// error-body convention the Lambda uses.
Future<Map<String, dynamic>> callGeminiDirect({
  required String apiKey,
  required String model,
  required List<Map<String, dynamic>> messages,
  Map<String, dynamic> parameters = const {},
}) async {
  final modelId = model.startsWith('gemini/') ? model.substring(7) : model;
  final url =
      'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent';

  final systemParts = <Map<String, dynamic>>[];
  final contents = <Map<String, dynamic>>[];

  for (final message in messages) {
    final role = message['role'] as String? ?? 'user';
    final parts = _contentToParts(message['content']);
    if (parts.isEmpty) continue;
    if (role == 'system') {
      systemParts.addAll(parts);
    } else {
      contents.add({'role': role == 'assistant' ? 'model' : 'user', 'parts': parts});
    }
  }

  final generationConfig = <String, dynamic>{};
  if (parameters['max_tokens'] != null) {
    generationConfig['maxOutputTokens'] = parameters['max_tokens'];
  }
  if (parameters['temperature'] != null) {
    generationConfig['temperature'] = parameters['temperature'];
  }

  final body = {
    'contents': contents,
    if (systemParts.isNotEmpty) 'systemInstruction': {'parts': systemParts},
    if (generationConfig.isNotEmpty) 'generationConfig': generationConfig,
  };

  try {
    final response = await _geminiDio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(
        headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      ),
    );
    return response.data ?? {};
  } on DioException catch (error) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) {
      final err = data['error'];
      final message = err is Map ? err['message']?.toString() : err.toString();
      return {
        'error': 'GEMINI API error: ${error.response?.statusCode ?? ''}',
        'details': message ?? error.message ?? 'Error desconocido',
      };
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      throw Exception(
        'Tiempo de espera agotado al contactar a Gemini. Intenta nuevamente.',
      );
    }
    rethrow;
  }
}

List<Map<String, dynamic>> _contentToParts(dynamic content) {
  if (content is String) {
    return content.isEmpty ? [] : [
      {'text': content},
    ];
  }
  if (content is List) {
    final parts = <Map<String, dynamic>>[];
    for (final item in content) {
      if (item is! Map) continue;
      if (item['type'] == 'text') {
        final text = item['text']?.toString() ?? '';
        if (text.isNotEmpty) parts.add({'text': text});
      } else if (item['type'] == 'image_url') {
        final imageUrl = item['image_url'];
        final dataUrl = imageUrl is Map ? imageUrl['url']?.toString() ?? '' : '';
        final match = _dataUrlPattern.firstMatch(dataUrl);
        if (match != null) {
          parts.add({
            'inlineData': {'mimeType': match.group(1), 'data': match.group(2)},
          });
        }
      }
    }
    return parts;
  }
  return [];
}
