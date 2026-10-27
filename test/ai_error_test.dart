import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocky/utils/ai_error.dart';

void main() {
  group('isTransientAiError', () {
    test('detects rate limits, overload and timeouts', () {
      expect(isTransientAiError(Exception('GEMINI API error: 429')), isTrue);
      expect(isTransientAiError(Exception('model is overloaded')), isTrue);
      expect(isTransientAiError(Exception('Tiempo de espera agotado')), isTrue);
      expect(
        isTransientAiError(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isTrue,
      );
    });

    test('does not retry permanent errors', () {
      expect(isTransientAiError(Exception('API key not valid')), isFalse);
    });
  });

  group('describeAiError', () {
    test('maps known causes to a specific message', () {
      expect(describeAiError(Exception('429 quota')), contains('Límite'));
      expect(
        describeAiError(Exception('503 unavailable')),
        contains('saturado'),
      );
      expect(
        describeAiError(Exception('weird')),
        'Error al analizar la imagen con IA',
      );
    });
  });

  group('retryTransient', () {
    test('retries transient errors then succeeds', () async {
      var calls = 0;
      final result = await retryTransient(() async {
        calls++;
        if (calls < 3) throw Exception('503 unavailable');
        return 'ok';
      }, delay: Duration.zero);
      expect(result, 'ok');
      expect(calls, 3);
    });

    test('does not retry permanent errors', () async {
      var calls = 0;
      await expectLater(
        retryTransient(() async {
          calls++;
          throw Exception('API key not valid');
        }, delay: Duration.zero),
        throwsException,
      );
      expect(calls, 1);
    });

    test('gives up after the retry budget', () async {
      var calls = 0;
      await expectLater(
        retryTransient(() async {
          calls++;
          throw Exception('429');
        }, delay: Duration.zero),
        throwsException,
      );
      expect(calls, 3);
    });
  });
}
