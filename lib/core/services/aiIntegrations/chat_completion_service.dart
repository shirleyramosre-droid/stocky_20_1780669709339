import 'dart:convert';
import 'package:dio/dio.dart';
import '../ai_client.dart';

// Load Lambda URL from compile-time environment variable (same pattern as SUPABASE_URL)
const String _chatCompletionEndpoint = String.fromEnvironment(
  'AWS_LAMBDA_CHAT_COMPLETION_URL',
  defaultValue: '',
);

/// No-op kept for backward compatibility — endpoint is now a compile-time constant.
Future<void> initializeLambdaEndpoint() async {
  if (_chatCompletionEndpoint.isEmpty) {
    print(
      '[ERROR] AWS_LAMBDA_CHAT_COMPLETION_URL no está configurada en las variables de entorno.',
    );
  } else {
    print(
      '[OK] Lambda URL configurada: ${_chatCompletionEndpoint.substring(0, _chatCompletionEndpoint.length.clamp(0, 40))}...',
    );
  }
}

Future<Map<String, dynamic>> getChatCompletion(
  String provider,
  String model,
  List<Map<String, dynamic>> messages, {
  Map<String, dynamic> parameters = const {},
}) async {
  if (_chatCompletionEndpoint.isEmpty) {
    throw Exception(
      'Lambda endpoint no configurado. Verifica AWS_LAMBDA_CHAT_COMPLETION_URL en env.json.',
    );
  }

  final payload = {
    'provider': provider,
    'model': model,
    'messages': messages,
    'stream': false,
    'parameters': parameters,
  };
  return await callLambdaFunction(_chatCompletionEndpoint, payload);
}

Future<void> getStreamingChatCompletion(
  String provider,
  String model,
  List<Map<String, dynamic>> messages, {
  required void Function(Map<String, dynamic> chunk) onChunk,
  required void Function() onComplete,
  required void Function(Exception error) onError,
  Map<String, dynamic> parameters = const {},
}) async {
  if (_chatCompletionEndpoint.isEmpty) {
    throw Exception(
      'Lambda endpoint no configurado. Verifica AWS_LAMBDA_CHAT_COMPLETION_URL en env.json.',
    );
  }

  final payload = {
    'provider': provider,
    'model': model,
    'messages': messages,
    'stream': true,
    'parameters': parameters,
  };

  try {
    final dio = Dio();
    final response = await dio.post<ResponseBody>(
      _chatCompletionEndpoint,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.stream,
      ),
    );

    String buffer = '';
    await for (final chunk in response.data!.stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          try {
            final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            if (data['type'] == 'chunk' && data['chunk'] != null) {
              onChunk(data['chunk'] as Map<String, dynamic>);
            } else if (data['type'] == 'done') {
              onComplete();
            } else if (data['type'] == 'error') {
              print(
                'Lambda Function Error: ${data['error']}, details: ${data['details']}',
              );
              onError(Exception(data['error']));
            }
          } catch (_) {}
        }
      }
    }
  } catch (error) {
    print('Streaming error: $error');
    onError(error is Exception ? error : Exception(error.toString()));
  }
}
