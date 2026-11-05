import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soplay/core/subtitles/subtitle_translation_service.dart';

void main() {
  group('Google Cloud Translation key validation', () {
    test('decodes escaped text once and preserves Unicode code points', () {
      expect(
        SubtitleTranslationService.decodeGoogleTranslatedText(
          'Fish &amp; chips: &#39;hi&#39; &lt;ok&gt; &#x1F642; &amp;quot;',
        ),
        'Fish & chips: \'hi\' <ok> 🙂 &quot;',
      );
    });

    test(
      'sends a minimal translation and accepts a complete response',
      () async {
        final adapter = _Adapter({
          'data': {
            'translations': [
              {'translatedText': 'Sozo'},
            ],
          },
        });
        await const SubtitleTranslationService().validateGoogleApiKey(
          ' google-test-key ',
          client: _dio(adapter, 'https://translation.googleapis.com'),
        );
        expect(adapter.request!.uri.path, '/language/translate/v2');
        expect(adapter.request!.headers['x-goog-api-key'], 'google-test-key');
      },
    );

    test(
      'rejects invalid credentials and identifies Google quota failures',
      () async {
        final service = const SubtitleTranslationService();
        await expectLater(
          service.validateGoogleApiKey(
            'bad',
            client: _dio(
              _Adapter({
                'error': {'message': 'API key not valid'},
              }, status: 400),
              'https://translation.googleapis.com',
            ),
          ),
          throwsA(
            isA<GoogleTranslationKeyException>().having(
              (e) => e.failure,
              'failure',
              GoogleTranslationKeyFailure.invalid,
            ),
          ),
        );
        await expectLater(
          service.validateGoogleApiKey(
            'limited',
            client: _dio(
              _Adapter({
                'error': {'message': 'Quota exceeded'},
              }, status: 429),
              'https://translation.googleapis.com',
            ),
          ),
          throwsA(
            isA<GoogleTranslationKeyException>().having(
              (e) => e.failure,
              'failure',
              GoogleTranslationKeyFailure.quota,
            ),
          ),
        );
      },
    );

    test('does not accept an incomplete success response', () async {
      await expectLater(
        const SubtitleTranslationService().validateGoogleApiKey(
          'key',
          client: _dio(
            _Adapter({
              'data': {'translations': []},
            }),
            'https://translation.googleapis.com',
          ),
        ),
        throwsA(
          isA<GoogleTranslationKeyException>().having(
            (e) => e.failure,
            'failure',
            GoogleTranslationKeyFailure.unexpected,
          ),
        ),
      );
    });

    test(
      'maps a connection failure without treating it as an invalid key',
      () async {
        await expectLater(
          const SubtitleTranslationService().validateGoogleApiKey(
            'key',
            client: _dio(
              _FailingAdapter(),
              'https://translation.googleapis.com',
            ),
          ),
          throwsA(
            isA<GoogleTranslationKeyException>().having(
              (e) => e.failure,
              'failure',
              GoogleTranslationKeyFailure.network,
            ),
          ),
        );
      },
    );
  });

  group('OpenAI key validation', () {
    test(
      'sends a minimal chat completion and accepts a complete response',
      () async {
        final adapter = _Adapter({
          'choices': [
            {
              'message': {'content': 'Sozo'},
            },
          ],
        });
        await const SubtitleTranslationService().validateOpenAiApiKey(
          ' sk-test-key ',
          client: _dio(adapter, 'https://api.openai.com/v1'),
        );
        expect(adapter.request!.uri.path, '/v1/chat/completions');
        expect(adapter.request!.headers['Authorization'], 'Bearer sk-test-key');
      },
    );

    test('identifies invalid keys and quota failures', () async {
      final service = const SubtitleTranslationService();
      await expectLater(
        service.validateOpenAiApiKey(
          'bad',
          client: _dio(
            _Adapter({
              'error': {'message': 'Invalid API key'},
            }, status: 401),
            'https://api.openai.com/v1',
          ),
        ),
        throwsA(
          isA<OpenAiKeyException>().having(
            (e) => e.failure,
            'failure',
            OpenAiKeyFailure.invalid,
          ),
        ),
      );
      await expectLater(
        service.validateOpenAiApiKey(
          'limited',
          client: _dio(
            _Adapter({
              'error': {'code': 'insufficient_quota'},
            }, status: 429),
            'https://api.openai.com/v1',
          ),
        ),
        throwsA(
          isA<OpenAiKeyException>().having(
            (e) => e.failure,
            'failure',
            OpenAiKeyFailure.quota,
          ),
        ),
      );
    });

    test('rejects missing completion content', () async {
      await expectLater(
        const SubtitleTranslationService().validateOpenAiApiKey(
          'key',
          client: _dio(_Adapter({'choices': []}), 'https://api.openai.com/v1'),
        ),
        throwsA(
          isA<OpenAiKeyException>().having(
            (e) => e.failure,
            'failure',
            OpenAiKeyFailure.unexpected,
          ),
        ),
      );
    });
  });
}

Dio _dio(HttpClientAdapter adapter, String baseUrl) =>
    Dio(BaseOptions(baseUrl: baseUrl, validateStatus: (_) => true))
      ..httpClientAdapter = adapter;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.payload, {this.status = 200});
  final Object payload;
  final int status;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}
