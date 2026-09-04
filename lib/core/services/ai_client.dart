import 'package:dio/dio.dart';

// Without explicit timeouts, Dio waits indefinitely on a stalled connection
// (e.g. network handoff while the camera/cropper activity is in the
// foreground), which surfaces as an infinite loading spinner instead of an
// error the user can retry from.
final Dio _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
  ),
);

Future<Map<String, dynamic>> callLambdaFunction(
  String endpoint,
  Map<String, dynamic> payload,
) async {
  try {
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: payload,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return response.data ?? {};
  } on DioException catch (error) {
    if (error.response?.data != null && error.response?.data is Map) {
      final data = error.response?.data as Map<String, dynamic>;
      if (data['error'] != null) {
        print(
          'Lambda Function Error: ${data['error']}, details: ${data['details']}',
        );
        throw Exception(data['error']);
      }
    }
    print('Lambda function error: $error');
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      throw Exception(
        'Tiempo de espera agotado al contactar el servicio de IA. Intenta nuevamente.',
      );
    }
    rethrow;
  }
}
